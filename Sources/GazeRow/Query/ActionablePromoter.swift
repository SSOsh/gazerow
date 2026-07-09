import CoreGraphics
import Foundation

/// 검색 node를 실제 클릭 가능한 overlay candidate로 승격한 결과.
///
/// @author suho.do
/// @since 2026-07-09
struct ActionablePromotionResult: Equatable {
    let searchNodeID: Int
    let actionableCandidateIndex: Int?
    let method: PromotionMethod?
    let failure: PromotionFailure?
}

/// Query search hit과 click target을 연결한 방법.
///
/// @author suho.do
/// @since 2026-07-09
enum PromotionMethod: Equatable {
    case direct
    case ancestor(levels: Int)
    case descendant(levels: Int)
    case spatial(distance: CGFloat)
}

/// Query search hit을 click target으로 승격하지 못한 이유.
///
/// @author suho.do
/// @since 2026-07-09
enum PromotionFailure: Equatable {
    case searchNodeMissing
    case notActionable
    case noAncestor
    case noDescendant
    case noSpatialNeighbor
}

/// 검색된 node를 clickable candidate로 연결하는 heuristic.
///
/// @author suho.do
/// @since 2026-07-09
struct ActionablePromoter {
    private let maxAncestorLevels: Int
    private let maxDescendantLevels: Int
    private let maxSpatialDistance: CGFloat

    init(
        maxAncestorLevels: Int = 4,
        maxDescendantLevels: Int = 2,
        maxSpatialDistance: CGFloat = 40
    ) {
        self.maxAncestorLevels = max(0, maxAncestorLevels)
        self.maxDescendantLevels = max(0, maxDescendantLevels)
        self.maxSpatialDistance = max(0, maxSpatialDistance)
    }

    func promote(
        searchNodeID: Int,
        index: ElementSearchIndex,
        actionableCandidates: [ClickableCandidate]
    ) -> ActionablePromotionResult {
        guard let searchNode = index.node(id: searchNodeID) else {
            return failure(searchNodeID: searchNodeID, failure: .searchNodeMissing)
        }

        let actionableIndexByNodeID = makeActionableIndexByNodeID(
            nodes: index.nodes,
            candidates: actionableCandidates
        )

        if let candidateIndex = actionableIndexByNodeID[searchNode.id] {
            return success(searchNodeID: searchNodeID, candidateIndex: candidateIndex, method: .direct)
        }

        if let ancestor = promoteAncestor(
            from: searchNode,
            index: index,
            actionableIndexByNodeID: actionableIndexByNodeID
        ) {
            return success(
                searchNodeID: searchNodeID,
                candidateIndex: ancestor.candidateIndex,
                method: .ancestor(levels: ancestor.levels)
            )
        }

        if let descendant = promoteDescendant(
            from: searchNode,
            index: index,
            actionableIndexByNodeID: actionableIndexByNodeID
        ) {
            return success(
                searchNodeID: searchNodeID,
                candidateIndex: descendant.candidateIndex,
                method: .descendant(levels: descendant.levels)
            )
        }

        if let spatial = promoteSpatial(
            from: searchNode,
            candidates: actionableCandidates
        ) {
            return success(
                searchNodeID: searchNodeID,
                candidateIndex: spatial.candidateIndex,
                method: .spatial(distance: spatial.distance)
            )
        }

        return failure(searchNodeID: searchNodeID, failure: .noSpatialNeighbor)
    }

    private func promoteAncestor(
        from node: SearchableNode,
        index: ElementSearchIndex,
        actionableIndexByNodeID: [Int: Int]
    ) -> (candidateIndex: Int, levels: Int)? {
        var currentParentID = node.parentID
        var levels = 0

        while let parentID = currentParentID, levels < maxAncestorLevels {
            levels += 1
            if let candidateIndex = actionableIndexByNodeID[parentID] {
                return (candidateIndex, levels)
            }
            currentParentID = index.node(id: parentID)?.parentID
        }

        return nil
    }

    private func promoteDescendant(
        from node: SearchableNode,
        index: ElementSearchIndex,
        actionableIndexByNodeID: [Int: Int]
    ) -> (candidateIndex: Int, levels: Int)? {
        var queue = node.childrenIDs.map { (nodeID: $0, level: 1) }
        var cursor = 0

        while cursor < queue.count {
            let item = queue[cursor]
            cursor += 1

            guard item.level <= maxDescendantLevels else {
                continue
            }

            if let candidateIndex = actionableIndexByNodeID[item.nodeID] {
                return (candidateIndex, item.level)
            }

            guard let child = index.node(id: item.nodeID) else {
                continue
            }

            queue.append(contentsOf: child.childrenIDs.map { (nodeID: $0, level: item.level + 1) })
        }

        return nil
    }

    private func promoteSpatial(
        from node: SearchableNode,
        candidates: [ClickableCandidate]
    ) -> (candidateIndex: Int, distance: CGFloat)? {
        let center = node.frame.center
        return candidates.enumerated()
            .filter { !$0.element.isSecure }
            .map { offset, candidate in
                (
                    candidateIndex: offset,
                    distance: center.distance(to: candidate.frame.center),
                    hasPress: candidate.actions.contains(AccessibilityAction.press)
                )
            }
            .filter { $0.distance <= maxSpatialDistance }
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance {
                    return lhs.distance < rhs.distance
                }
                if lhs.hasPress != rhs.hasPress {
                    return lhs.hasPress
                }
                return lhs.candidateIndex < rhs.candidateIndex
            }
            .first
            .map { (candidateIndex: $0.candidateIndex, distance: $0.distance) }
    }

    private func makeActionableIndexByNodeID(
        nodes: [SearchableNode],
        candidates: [ClickableCandidate]
    ) -> [Int: Int] {
        var result: [Int: Int] = [:]
        let nodeKeyByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, ActionableKey(node: $0)) })

        for (candidateIndex, candidate) in candidates.enumerated() where !candidate.isSecure {
            let candidateKey = ActionableKey(candidate: candidate)
            guard let nodeID = nodeKeyByID.first(where: { $0.value == candidateKey })?.key else {
                continue
            }
            result[nodeID] = candidateIndex
        }

        return result
    }

    private func success(
        searchNodeID: Int,
        candidateIndex: Int,
        method: PromotionMethod
    ) -> ActionablePromotionResult {
        ActionablePromotionResult(
            searchNodeID: searchNodeID,
            actionableCandidateIndex: candidateIndex,
            method: method,
            failure: nil
        )
    }

    private func failure(
        searchNodeID: Int,
        failure: PromotionFailure
    ) -> ActionablePromotionResult {
        ActionablePromotionResult(
            searchNodeID: searchNodeID,
            actionableCandidateIndex: nil,
            method: nil,
            failure: failure
        )
    }
}

private struct ActionableKey: Equatable {
    let role: String
    let subrole: String?
    let title: String?
    let frame: CGRect

    init(node: SearchableNode) {
        self.role = node.role ?? ""
        self.subrole = node.subrole
        self.title = node.title
        self.frame = node.frame
    }

    init(candidate: ClickableCandidate) {
        self.role = candidate.role
        self.subrole = candidate.subrole
        self.title = candidate.title
        self.frame = candidate.frame
    }
}

private extension ClickableCandidate {
    var isSecure: Bool {
        role == AccessibilityRole.secureTextField
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        hypot(x - point.x, y - point.y)
    }
}
