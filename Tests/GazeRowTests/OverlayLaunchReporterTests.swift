import CoreGraphics
import XCTest
@testable import GazeRow

/// `OverlayLaunchReporter`의 stdout 메시지 포맷을 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class OverlayLaunchReporterTests: XCTestCase {

    func test_success_labelCount를_포함한다() {
        // given
        let labelCount = 12

        // when
        let message = OverlayLaunchReporter.success(labelCount: labelCount)

        // then
        XCTAssertEqual(message, "GAZEROW_OVERLAY_RESULT success labels=12")
    }

    func test_failure_logCode를_포함한다() {
        // given
        let logCode = "target_resolution_failed.no_frontmost_application"

        // when
        let message = OverlayLaunchReporter.failure(logCode: logCode)

        // then
        XCTAssertEqual(
            message,
            "GAZEROW_OVERLAY_RESULT failure reason=target_resolution_failed.no_frontmost_application"
        )
    }

    func test_labelMap_label과_candidate정보를_출력한다() {
        // given
        let layout = OverlayLayout(
            targetFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            localBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            labels: [
                OverlayLabel(
                    id: 0,
                    text: "A",
                    candidateFrame: CGRect(x: 10, y: 20, width: 30, height: 40),
                    labelFrame: CGRect(x: 10, y: 0, width: 32, height: 22),
                    anchorPoint: CGPoint(x: 25, y: 40)
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
        let candidates = [
            ClickableCandidate(
                role: AccessibilityRole.button,
                subrole: nil,
                title: "Open Folder",
                frame: CGRect(x: 10, y: 20, width: 30, height: 40),
                actions: [AccessibilityAction.press]
            )
        ]

        // when
        let result = OverlayLaunchReporter.labelMap(layout: layout, candidates: candidates)

        // then
        XCTAssertEqual(
            result,
            [
                "GAZEROW_OVERLAY_LABEL index=0 label=A role=AXButton title=Open_Folder frame=10,20,30,40 actions=AXPress"
            ]
        )
    }
}
