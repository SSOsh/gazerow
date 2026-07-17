import CoreGraphics
import XCTest
@testable import GazeRow

/// OverlayClickTargetDiagnostic 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-14
final class OverlayClickTargetDiagnosticTests: XCTestCase {

    func test_source는_원문title없이_선택candidate의_비교정보를_기록한다() {
        // given
        let candidate = ClickableCandidate(
            role: AccessibilityRole.button,
            subrole: "AXTabButton",
            title: "Private project title",
            frame: CGRect(x: 10.4, y: 20.6, width: 30.2, height: 40.8),
            actions: [AccessibilityAction.press]
        )

        // when
        let message = OverlayClickTargetDiagnostic.source(
            index: 2,
            candidateCount: 7,
            candidate: candidate
        )

        // then
        XCTAssertEqual(
            message,
            "click target diagnostic phase=source index=2 count=7 role=AXButton subrolePresent=true titlePresent=true actionCount=1 frame=(10,21 30x41)"
        )
        XCTAssertFalse(message.contains(candidate.title!))
    }

    func test_resolved는_원문title없이_Enter시점target의_비교정보를_기록한다() {
        // given
        let target = ClickTarget(
            element: 1,
            role: AccessibilityRole.searchField,
            subrole: nil,
            title: "Sensitive search term",
            frame: CGRect(x: 51, y: 82, width: 240, height: 34),
            actions: []
        )

        // when
        let message = OverlayClickTargetDiagnostic.resolved(
            index: 4,
            candidateCount: 9,
            target: target
        )

        // then
        XCTAssertEqual(
            message,
            "click target diagnostic phase=resolved index=4 count=9 role=AXSearchField subrolePresent=false titlePresent=true actionCount=0 frame=(51,82 240x34)"
        )
        XCTAssertFalse(message.contains(target.title!))
    }

    func test_source는_공백title을_없는값으로_기록한다() {
        // given
        let candidate = ClickableCandidate(
            role: AccessibilityRole.button,
            subrole: nil,
            title: "  \n",
            frame: CGRect(x: 0, y: 0, width: 20, height: 20),
            actions: []
        )

        // when
        let message = OverlayClickTargetDiagnostic.source(
            index: 0,
            candidateCount: 1,
            candidate: candidate
        )

        // then
        XCTAssertTrue(message.contains("titlePresent=false"))
    }
}
