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
}
