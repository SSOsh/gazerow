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
    /// element·window score 경합에서 scope가 한 글자 차이로 뒤집히는 진동을 막는 margin.
    /// 승자가 이 값 이상 앞서야 전환하고, margin 이내면 직전 scope에 관성을 준다.
    static let scopeScoreMargin = 20

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

        if let scope = bestSearchScope(
            elementMatches: elementMatches,
            windowMatches: windowMatches,
            lastScope: lastScope
        ) {
            return scope
        }

        if buffer.count >= 2 || containsHangul(buffer) || buffer.contains(" ") {
            return .elements
        }

        return lastScope == .windows ? .elements : lastScope
    }

    private func bestSearchScope(
        elementMatches: [SearchMatch],
        windowMatches: [WindowMatch],
        lastScope: QueryScope
    ) -> QueryScope? {
        guard !elementMatches.isEmpty || !windowMatches.isEmpty else {
            return nil
        }

        guard !elementMatches.isEmpty else {
            return .windows
        }

        guard !windowMatches.isEmpty else {
            return .elements
        }

        // 둘 다 매치: score 경합. 승자가 margin 이상 앞서야 전환하고,
        // margin 이내(경합)면 직전 scope에 관성을 준다(양방향 대칭 히스테리시스).
        let bestElementScore = elementMatches.map(\.score).max() ?? 0
        let bestWindowScore = windowMatches.map(\.score).max() ?? 0
        return resolveContestedScope(
            elementScore: bestElementScore,
            windowScore: bestWindowScore,
            lastScope: lastScope
        )
    }

    private func resolveContestedScope(
        elementScore: Int,
        windowScore: Int,
        lastScope: QueryScope
    ) -> QueryScope {
        let difference = windowScore - elementScore
        if difference > Self.scopeScoreMargin {
            return .windows
        }
        if difference < -Self.scopeScoreMargin {
            return .elements
        }

        // margin 이내 경합: 직전이 windows면 windows를 유지하고, 그 외에는 elements로 안정화한다.
        return lastScope == .windows ? .windows : .elements
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
