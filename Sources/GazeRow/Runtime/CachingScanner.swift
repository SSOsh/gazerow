import CoreGraphics
import Foundation

/// AX scan 결과를 짧은 TTL 동안 재사용하는 caching decorator.
///
/// 같은 target window를 짧은 간격으로 다시 activation할 때 전체 재스캔을 피한다.
/// UI 변경으로 인한 stale candidate 위험을 줄이기 위해 기본 TTL은 0.5초로 짧게 유지하고,
/// window frame·title이 바뀌면 다른 cache key로 취급해 자동으로 재스캔한다.
/// scan 실패는 cache하지 않아 다음 activation에서 즉시 재시도한다.
///
/// @author suho.do
/// @since 2026-07-07
@MainActor
final class CachingScanner: OverlaySessionBundleProgressiveScanning {
    private let wrapped: any OverlaySessionScanning
    private let timeToLive: TimeInterval
    private let monitoredTimeToLive: TimeInterval
    private let dateProvider: () -> Date
    private let changeMonitor: (any AccessibilityChangeMonitoring)?
    private let generationStore: AccessibilityTreeGenerationStore
    private let cacheEventRecorder: (AccessibilityScanCacheEvent) -> Void
    private var cachedScan: CachedScan?
    private var monitoredProcessIdentifier: pid_t?
    private var isMonitoringChanges = false

    init(
        wrapped: any OverlaySessionScanning,
        timeToLive: TimeInterval = 0.5,
        monitoredTimeToLive: TimeInterval = 3,
        changeMonitor: (any AccessibilityChangeMonitoring)? = nil,
        generationStore: AccessibilityTreeGenerationStore = AccessibilityTreeGenerationStore(),
        cacheEventRecorder: @escaping (AccessibilityScanCacheEvent) -> Void = { event in
            AppLogger.overlay.info(
                "AX scan cache event=\(event.code, privacy: .public)"
            )
        },
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.wrapped = wrapped
        self.timeToLive = max(0, timeToLive)
        self.monitoredTimeToLive = max(self.timeToLive, monitoredTimeToLive)
        self.changeMonitor = changeMonitor
        self.generationStore = generationStore
        self.cacheEventRecorder = cacheEventRecorder
        self.dateProvider = dateProvider
    }

    func scan(context: TargetContext) -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        let key = ScanCacheKey(context: context)
        let now = dateProvider()
        prepareChangeMonitoring(for: context.application.processIdentifier)

        if let cachedScan,
           cachedScan.key == key,
           now.timeIntervalSince(cachedScan.storedAt) <= effectiveTimeToLive {
            cacheEventRecorder(.hit)
            return .success(cachedScan.bundle.scanResult)
        }
        cacheEventRecorder(.miss(cacheMissReason(for: key, at: now)))

