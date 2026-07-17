import Foundation

/// overlay의 입력·scope·match 순환 상태를 순수하게 갱신한다.
///
/// @author suho.do
/// @since 2026-07-17
struct OverlaySessionReducer {
    func appendQuery(_ grapheme: String, to session: inout OverlaySessionState) {
        clearSecondConfirm(in: &session)
        if session.queryInput.buffer.isEmpty || grapheme.count > 1 {
            session.queryInput.buffer = grapheme
        } else {
            session.queryInput.buffer.append(grapheme)
        }
        session.queryInput.lastScope = session.queryInput.pinnedScope ?? .elements
    }

    /// query 문자를 지우고 query가 남아 있는지 반환한다.
    @discardableResult
    func deleteInput(from session: inout OverlaySessionState) -> Bool {
        clearSecondConfirm(in: &session)
        guard !session.queryInput.buffer.isEmpty else {
            session.focusEngine.clearLabelBuffer()
            return false
        }
        session.queryInput.buffer.removeLast()
        return !session.queryInput.buffer.isEmpty
    }

    func clearQuery(in session: inout OverlaySessionState) {
        clearSecondConfirm(in: &session)
        session.queryInput = QueryInputState(lastScope: session.queryInput.lastScope)
        session.focusEngine.clearLabelBuffer()
        session.elementMatches = []
        session.elementMatchIndex = 0
    }

    func clearLabelInput(in session: inout OverlaySessionState) {
        clearSecondConfirm(in: &session)
        session.focusEngine.clearLabelBuffer()
        session.queryInput.buffer = ""
        session.queryInput.pinnedScope = nil
    }

    func pinScope(_ scope: QueryScope, in session: inout OverlaySessionState) {
        clearSecondConfirm(in: &session)
        session.queryInput.pinnedScope = scope
        session.queryInput.lastScope = scope
    }

    func selectScope(_ scope: QueryScope, in session: inout OverlaySessionState) {
        clearSecondConfirm(in: &session)
        switch scope {
        case .labels:
            session.queryInput = QueryInputState(lastScope: .labels)
            session.elementMatches = []
            session.elementMatchIndex = 0
            session.windowMatches = []
            session.windowMatchIndex = 0
            session.focusEngine.clearLabelBuffer()
        case .elements, .windows:
            session.queryInput.pinnedScope = scope
            session.queryInput.lastScope = scope
        }
    }

    func cycleElementMatch(forward: Bool, in session: inout OverlaySessionState) {
        guard !session.elementMatches.isEmpty else {
            return
        }
        session.elementMatchIndex = wrappedIndex(
            session.elementMatchIndex,
            count: session.elementMatches.count,
            forward: forward
        )
    }

    func cycleWindowMatch(forward: Bool, in session: inout OverlaySessionState) {
        guard !session.windowMatches.isEmpty else {
            return
        }
        session.windowMatchIndex = wrappedIndex(
            session.windowMatchIndex,
            count: session.windowMatches.count,
            forward: forward
        )
    }

    func shouldCycleQueryMatches(
        _ session: OverlaySessionState,
        scope: QueryScope
    ) -> Bool {
        !session.queryInput.buffer.isEmpty
            && (session.queryInput.pinnedScope ?? session.queryInput.lastScope) == scope
    }

    func clearSecondConfirm(in session: inout OverlaySessionState) {
        session.pendingSecondConfirm = nil
    }

    private func wrappedIndex(_ index: Int, count: Int, forward: Bool) -> Int {
        let delta = forward ? 1 : -1
        return (index + delta + count) % count
    }
}
