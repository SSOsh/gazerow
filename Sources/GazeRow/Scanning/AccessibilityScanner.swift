import CoreGraphics
import Foundation

/// target window의 AX tree에서 clickable candidate를 수집한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct AccessibilityScanner<Client: AccessibilityElementClient> {
    private let client: Client
    private let configuration: AccessibilityScanConfiguration
    private let clickabilityPolicy: AccessibilityClickabilityPolicy
    private let dateProvider: () -> Date

    nonisolated init(
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

    func scan(context: TargetContext) -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        let startedAt = dateProvider()

        switch client.rootElement(for: context) {
        case .success(let root):
            return .success(scan(root: root, context: context, startedAt: startedAt))
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func scan(
        root: Client.Element,
        context: TargetContext,
        startedAt: Date
    ) -> AccessibilityScanResult {
        var stack: [(element: Client.Element, depth: Int)] = [(root, 0)]
        stack.append(contentsOf: client.additionalRootElements(for: context).map { ($0, 0) })
        var nodesVisited = 0
        var candidates: [ClickableCandidate] = []
        var candidateKeys = Set<CandidateKey>()
        var didHitDepthLimit = false
        var didHitNodeLimit = false
        var didTimeout = false
        var failedChildReadCount = 0

        while let item = stack.popLast() {
            if nodesVisited >= configuration.maxNodes {
                didHitNodeLimit = true
                break
            }

            if isTimedOut(startedAt: startedAt) {
                didTimeout = true
                break
            }

            nodesVisited += 1

            if let candidate = makeCandidate(
                from: item.element,
                within: context.window.frame
            ),
               candidateKeys.insert(CandidateKey(candidate)).inserted {
                candidates.append(candidate)
            }

            guard item.depth < configuration.maxDepth else {
                didHitDepthLimit = true
                continue
            }

            switch client.children(of: item.element) {
            case .success(let children):
                stack.append(contentsOf: children.reversed().map { ($0, item.depth + 1) })
            case .failure:
                failedChildReadCount += 1
            }
        }

        let finishedAt = dateProvider()
        return AccessibilityScanResult(
            candidates: candidates,
            nodesVisited: nodesVisited,
            scanDuration: finishedAt.timeIntervalSince(startedAt),
            didHitDepthLimit: didHitDepthLimit,
            didHitNodeLimit: didHitNodeLimit,
            didTimeout: didTimeout,
            failedChildReadCount: failedChildReadCount
        )
    }

    private func isTimedOut(startedAt: Date) -> Bool {
        dateProvider().timeIntervalSince(startedAt) > configuration.timeout
    }

    private func makeCandidate(
        from element: Client.Element,
        within targetFrame: CGRect
    ) -> ClickableCandidate? {
        let snapshot = client.snapshot(of: element)
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
            guard hasSemanticText(in: snapshot) else {
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

    private func hasSemanticText(in snapshot: AccessibilityElementSnapshot) -> Bool {
        clickabilityPolicy.hasSemanticText(
            title: snapshot.title,
            value: snapshot.value,
            help: snapshot.help
        )
    }

}

private struct CandidateKey: Hashable {
    private let role: String
    private let subrole: String?
    private let x: Int
    private let y: Int
    private let width: Int
    private let height: Int
    private let actions: [String]

    init(_ candidate: ClickableCandidate) {
        self.role = candidate.role
        self.subrole = candidate.subrole
        self.x = Int(candidate.frame.origin.x.rounded())
        self.y = Int(candidate.frame.origin.y.rounded())
        self.width = Int(candidate.frame.width.rounded())
        self.height = Int(candidate.frame.height.rounded())
        self.actions = candidate.actions.sorted()
    }
}
