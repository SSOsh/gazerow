import CoreGraphics
import Foundation

/// 최초 overlay 후보와 Enter 시점 click target을 안전하게 연결한다.
///
/// @author suho.do
/// @since 2026-07-14
struct OverlayClickTargetMatcher {
    private let configuration: OverlayClickTargetMatchConfiguration

    init(configuration: OverlayClickTargetMatchConfiguration = OverlayClickTargetMatchConfiguration()) {
        self.configuration = configuration
    }

    func match<Element>(
        selection: OverlayClickSelection,
        currentTargets: [ClickTarget<Element>]
    ) -> OverlayClickTargetMatch<Element> {
        let matches = currentTargets.enumerated().filter { item in
            isDescriptorMatch(selection.candidate, target: item.element)
        }

        switch matches.count {
        case 1:
            let match = matches[0]
            return .matched(
                target: match.element,
                metadata: metadata(
                    strategy: match.offset == selection.labelID
                        ? .validatedOriginalIndex
                        : .descriptor,
                    selection: selection,
                    currentTargets: currentTargets,
                    currentIndex: match.offset,
                    target: match.element
                )
            )
        case 0:
            return hasChangedCandidate(for: selection.candidate, in: currentTargets)
                ? .changed
                : .unavailable
        default:
            return .ambiguous
        }
    }

    private func isDescriptorMatch<Element>(
        _ candidate: ClickableCandidate,
        target: ClickTarget<Element>
    ) -> Bool {
        hasMatchingSemantics(candidate, target: target)
            && centerDistance(from: candidate.frame, to: target.frame) <= configuration.maximumCenterDistance
    }

    private func hasChangedCandidate<Element>(
        for candidate: ClickableCandidate,
        in currentTargets: [ClickTarget<Element>]
    ) -> Bool {
        currentTargets.contains { target in
            hasMatchingSemantics(candidate, target: target)
        }
    }

    private func hasMatchingSemantics<Element>(
        _ candidate: ClickableCandidate,
        target: ClickTarget<Element>
    ) -> Bool {
        guard candidate.role == target.role else {
            return false
        }

        if let subrole = candidate.subrole, subrole != target.subrole {
            return false
        }

        if let title = normalizedText(candidate.title) {
            return normalizedText(target.title) == title
        }

        return candidate.subrole != nil || !Set(candidate.actions).intersection(target.actions).isEmpty
    }

    private func metadata<Element>(
        strategy: OverlayClickTargetMatchStrategy,
        selection: OverlayClickSelection,
        currentTargets: [ClickTarget<Element>],
        currentIndex: Int,
        target: ClickTarget<Element>
    ) -> OverlayClickTargetMatchMetadata {
        OverlayClickTargetMatchMetadata(
            strategy: strategy,
            sourceCandidateCount: selection.sourceCandidateCount,
            currentCandidateCount: currentTargets.count,
            sourceIndex: selection.labelID,
            currentIndex: currentIndex,
            centerDistance: centerDistance(from: selection.candidate.frame, to: target.frame),
            roleMatches: selection.candidate.role == target.role,
            subroleMatches: selection.candidate.subrole == nil || selection.candidate.subrole == target.subrole,
            titleMatches: normalizedText(selection.candidate.title) == normalizedText(target.title),
            actionsOverlap: !Set(selection.candidate.actions).intersection(target.actions).isEmpty
        )
    }

    private func centerDistance(from lhs: CGRect, to rhs: CGRect) -> CGFloat {
        hypot(lhs.midX - rhs.midX, lhs.midY - rhs.midY)
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalized = value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
        return normalized.isEmpty ? nil : normalized
    }
}

/// click target 일치 판정 설정.
///
/// @author suho.do
/// @since 2026-07-14
struct OverlayClickTargetMatchConfiguration: Equatable {
    let maximumCenterDistance: CGFloat

    init(maximumCenterDistance: CGFloat = 12) {
        self.maximumCenterDistance = max(0, maximumCenterDistance)
    }
}

/// click target 일치 경로.
///
/// @author suho.do
/// @since 2026-07-14
enum OverlayClickTargetMatchStrategy: String, Equatable {
    case validatedOriginalIndex
    case descriptor
}

/// 개인정보 없이 target 일치 결과를 설명하는 metadata.
///
/// @author suho.do
/// @since 2026-07-14
struct OverlayClickTargetMatchMetadata: Equatable {
    let strategy: OverlayClickTargetMatchStrategy
    let sourceCandidateCount: Int
    let currentCandidateCount: Int
    let sourceIndex: Int
    let currentIndex: Int
    let centerDistance: CGFloat
    let roleMatches: Bool
    let subroleMatches: Bool
    let titleMatches: Bool
    let actionsOverlap: Bool
}

/// click target 일치 판정 결과.
///
/// @author suho.do
/// @since 2026-07-14
enum OverlayClickTargetMatch<Element> {
    case matched(target: ClickTarget<Element>, metadata: OverlayClickTargetMatchMetadata)
    case unavailable
    case changed
    case ambiguous
}
