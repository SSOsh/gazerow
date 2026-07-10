import CoreGraphics
import XCTest
@testable import GazeRow

/// IntentRouter 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-09
final class IntentRouterTests: XCTestCase {

    func test_chooseScope_pinnedScope가_최우선이다() {
        // given
        let sut = IntentRouter()

        // when
        let scope = sut.chooseScope(
            buffer: "slack",
            pinnedScope: .windows,
            focusEngine: focusEngine,
            elementMatches: [match(nodeID: 0)],
            windowMatches: [windowMatch(entryID: 0)],
            lastScope: .elements
        )

        // then
        XCTAssertEqual(scope, .windows)
    }

    func test_chooseScope_labelPrefix가_있으면_labels를_선택한다() {
        // given
        let sut = IntentRouter()

        // when
        let scope = sut.chooseScope(
            buffer: "A",
            pinnedScope: nil,
            focusEngine: focusEngine,
            elementMatches: [],
            lastScope: .elements
        )

        // then
        XCTAssertEqual(scope, .labels)
    }

    func test_chooseScope_두글자이상은_매칭이_없으면_elements를_선택한다() {
        // given
        let sut = IntentRouter()

        // when
        let scope = sut.chooseScope(
            buffer: "de",
            pinnedScope: nil,
            focusEngine: focusEngine,
            elementMatches: [],
            lastScope: .labels
        )

        // then
        XCTAssertEqual(scope, .elements)
    }

    func test_chooseScope_windowMatch만_있으면_두글자이상도_windows를_선택한다() {
        // given
        let sut = IntentRouter()

        // when
        let scope = sut.chooseScope(
            buffer: "safari",
            pinnedScope: nil,
            focusEngine: focusEngine,
            elementMatches: [],
            windowMatches: [windowMatch(entryID: 0, score: 80)],
            lastScope: .labels
        )

        // then
        XCTAssertEqual(scope, .windows)
    }

    func test_chooseScope_element와_window가_모두_있으면_높은_score_scope를_선택한다() {
        // given
        let sut = IntentRouter()

        // when
        let scope = sut.chooseScope(
            buffer: "xcode",
            pinnedScope: nil,
            focusEngine: focusEngine,
            elementMatches: [match(nodeID: 0, score: 40)],
            windowMatches: [windowMatch(entryID: 0, score: 150)],
            lastScope: .elements
        )

        // then
        XCTAssertEqual(scope, .windows)
    }

    func test_chooseScope_최근scope가_windows이면_동시매칭에서_windows를_유지한다() {
        // given
        let sut = IntentRouter()

        // when
        let scope = sut.chooseScope(
            buffer: "code",
            pinnedScope: nil,
            focusEngine: focusEngine,
            elementMatches: [match(nodeID: 0, score: 120)],
            windowMatches: [windowMatch(entryID: 0, score: 60)],
            lastScope: .windows
        )

        // then
        XCTAssertEqual(scope, .windows)
    }

    func test_chooseScope_한글은_elements를_선택한다() {
        // given
        let sut = IntentRouter()

        // when
        let scope = sut.chooseScope(
            buffer: "삭제",
            pinnedScope: nil,
            focusEngine: focusEngine,
            elementMatches: [],
            lastScope: .labels
        )

        // then
        XCTAssertEqual(scope, .elements)
    }

    func test_resolve_elements는_searchMatch를_promotion된_candidate로_연결한다() {
        // given
        let candidate = ClickableCandidate(
            role: AccessibilityRole.button,
            subrole: nil,
            title: "Delete",
            frame: CGRect(x: 10, y: 10, width: 20, height: 20),
            actions: [AccessibilityAction.press]
        )
        let index = ElementSearchIndex(nodes: [
            SearchableNode(
                id: 0,
                role: AccessibilityRole.button,
                title: "Delete",
                frame: candidate.frame
            )
        ])
        let sut = IntentRouter()

        // when
        let resolution = sut.resolve(
            queryInput: QueryInputState(buffer: "delete", lastScope: .elements),
            focusEngine: focusEngine,
            elementIndex: index,
            elementMatchIndex: 0,
            actionableCandidates: [candidate]
        )

        // then
        XCTAssertEqual(resolution.scope, .elements)
        XCTAssertEqual(resolution.matchCount, 1)
        XCTAssertEqual(resolution.matchIndex, 0)
        XCTAssertEqual(resolution.focusedDisplayName, "Delete")
        XCTAssertEqual(resolution.focusTargetCandidateIndex, 0)
        XCTAssertEqual(resolution.promotionMethod, .direct)
    }

    func test_resolve_elements_match가_없으면_clickTarget이_nil이다() {
        // given
        let sut = IntentRouter()

        // when
        let resolution = sut.resolve(
            queryInput: QueryInputState(buffer: "missing", lastScope: .elements),
            focusEngine: focusEngine,
            elementIndex: ElementSearchIndex(nodes: []),
            elementMatchIndex: 0,
            actionableCandidates: []
        )

        // then
        XCTAssertEqual(resolution.scope, .elements)
        XCTAssertEqual(resolution.matchCount, 0)
        XCTAssertNil(resolution.focusTargetCandidateIndex)
    }

    func test_resolve_windows는_windowMatch를_반환한다() {
        // given
        let windowIndex = WindowSearchIndex(entries: [
            WindowEntry(
                id: 7,
                appName: "Slack",
                bundleID: "com.tinyspeck.slackmacgap",
                windowTitle: "#general",
                windowTitleHash: "hash",
                pid: 100,
                axWindow: nil,
                appIcon: nil
            )
        ])
        let sut = IntentRouter()

        // when
        let resolution = sut.resolve(
            queryInput: QueryInputState(buffer: "slack", pinnedScope: .windows, lastScope: .windows),
            focusEngine: focusEngine,
            elementIndex: ElementSearchIndex(nodes: [
                SearchableNode(id: 0, role: AccessibilityRole.button, title: "slack", frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            ]),
            elementMatchIndex: 0,
            actionableCandidates: [],
            windowIndex: windowIndex,
            windowMatchIndex: 0
        )

        // then
        XCTAssertEqual(resolution.scope, .windows)
        XCTAssertEqual(resolution.matchCount, 1)
        XCTAssertEqual(resolution.focusedDisplayName, "Slack — #general")
        XCTAssertEqual(resolution.windowEntryID, 7)
        XCTAssertNil(resolution.focusTargetCandidateIndex)
    }

    private var focusEngine: FocusEngine {
        FocusEngine(
            items: [
                FocusItem(id: 0, label: "A", frame: CGRect(x: 0, y: 0, width: 10, height: 10)),
                FocusItem(id: 1, label: "B", frame: CGRect(x: 0, y: 20, width: 10, height: 10))
            ]
        )
    }

    private func match(nodeID: Int, score: Int = 100) -> SearchMatch {
        SearchMatch(
            nodeID: nodeID,
            score: score,
            matchedFields: [.title],
            displayName: "Match"
        )
    }

    private func windowMatch(entryID: Int, score: Int = 100) -> WindowMatch {
        WindowMatch(entryID: entryID, score: score, displayLine: "Window")
    }
}
