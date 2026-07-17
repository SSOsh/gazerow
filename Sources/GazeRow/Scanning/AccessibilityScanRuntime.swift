import ApplicationServices
import Foundation

/// 직렬 AX runtime이 내보내는 progressive scan event.
///
/// AX 객체는 event에 포함하지 않고 Sendable snapshot만 UI actor로 전달한다.
///
/// @author suho.do
/// @since 2026-07-17
enum AccessibilityScanRuntimeEvent: Equatable, Sendable {
    case progress(AccessibilityScanProgress)
    case completed(AccessibilityScanBundleResponse)
}

/// AX tree 순회를 UI actor 밖에서 직렬화하는 실행 경계.
///
/// production operation 안에서만 `AXUIElement`를 생성하고 소비한다. UI actor와는
/// `AccessibilityScanRequest`, progress, response 값만 주고받는다.
///
/// @author suho.do
/// @since 2026-07-17
actor AccessibilityScanRuntime {
    typealias ProgressHandler = @Sendable (AccessibilityScanProgress) -> Void
    typealias ScanOperation = @Sendable (
        AccessibilityScanRequest,
        ProgressHandler
    ) async -> AccessibilityScanBundleExecutionOutcome

    private let operation: ScanOperation

    init(operation: @escaping ScanOperation) {
        self.operation = operation
    }

    /// production AX client를 runtime 내부에서 생성하는 기본 실행 경계.
    nonisolated static func production() -> AccessibilityScanRuntime {
        AccessibilityScanRuntime { request, onProgress in
            let context = TargetContext(
                application: TargetApplication(
                    localizedName: request.target.bundleIdentifier,
                    bundleIdentifier: request.target.bundleIdentifier,
                    processIdentifier: request.target.processIdentifier
                ),
                window: TargetWindow(frame: request.target.windowFrame, title: nil),
                resolvedAt: Date()
            )
            let collector = AccessibilityScanBundleCollector(
                client: AXAccessibilityElementClient(),
                configuration: request.configuration
            )
            let result = await collector.collectProgressively(
                context: context,
                onProgress: onProgress
            )
            switch result {
            case .success(let scanResult):
                    return .success(scanResult)
            case .failure(let failure):
                return .failure(failure)
            }
        }
    }

    /// 호출자의 cancellation을 runtime 작업에 연결한 event stream을 만든다.
    nonisolated func events(
        for request: AccessibilityScanRequest
    ) -> AsyncStream<AccessibilityScanRuntimeEvent> {
        AsyncStream { continuation in
            let task = Task {
                await self.execute(request: request, continuation: continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func execute(
        request: AccessibilityScanRequest,
        continuation: AsyncStream<AccessibilityScanRuntimeEvent>.Continuation
    ) async {
        let outcome = await operation(request) { progress in
            continuation.yield(.progress(progress))
        }
        continuation.yield(
            .completed(
                AccessibilityScanBundleResponse(
                    activationID: request.activationID,
                    outcome: outcome
                )
            )
        )
        continuation.finish()
    }
}

/// MainActor overlay 흐름과 직렬 AX runtime을 연결하는 production scanner.
///
/// @author suho.do
/// @since 2026-07-17
@MainActor
final class AXRuntimeScanner: OverlaySessionBundleProgressiveScanning {
    private let runtime: AccessibilityScanRuntime
    private let configuration: AccessibilityScanConfiguration

    init(
        runtime: AccessibilityScanRuntime = .production(),
        configuration: AccessibilityScanConfiguration = AccessibilityScanConfiguration()
    ) {
        self.runtime = runtime
        self.configuration = configuration
    }

    /// 동기 진입점은 기존 내부 계약 호환용이다.
    ///
    /// production overlay activation은 `scanProgressively`를 사용해 AX runtime 경계를 탄다.
    func scan(context: TargetContext) -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        AccessibilityScanner(
            client: AXAccessibilityElementClient(),
            configuration: configuration
        )
        .scan(context: context)
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
        let activationID = UUID()
        let request = AccessibilityScanRequest(
            activationID: activationID,
            context: context,
            configuration: configuration
        )

        for await event in runtime.events(for: request) {
            guard !Task.isCancelled else {
                return .failure(.cancelled)
            }

            switch event {
            case .progress(let progress):
                onProgress(progress)
            case .completed(let response):
                guard response.activationID == activationID else {
                    return .failure(.cancelled)
                }
                switch response.outcome {
                case .success(let bundle):
                    return .success(bundle)
                case .failure(let failure):
                    return .failure(failure)
                }
            }
        }

        return .failure(.cancelled)
    }
}
