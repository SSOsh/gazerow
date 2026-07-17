import CoreGraphics
import Foundation
import XCTest
@testable import GazeRow

/// OverlaySessionReducer 순수 상태 전이를 검증한다.
///
/// @author suho.do
/// @since 2026-07-17
final class OverlaySessionReducerTests: XCTestCase {

    func test_appendQuery는_첫입력과복합입력을교체하고_단일입력은이어붙인다() {
        // given
        let sut = OverlaySessionReducer()
        var session = makeSession()

        // when
        sut.appendQuery("a", to: &session)
        sut.appendQuery("b", to: &session)
        sut.appendQuery("검색", to: &session)

        // then
        XCTAssertEqual(session.queryInput.buffer, "검색")
        XCTAssertEqual(session.queryInput.lastScope, .elements)
    }

    func test_deleteInput은_query가없으면_labelBuffer를지운다() {
        // given
        let sut = OverlaySessionReducer()
        var session = makeSession()
        _ = session.focusEngine.typeLabelCharacter("A")

        // when
        let hasRemainingQuery = sut.deleteInput(from: &session)

        // then
        XCTAssertFalse(hasRemainingQuery)
        XCTAssertEqual(session.focusEngine.labelBuffer, "")
    }

    func test_selectLabels는_queryMatch와scope상태를초기화한다() {
        // given
        let sut = OverlaySessionReducer()
        var session = makeSession()
        session.queryInput = QueryInputState(buffer: "open", pinnedScope: .elements, lastScope: .elements)
        session.elementMatches = [
            SearchMatch(nodeID: 1, score: 10, matchedFields: [.title], displayName: "Open")
        ]
        session.windowMatches = [
            WindowMatch(entryID: 2, score: 10, displayLine: "Finder")
        ]

        // when
        sut.selectScope(.labels, in: &session)

        // then
        XCTAssertEqual(session.queryInput, QueryInputState(lastScope: .labels))
        XCTAssertTrue(session.elementMatches.isEmpty)
        XCTAssertTrue(session.windowMatches.isEmpty)
    }

    func test_cycleMatches는_양방향으로순환한다() {
        // given
        let sut = OverlaySessionReducer()
        var session = makeSession()
        session.elementMatches = [
            SearchMatch(nodeID: 1, score: 10, matchedFields: [.title], displayName: "One"),
            SearchMatch(nodeID: 2, score: 9, matchedFields: [.title], displayName: "Two")
        ]

        // when
        sut.cycleElementMatch(forward: false, in: &session)
        let previous = session.elementMatchIndex
        sut.cycleElementMatch(forward: true, in: &session)

        // then
        XCTAssertEqual(previous, 1)
        XCTAssertEqual(session.elementMatchIndex, 0)
    }

    func test_input상태전이는_pendingSecondConfirm을초기화한다() {
        // given
        let sut = OverlaySessionReducer()
        var session = makeSession()
        session.pendingSecondConfirm = PendingSecondConfirm(
            focusedItemID: 0,
            riskClass: .destructive
        )

        // when
        sut.pinScope(.windows, in: &session)

        // then
        XCTAssertNil(session.pendingSecondConfirm)
        XCTAssertEqual(session.queryInput.pinnedScope, .windows)
    }

    private func makeSession() -> OverlaySessionState {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let layout = OverlayLayout(
            targetFrame: frame,
            localBounds: frame,
            labels: [
                OverlayLabel(
                    id: 0,
                    text: "A",
                    candidateFrame: frame,
                    labelFrame: frame,
                    anchorPoint: .zero
                )
            ],
            metrics: OverlayLayoutMetrics(
                labelCount: 1,
                collisionCount: 0,
                occlusionCount: 0,
                displayScaleFactor: 2
            ),
            displayInfo: OverlayDisplayInfo(scaleFactor: 2, visibleFrame: nil)
        )
        let candidate = ClickableCandidate(
            role: AccessibilityRole.button,
            subrole: nil,
            title: "Open",
            frame: frame,
            actions: [AccessibilityAction.press]
        )
        let context = TargetContext(
            application: TargetApplication(
                localizedName: "Finder",
                bundleIdentifier: "com.apple.finder",
                processIdentifier: 100
            ),
            window: TargetWindow(frame: frame, title: "Finder"),
            resolvedAt: Date(timeIntervalSince1970: 1)
        )
        return OverlaySessionState(
            snapshot: OverlaySessionSnapshot(
                context: context,
                scanResult: AccessibilityScanResult(
                    candidates: [candidate],
                    nodesVisited: 1,
                    scanDuration: 0,
                    didHitDepthLimit: false,
                    didHitNodeLimit: false,
                    didTimeout: false,
                    failedChildReadCount: 0
                ),
                layout: layout
            ),
            focusEngine: FocusEngine(layout: layout)
        )
    }
}