        let result = wrapped.scan(context: context)
        switch result {
        case .success(let scanResult):
            cachedScan = CachedScan(
                key: key,
                bundle: bundleWithCurrentCacheMetadata(
                    AccessibilityScanBundle.fallback(scanResult: scanResult),
                    processIdentifier: context.application.processIdentifier
                ),
                storedAt: now
            )
        case .failure:
            invalidateCache(reason: .scanFailure)
        }
        return result
    }

    func scanProgressively(
        context: TargetContext,
        onProgress: @escaping (AccessibilityScanProgress) -> Void
    ) async -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        let result = await scanBundleProgressively(context: context, onProgress: onProgress)
        return result.map(\.scanResult)
    }

    func scanBundleProgressively(
        context: TargetContext,
        onProgress: @escaping (AccessibilityScanProgress) -> Void
    ) async -> Result<AccessibilityScanBundle, AccessibilityScanFailure> {
        let key = ScanCacheKey(context: context)
        let now = dateProvider()
        prepareChangeMonitoring(for: context.application.processIdentifier)

        if let cachedScan,
           cachedScan.key == key,
           now.timeIntervalSince(cachedScan.storedAt) <= effectiveTimeToLive {
            cacheEventRecorder(.hit)
            let scanResult = cachedScan.bundle.scanResult
            onProgress(
                AccessibilityScanProgress(
                    candidates: scanResult.candidates,
                    nodesVisited: scanResult.nodesVisited
                )
            )
            return .success(cachedScan.bundle)
        }
        cacheEventRecorder(.miss(cacheMissReason(for: key, at: now)))

        let result: Result<AccessibilityScanBundle, AccessibilityScanFailure>
        if let bundleScanner = wrapped as? any OverlaySessionBundleProgressiveScanning {
            result = await bundleScanner.scanBundleProgressively(
                context: context,
                onProgress: onProgress
            )
        } else if let progressiveScanner = wrapped as? any OverlaySessionProgressiveScanning {
            result = await progressiveScanner.scanProgressively(
                context: context,
                onProgress: onProgress
            )
            .map(AccessibilityScanBundle.fallback)
        } else {
            result = wrapped.scan(context: context).map(AccessibilityScanBundle.fallback)
        }
        let resultWithMetadata = result.map {
            bundleWithCurrentCacheMetadata(
                $0,
                processIdentifier: context.application.processIdentifier
            )
        }
        store(resultWithMetadata, for: key, at: now)
        return resultWithMetadata
    }

    /// cache를 즉시 무효화한다.
    func invalidate() {
        invalidateCache(reason: .manual)
    }

    private func store(
        _ result: Result<AccessibilityScanBundle, AccessibilityScanFailure>,
        for key: ScanCacheKey,
        at date: Date
    ) {
        switch result {
        case .success(let bundle):
            cachedScan = CachedScan(key: key, bundle: bundle, storedAt: date)
        case .failure:
            invalidateCache(reason: .scanFailure)
        }
    }

    private var effectiveTimeToLive: TimeInterval {
        isMonitoringChanges ? monitoredTimeToLive : timeToLive
    }

    private func prepareChangeMonitoring(for processIdentifier: pid_t) {
        guard let changeMonitor else {
            return
        }

        if isMonitoringChanges, monitoredProcessIdentifier == processIdentifier {
            return
        }

        if let monitoredProcessIdentifier {
            generationStore.setMonitoringActive(false, for: monitoredProcessIdentifier)
        }
        changeMonitor.stop()
        isMonitoringChanges = changeMonitor.start(
            processIdentifier: processIdentifier,
            onChange: { [weak self] metadata in
                guard let self else {
                    return
                }
                self.generationStore.recordChange(metadata, for: processIdentifier)
                self.isMonitoringChanges = false
                self.monitoredProcessIdentifier = nil
                self.invalidateCache(reason: .accessibilityChange(metadata.kind))
            }
        )
        monitoredProcessIdentifier = isMonitoringChanges ? processIdentifier : nil
        generationStore.setMonitoringActive(isMonitoringChanges, for: processIdentifier)
    }

    private func bundleWithCurrentCacheMetadata(
        _ bundle: AccessibilityScanBundle,
        processIdentifier: pid_t
    ) -> AccessibilityScanBundle {
        let snapshot = generationStore.snapshot(for: processIdentifier)
        return bundle.withCacheMetadata(
            generation: snapshot.generation,
            isChangeMonitoringActive: snapshot.isChangeMonitoringActive
        )
    }

    private func cacheMissReason(
        for key: ScanCacheKey,
        at date: Date
    ) -> AccessibilityScanCacheMissReason {
        guard let cachedScan else {
            return .empty
        }
        guard cachedScan.key == key else {
            return .targetChanged
        }
        return date.timeIntervalSince(cachedScan.storedAt) > effectiveTimeToLive
            ? .expired
            : .empty
    }

    private func invalidateCache(reason: AccessibilityScanCacheInvalidationReason) {
        cachedScan = nil
        cacheEventRecorder(.invalidated(reason))
    }
}

/// caching decorator의 cache 항목.
///
/// @author suho.do
/// @since 2026-07-07
private struct CachedScan {
    let key: ScanCacheKey
    let bundle: AccessibilityScanBundle
    let storedAt: Date
}

/// scan cache 식별 키.
///
/// 같은 app·window·frame·title일 때만 cache hit로 취급한다.
///
/// @author suho.do
/// @since 2026-07-07
private struct ScanCacheKey: Equatable {
    let processIdentifier: pid_t
    let bundleIdentifier: String
    let windowFrame: CGRect
    let windowTitle: String?

    init(context: TargetContext) {
        self.processIdentifier = context.application.processIdentifier
        self.bundleIdentifier = context.application.bundleIdentifier
        self.windowFrame = context.window.frame
        self.windowTitle = context.window.title
    }
}
