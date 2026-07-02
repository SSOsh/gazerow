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
    private let dateProvider: () -> Date

    init(
        client: Client,
        configuration: AccessibilityScanConfiguration = AccessibilityScanConfiguration(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.configuration = configuration
        self.dateProvider = dateProvider
    }

    func scan(context: TargetContext) -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        let startedAt = dateProvider()

        switch client.rootElement(for: context) {
        case .success(let root):
            return .success(scan(root: root, startedAt: startedAt))
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func scan(root: Client.Element, startedAt: Date) -> AccessibilityScanResult {
        var stack: [(element: Client.Element, depth: Int)] = [(root, 0)]
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

            let snapshot = client.snapshot(of: item.element)
            if let candidate = makeCandidate(from: snapshot),
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

    private func makeCandidate(from snapshot: AccessibilityElementSnapshot) -> ClickableCandidate? {
        guard !snapshot.isSecureField,
              let role = snapshot.role,
              isClickable(snapshot: snapshot),
              let frame = snapshot.frame,
              frame.width > 0,
              frame.height > 0 else {
            return nil
        }

        return ClickableCandidate(
            role: role,
            subrole: snapshot.subrole,
            title: snapshot.title,
            frame: frame,
            actions: snapshot.actions
        )
    }

    private func isClickable(snapshot: AccessibilityElementSnapshot) -> Bool {
        snapshot.actions.contains(AccessibilityAction.press)
            || snapshot.actions.contains(AccessibilityAction.confirm)
            || clickableRoles.contains(snapshot.role ?? "")
    }

    private var clickableRoles: Set<String> {
        [
            AccessibilityRole.button,
            AccessibilityRole.checkBox,
            AccessibilityRole.comboBox,
            AccessibilityRole.disclosureTriangle,
            AccessibilityRole.link,
            AccessibilityRole.menuButton,
            AccessibilityRole.popUpButton,
            AccessibilityRole.radioButton,
            AccessibilityRole.slider,
            AccessibilityRole.tabGroup,
            AccessibilityRole.textField
        ]
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
