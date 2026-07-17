import CoreGraphics
import Foundation
import XCTest
@testable import GazeRow

/// launch evaluation query 요약을 검증한다.
///
/// @author suho.do
/// @since 2026-07-17
final class EvaluationQuerySummarizerTests: XCTestCase {

    func test_summary_elements는현재match의순번과이름을반환한다() {
        // given
        var session = makeSession()
        session.elementMatches = [
            SearchMatch(nodeID: 1, score: 100, matchedFields: [.title], displayName: "First"),
            SearchMatch(nodeID: 2, score: 90, matchedFields: [.title], displayName: "Second")
        ]
        session.elementMatchIndex = 1

        // when
        let result = EvaluationQuerySummarizer().summary(for: .elements, session: session)

        // then
        XCTAssertEqual(
            result,
            EvaluationQuerySummary(
                matchCount: 2,
                matchIndex: 2,
                focusedDisplayName: "Second"
            )
        )
    }

    func test_summary_windows는현재match의순번과이름을반환한다() {
        // given
        var session = makeSession()
        session.windowMatches = [
            WindowMatch(entryID: 3, score: 80, displayLine: "Finder — Downloads")
        ]

        // when
        let result = EvaluationQuerySummarizer().summary(for: .windows, session: session)

        // then
        XCTAssertEqual(
            result,
            EvaluationQuerySummary(
                matchCount: 1,
                matchIndex: 1,
                focusedDisplayName: "Finder — Downloads"
            )
        )
    }

    func test_summary_labels는현재focusLabel을반환한다() {
        // given
        var session = makeSession()
        _ = session.focusEngine.focusItem(id: 0)

        // when
        let result = EvaluationQuerySummarizer().summary(for: .labels, session: session)

        // then
        XCTAssertEqual(
            result,
            EvaluationQuerySummary(
                matchCount: 1,
                matchIndex: 1,
                focusedDisplayName: "A"
            )
        )
    }

    func test_summary_matchIndex가범위를벗어나면_count는유지하고선택은비운다() {
        // given
        var session = makeSession()
        session.elementMatches = [
            SearchMatch(nodeID: 1, score: 100, matchedFields: [.title], displayName: "Only")
        ]
        session.elementMatchIndex = 4

        // when
        let result = EvaluationQuerySummarizer().summary(for: .elements, session: session)

        // then
        XCTAssertEqual(
            result,
            EvaluationQuerySummary(
                matchCount: 1,
                matchIndex: 0,
                focusedDisplayName: nil
            )
        )
    }

    private func makeSession() -> OverlaySessionState {
        let candidate = ClickableCandidate(
            role: AccessibilityRole.button,
            subrole: nil,
            title: "Open",
            frame: CGRect(x: 10, y: 10, width: 40, height: 20),
            actions: [AccessibilityAction.press]
        )
        let layout = OverlayLayout(
            targetFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            localBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            labels: [
                OverlayLabel(
                    id: 0,
                    text: "A",
                    candidateFrame: candidate.frame,
                    labelFrame: candidate.frame,
                    anchorPoint: CGPoint(x: 30, y: 20)
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
        let scanResult = AccessibilityScanResult(
            candidates: [candidate],
            nodesVisited: 1,
            scanDuration: 0,
            didHitDepthLimit: false,
            didHitNodeLimit: false,
            didTimeout: false,
            failedChildReadCount: 0
        )
        let context = TargetContext(
            application: TargetApplication(
                localizedName: "Finder",
                bundleIdentifier: "com.apple.finder",
                processIdentifier: 100
            ),
            window: TargetWindow(
                frame: layout.targetFrame,
                title: "Finder"
            ),
            resolvedAt: Date(timeIntervalSince1970: 1)
        )
        return OverlaySessionState(
            snapshot: OverlaySessionSnapshot(
                context: context,
                scanResult: scanResult,
                layout: layout
            ),
            focusEngine: FocusEngine(layout: layout)
        )
    }
}
