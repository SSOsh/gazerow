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
    case completed(AccessibilityScanResponse)
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
    ) async -> AccessibilityScanExecutionOutcome

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
            let scanner = AXAccessibilityScanTraversal(
                client: AXAccessibilityElementClient(),
                configuration: request.configuration
            )
            let result = await scanner.scanProgressively(
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
                AccessibilityScanResponse(
                    activationID: request.activationID,
                    outcome: outcome
                )
            )
        )
        continuation.finish()
    }
}

/// AX runtime actor 내부에서만 사용하는 nonisolated traversal.
///
/// `AXUIElement`를 이 값의 호출 스택 밖으로 반환하지 않는다.
private struct AXAccessibilityScanTraversal {
    private var progressiveYieldInterval: Int { 32 }
    private let client: AXAccessibilityElementClient
    private let configuration: AccessibilityScanConfiguration
    private let clickabilityPolicy: AccessibilityClickabilityPolicy
    private let dateProvider: () -> Date

    init(
        client: AXAccessibilityElementClient,
        configuration: AccessibilityScanConfiguration,
        clickabilityPolicy: AccessibilityClickabilityPolicy = AccessibilityClickabilityPolicy(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.configuration = configuration
        self.clickabilityPolicy = clickabilityPolicy
        self.dateProvider = dateProvider
    }

    func scanProgressively(
        context: TargetContext,
        onProgress: (AccessibilityScanProgress) -> Void
    ) async -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        let startedAt = dateProvider()

        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }

        let root: AXUIElement
        switch client.rootElement(for: context) {
        case .success(let resolvedRoot):
            root = resolvedRoot
        case .failure(let failure):
            return .failure(failure)
        }

        var stack: [(element: AXUIElement, depth: Int)] = [(root, 0)]
        stack.append(contentsOf: client.additionalRootElements(for: context).map { ($0, 0) })
        var nodesVisited = 0
        var candidates: [ClickableCandidate] = []
        var candidateKeys = Set<RuntimeCandidateKey>()
        var didHitDepthLimit = false
        var didHitNodeLimit = false
        var didTimeout = false
        var failedChildReadCount = 0

        while let item = stack.popLast() {
            if Task.isCancelled {
                return .failure(.cancelled)
            }

            if nodesVisited >= configuration.maxNodes {
                didHitNodeLimit = true
                break
            }

            if dateProvider().timeIntervalSince(startedAt) > configuration.timeout {
                didTimeout = true
                break
            }

            nodesVisited += 1
            let inspection = client.inspect(item.element)
            let candidateCountBefore = candidates.count
            if let candidate = makeCandidate(
                from: inspection.snapshot,
                within: context.window.frame
            ),
               candidateKeys.insert(RuntimeCandidateKey(candidate)).inserted {
                candidates.append(candidate)
            }

            guard item.depth < configuration.maxDepth else {
                didHitDepthLimit = true
                continue
            }

            switch inspection.children {
            case .success(let children):
                stack.append(contentsOf: children.reversed().map { ($0, item.depth + 1) })
            case .failure:
                failedChildReadCount += 1
            }

            if candidateCountBefore != candidates.count || nodesVisited.isMultiple(of: progressiveYieldInterval) {
                onProgress(AccessibilityScanProgress(candidates: candidates, nodesVisited: nodesVisited))
                await Task.yield()
            }
        }

        return .success(
            AccessibilityScanResult(
                candidates: candidates,
                nodesVisited: nodesVisited,
                scanDuration: dateProvider().timeIntervalSince(startedAt),
                didHitDepthLimit: didHitDepthLimit,
                didHitNodeLimit: didHitNodeLimit,
                didTimeout: didTimeout,
                failedChildReadCount: failedChildReadCount
            )
        )
    }

    private func makeCandidate(
        from snapshot: AccessibilityElementSnapshot,
        within targetFrame: CGRect
    ) -> ClickableCandidate? {
        guard let role = snapshot.role,
              !snapshot.isSecureField else {
            return nil
        }

        let title: String?
        if clickabilityPolicy.hasClickAction(snapshot.actions)
            || clickabilityPolicy.isFocusableInput(
                role: role,
                subrole: snapshot.subrole,
                actions: snapshot.actions
            )
            || (role != AccessibilityRole.image && clickabilityPolicy.isClickableRole(role)) {
            title = snapshot.title
        } else if role == AccessibilityRole.image {
            title = snapshot.title
            guard clickabilityPolicy.hasSemanticText(
                title: snapshot.title,
                value: snapshot.value,
                help: snapshot.help
            ) else {
                return nil
            }
        } else {
            return nil
        }

        guard let frame = snapshot.frame,
              frame.width > 0,
              frame.height > 0,
              frame.intersects(targetFrame) else {
            return nil
        }

        return ClickableCandidate(
            role: role,
            subrole: snapshot.subrole,
            title: title,
            frame: frame,
            actions: snapshot.actions
        )
    }
}

private struct RuntimeCandidateKey: Hashable {
    private let role: String
    private let subrole: String?
    private let x: Int
    private let y: Int
    private let width: Int
    private let height: Int
    private let actions: [String]

    init(_ candidate: ClickableCandidate) {
        role = candidate.role
        subrole = candidate.subrole
        x = Int(candidate.frame.origin.x.rounded())
        y = Int(candidate.frame.origin.y.rounded())
        width = Int(candidate.frame.width.rounded())
        height = Int(candidate.frame.height.rounded())
        actions = candidate.actions.sorted()
    }
}

/// MainActor overlay 흐름과 직렬 AX runtime을 연결하는 production scanner.
///
/// @author suho.do
/// @since 2026-07-17
@MainActor
final class AXRuntimeScanner: OverlaySessionProgressiveScanning {
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
                case .success(let result):
                    return .success(result)
                case .failure(let failure):
                    return .failure(failure)
                }
            }
        }

        return .failure(.cancelled)
    }
}
