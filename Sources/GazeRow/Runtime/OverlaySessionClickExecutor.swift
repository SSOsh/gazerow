import ApplicationServices
import CoreGraphics
import Foundation

/// overlay focused label을 실제 click execution으로 연결한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
protocol OverlaySessionClickExecuting {
    func execute(
        focusedIndex: Int,
        context: TargetContext,
        isSecondConfirmProvided: Bool
    ) -> Result<ClickExecutionSuccess, OverlaySessionClickFailure>
}

/// overlay session click 실패 사유.
///
/// @author suho.do
/// @since 2026-07-02
enum OverlaySessionClickFailure: Error, Equatable {
    case scanFailed(AccessibilityScanFailure)
    case missingFocusedTarget(index: Int)
    case executionFailed(ClickExecutionFailure)
}

/// production AXPress click executor adapter.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct AXOverlaySessionClickExecutor: OverlaySessionClickExecuting {
    private let targetResolver: OverlaySessionClickTargetResolver<AXAccessibilityElementClient>
    private let clickExecutor: ClickExecutor<AXClickExecutionClient>

    init(
        targetResolver: OverlaySessionClickTargetResolver<AXAccessibilityElementClient> = OverlaySessionClickTargetResolver(client: AXAccessibilityElementClient()),
        clickExecutor: ClickExecutor<AXClickExecutionClient> = ClickExecutor(
            client: AXClickExecutionClient(),
            configuration: .overlayConfirmedClick
        )
    ) {
        self.targetResolver = targetResolver
        self.clickExecutor = clickExecutor
    }

    func execute(
        focusedIndex: Int,
        context: TargetContext,
        isSecondConfirmProvided: Bool
    ) -> Result<ClickExecutionSuccess, OverlaySessionClickFailure> {
        switch targetResolver.resolveTargets(context: context) {
        case .success(let targets):
            guard targets.indices.contains(focusedIndex) else {
                return .failure(.missingFocusedTarget(index: focusedIndex))
            }
            let target = targets[focusedIndex]
            let frameText = "(\(Int(target.frame.minX)),\(Int(target.frame.minY)) \(Int(target.frame.width))x\(Int(target.frame.height)))"
            AppLogger.interaction.info(
                "click target index=\(focusedIndex, privacy: .public) count=\(targets.count, privacy: .public) role=\(target.role, privacy: .public) frame=\(frameText, privacy: .public) actions=\(target.actions.joined(separator: ","), privacy: .public)"
            )
            let request = ClickExecutionRequest(
                target: target,
                isSecondConfirmProvided: isSecondConfirmProvided
            )
            return clickExecutor.execute(request).mapError(OverlaySessionClickFailure.executionFailed)
        case .failure(let failure):
            return .failure(.scanFailed(failure))
        }
    }
}

/// scan 순서와 동일한 순서로 click target element를 수집한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct OverlaySessionClickTargetResolver<Client: AccessibilityElementClient> {
    private let client: Client
    private let configuration: AccessibilityScanConfiguration
    private let clickabilityPolicy: AccessibilityClickabilityPolicy
    private let dateProvider: () -> Date

    init(
        client: Client,
        configuration: AccessibilityScanConfiguration = AccessibilityScanConfiguration(),
        clickabilityPolicy: AccessibilityClickabilityPolicy = AccessibilityClickabilityPolicy(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.configuration = configuration
        self.clickabilityPolicy = clickabilityPolicy
        self.dateProvider = dateProvider
    }

    func resolveTargets(context: TargetContext) -> Result<[ClickTarget<Client.Element>], AccessibilityScanFailure> {
        let startedAt = dateProvider()

        switch client.rootElement(for: context) {
        case .success(let root):
            return .success(resolveTargets(root: root, startedAt: startedAt))
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func resolveTargets(
        root: Client.Element,
        startedAt: Date
    ) -> [ClickTarget<Client.Element>] {
        var stack: [(element: Client.Element, depth: Int)] = [(root, 0)]
        var nodesVisited = 0
        var targets: [ClickTarget<Client.Element>] = []
        var targetKeys = Set<ClickTargetKey>()

        while let item = stack.popLast() {
            if nodesVisited >= configuration.maxNodes || isTimedOut(startedAt: startedAt) {
                break
            }

            nodesVisited += 1

            let snapshot = client.snapshot(of: item.element)
            if let target = makeTarget(element: item.element, snapshot: snapshot),
               targetKeys.insert(ClickTargetKey(target)).inserted {
                targets.append(target)
            }

            guard item.depth < configuration.maxDepth else {
                continue
            }

            if case .success(let children) = client.children(of: item.element) {
                stack.append(contentsOf: children.reversed().map { ($0, item.depth + 1) })
            }
        }

        return targets
    }

    private func makeTarget(
        element: Client.Element,
        snapshot: AccessibilityElementSnapshot
    ) -> ClickTarget<Client.Element>? {
        guard !snapshot.isSecureField,
              let role = snapshot.role,
              clickabilityPolicy.isClickable(snapshot),
              let frame = snapshot.frame,
              frame.width > 0,
              frame.height > 0 else {
            return nil
        }

        return ClickTarget(
            element: element,
            role: role,
            subrole: snapshot.subrole,
            title: snapshot.title,
            frame: frame,
            actions: snapshot.actions
        )
    }

    private func isTimedOut(startedAt: Date) -> Bool {
        dateProvider().timeIntervalSince(startedAt) > configuration.timeout
    }

}

private struct ClickTargetKey: Hashable {
    private let role: String
    private let subrole: String?
    private let x: Int
    private let y: Int
    private let width: Int
    private let height: Int
    private let actions: [String]

    init<Element>(_ target: ClickTarget<Element>) {
        self.role = target.role
        self.subrole = target.subrole
        self.x = Int(target.frame.origin.x.rounded())
        self.y = Int(target.frame.origin.y.rounded())
        self.width = Int(target.frame.width.rounded())
        self.height = Int(target.frame.height.rounded())
        self.actions = target.actions.sorted()
    }
}
