import Foundation

/// launch evaluation에 출력할 현재 query 선택 요약.
///
/// @author suho.do
/// @since 2026-07-17
struct EvaluationQuerySummary: Equatable {
    let matchCount: Int
    let matchIndex: Int
    let focusedDisplayName: String?
}

/// overlay session state를 launch evaluation용 query 요약으로 변환한다.
///
/// @author suho.do
/// @since 2026-07-17
struct EvaluationQuerySummarizer {
    func summary(
        for scope: QueryScope,
        session: OverlaySessionState
    ) -> EvaluationQuerySummary {
        switch scope {
        case .elements:
            elementSummary(session)
        case .windows:
            windowSummary(session)
        case .labels:
            labelSummary(session)
        }
    }

    private func elementSummary(_ session: OverlaySessionState) -> EvaluationQuerySummary {
        let match = session.elementMatches.indices.contains(session.elementMatchIndex)
            ? session.elementMatches[session.elementMatchIndex]
            : nil
        return EvaluationQuerySummary(
            matchCount: session.elementMatches.count,
            matchIndex: match == nil ? 0 : session.elementMatchIndex + 1,
            focusedDisplayName: match?.displayName
        )
    }

    private func windowSummary(_ session: OverlaySessionState) -> EvaluationQuerySummary {
        let match = session.windowMatches.indices.contains(session.windowMatchIndex)
            ? session.windowMatches[session.windowMatchIndex]
            : nil
        return EvaluationQuerySummary(
            matchCount: session.windowMatches.count,
            matchIndex: match == nil ? 0 : session.windowMatchIndex + 1,
            focusedDisplayName: match?.displayLine
        )
    }

    private func labelSummary(_ session: OverlaySessionState) -> EvaluationQuerySummary {
        let label = session.snapshot.layout.labels.first {
            $0.id == session.focusEngine.focusedItemID
        }
        return EvaluationQuerySummary(
            matchCount: label == nil ? 0 : 1,
            matchIndex: label == nil ? 0 : 1,
            focusedDisplayName: label?.text
        )
    }
}
