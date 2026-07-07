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
final class CachingScanner: OverlaySessionScanning {
    private let wrapped: any OverlaySessionScanning
    private let timeToLive: TimeInterval
    private let dateProvider: () -> Date
    private var cachedScan: CachedScan?

    init(
        wrapped: any OverlaySessionScanning,
        timeToLive: TimeInterval = 0.5,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.wrapped = wrapped
        self.timeToLive = max(0, timeToLive)
        self.dateProvider = dateProvider
    }

    func scan(context: TargetContext) -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        let key = ScanCacheKey(context: context)
        let now = dateProvider()

        if let cachedScan,
           cachedScan.key == key,
           now.timeIntervalSince(cachedScan.storedAt) <= timeToLive {
            return .success(cachedScan.result)
        }

        let result = wrapped.scan(context: context)
        switch result {
        case .success(let scanResult):
            cachedScan = CachedScan(key: key, result: scanResult, storedAt: now)
        case .failure:
            cachedScan = nil
        }
        return result
    }

    /// cache를 즉시 무효화한다.
    func invalidate() {
        cachedScan = nil
    }
}

/// caching decorator의 cache 항목.
///
/// @author suho.do
/// @since 2026-07-07
private struct CachedScan {
    let key: ScanCacheKey
    let result: AccessibilityScanResult
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
