import CoreGraphics
import XCTest
@testable import GazeRow

/// `OverlayLaunchReporter`의 stdout 메시지 포맷을 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class OverlayLaunchReporterTests: XCTestCase {

    func test_starting_bundleIdentifier를_포함한다() {
        // given
        let bundleIdentifier = "com.microsoft.VSCode"

        // when
        let message = OverlayLaunchReporter.starting(bundleIdentifier: bundleIdentifier)

        // then
        XCTAssertEqual(message, "GAZEROW_OVERLAY_RESULT starting bundle=com.microsoft.VSCode")
    }

    func test_starting_bundleIdentifier가_없으면_frontmost를_출력한다() {
        // when
        let message = OverlayLaunchReporter.starting(bundleIdentifier: nil)

        // then
        XCTAssertEqual(message, "GAZEROW_OVERLAY_RESULT starting bundle=<frontmost>")
    }

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

    func test_failureDetails_noCandidates는_scan집계만_출력한다() {
        // given
        let context = TargetContext(
            application: TargetApplication(
                localizedName: "Discord",
                bundleIdentifier: "com.hnc.Discord",
                processIdentifier: 100
            ),
            window: TargetWindow(
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                title: "Private Window Title"
            ),
            resolvedAt: Date(timeIntervalSince1970: 1_788_800_000)
        )
        let scanResult = AccessibilityScanResult(
            candidates: [],
            nodesVisited: 37,
            scanDuration: 0.1234,
            didHitDepthLimit: false,
            didHitNodeLimit: true,
            didTimeout: false,
            failedChildReadCount: 2
        )

        // when
        let result = OverlayLaunchReporter.failureDetails(
            .noCandidates(context: context, scanResult: scanResult)
        )

        // then
        XCTAssertEqual(
            result,
            [
                "GAZEROW_OVERLAY_SCAN_SUMMARY bundle=com.hnc.Discord candidates=0 nodes=37 duration_ms=123 depth_limit=false node_limit=true timeout=false failed_child_reads=2"
            ]
        )
        XCTAssertFalse(result.joined(separator: " ").contains("Private Window Title"))
    }

    func test_failureDetails_noCandidates외_실패는_빈배열() {
        // when
        let result = OverlayLaunchReporter.failureDetails(.sessionDisabled)

        // then
        XCTAssertTrue(result.isEmpty)
    }

    func test_clickResult_success_method와_risk를_출력한다() {
        // given
        let success = ClickExecutionSuccess(
            method: .accessibilityAction(AccessibilityAction.open),
            riskClass: .safeNavigation,
            fallbackUsed: false
        )

        // when
        let message = OverlayLaunchReporter.clickResult(.success(success))

        // then
        XCTAssertEqual(
            message,
            "GAZEROW_OVERLAY_CLICK_RESULT success method=accessibilityAction.AXOpen risk=safeNavigation fallback=false"
        )
    }

    func test_clickResult_failure_reason을_출력한다() {
        // when
        let message = OverlayLaunchReporter.clickResult(
            .failure(.executionFailed(.secondConfirmRequired(riskClass: .destructive)))
        )

        // then
        XCTAssertEqual(
            message,
            "GAZEROW_OVERLAY_CLICK_RESULT failure reason=execution_failed.second_confirm_required.destructive"
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
