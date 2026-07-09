import CoreGraphics
import Foundation

/// Query Overlay 입력 해석 결과.
///
/// @author suho.do
/// @since 2026-07-09
struct QueryResolution: Equatable {
    let scope: QueryScope
    let matchCount: Int
    let matchIndex: Int
    let focusedDisplayName: String?
    let focusTargetCandidateIndex: Int?
    let highlightFrame: CGRect?
    let promotionMethod: PromotionMethod?
    let windowEntryID: Int?

    init(
        scope: QueryScope,
        matchCount: Int,
        matchIndex: Int,
        focusedDisplayName: String?,
        focusTargetCandidateIndex: Int?,
        highlightFrame: CGRect?,
        promotionMethod: PromotionMethod?,
        windowEntryID: Int? = nil
    ) {
        self.scope = scope
        self.matchCount = matchCount
        self.matchIndex = matchIndex
        self.focusedDisplayName = focusedDisplayName
        self.focusTargetCandidateIndex = focusTargetCandidateIndex
        self.highlightFrame = highlightFrame
        self.promotionMethod = promotionMethod
        self.windowEntryID = windowEntryID
    }
}

/// Query buffer를 label/element intent로 해석한다.
///
/// @author suho.do
/// @since 2026-07-09
struct IntentRouter {
    private let promoter: ActionablePromoter

    init(promoter: ActionablePromoter = ActionablePromoter()) {
        self.promoter = promoter
    }

    func resolve(
        queryInput: QueryInputState,
        focusEngine: FocusEngine,
        elementIndex: ElementSearchIndex,
        elementMatchIndex: Int,
        actionableCandidates: [ClickableCandidate],
        windowIndex: WindowSearchIndex = WindowSearchIndex(entries: []),
        windowMatchIndex: Int = 0
    ) -> QueryResolution {
        let matches = elementIndex.search(queryInput.buffer)
        let windowMatches = windowIndex.search(queryInput.buffer)
        let scope = chooseScope(
            buffer: queryInput.buffer,
            pinnedScope: queryInput.pinnedScope,
            focusEngine: focusEngine,
            elementMatches: matches,
            windowMatches: windowMatches,
            lastScope: queryInput.lastScope
        )

        switch scope {
        case .labels:
            return QueryResolution(
                scope: .labels,
                matchCount: focusEngine.items.count,
                matchIndex: focusEngine.focusedItemID ?? 0,
                focusedDisplayName: nil,
                focusTargetCandidateIndex: focusEngine.focusedItemID,
                highlightFrame: nil,
                promotionMethod: nil
            )
        case .elements:
            return elementResolution(
                matches: matches,
                matchIndex: elementMatchIndex,
                elementIndex: elementIndex,
                actionableCandidates: actionableCandidates
            )
        case .windows:
            return windowResolution(
                matches: windowMatches,
                matchIndex: windowMatchIndex
            )
        }
    }

    func chooseScope(
        buffer: String,
        pinnedScope: QueryScope?,
        focusEngine: FocusEngine,
        elementMatches: [SearchMatch],
        windowMatches: [WindowMatch] = [],
        lastScope: QueryScope
    ) -> QueryScope {
        if let pinnedScope {
            return pinnedScope
        }

        let normalized = buffer.uppercased()
        if isPotentialLabel(normalized),
           focusEngine.items.contains(where: { $0.label.hasPrefix(normalized) }) {
            return .labels
        }

        if buffer.count >= 2 || containsHangul(buffer) || buffer.contains(" ") {
            return .elements
        }

        if !elementMatches.isEmpty {
            return .elements
        }

        if !windowMatches.isEmpty {
            return .windows
        }

        return lastScope == .windows ? .elements : lastScope
    }

    private func elementResolution(
        matches: [SearchMatch],
        matchIndex: Int,
        elementIndex: ElementSearchIndex,
        actionableCandidates: [ClickableCandidate]
    ) -> QueryResolution {
        guard !matches.isEmpty else {
            return QueryResolution(
                scope: .elements,
                matchCount: 0,
                matchIndex: 0,
                focusedDisplayName: nil,
                focusTargetCandidateIndex: nil,
                highlightFrame: nil,
                promotionMethod: nil
            )
        }

        let safeIndex = (matchIndex + matches.count) % matches.count
        let match = matches[safeIndex]
        let node = elementIndex.node(id: match.nodeID)
        let promotion = promoter.promote(
            searchNodeID: match.nodeID,
            index: elementIndex,
            actionableCandidates: actionableCandidates
        )

        return QueryResolution(
            scope: .elements,
            matchCount: matches.count,
            matchIndex: safeIndex,
            focusedDisplayName: match.displayName,
            focusTargetCandidateIndex: promotion.actionableCandidateIndex,
            highlightFrame: node?.frame,
            promotionMethod: promotion.method
        )
    }

    private func windowResolution(
        matches: [WindowMatch],
        matchIndex: Int
    ) -> QueryResolution {
        guard !matches.isEmpty else {
            return QueryResolution(
                scope: .windows,
                matchCount: 0,
                matchIndex: 0,
                focusedDisplayName: nil,
                focusTargetCandidateIndex: nil,
                highlightFrame: nil,
                promotionMethod: nil
            )
        }

        let safeIndex = (matchIndex + matches.count) % matches.count
        let match = matches[safeIndex]
        return QueryResolution(
            scope: .windows,
            matchCount: matches.count,
            matchIndex: safeIndex,
            focusedDisplayName: match.displayLine,
            focusTargetCandidateIndex: nil,
            highlightFrame: nil,
            promotionMethod: nil,
            windowEntryID: match.entryID
        )
    }

    private func isPotentialLabel(_ buffer: String) -> Bool {
        guard (1...2).contains(buffer.count) else {
            return false
        }

        return buffer.allSatisfy { $0.isASCII && $0.isLetter }
    }

    private func containsHangul(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            (0xAC00...0xD7AF).contains(Int(scalar.value))
                || (0x3130...0x318F).contains(Int(scalar.value))
        }
    }
}
