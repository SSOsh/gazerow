import XCTest
@testable import GazeRow

/// OverlayClickFailureGuidance 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-12
final class OverlayClickFailureGuidanceTests: XCTestCase {

    func test_missingFocusedTarget은_label또는_tab을_안내한다() {
        // given
        let failure = OverlaySessionClickFailure.missingFocusedTarget(index: -1)

        // when
        let sut = OverlayClickFailureGuidance(failure: failure)

        // then
        XCTAssertTrue(sut.message.contains("no focused target"))
        XCTAssertTrue(sut.message.contains("Type a label"))
        XCTAssertTrue(sut.message.contains("Tab"))
    }

    func test_scanFailed_permission은_권한재확인을_안내한다() {
        // given
        let failure = OverlaySessionClickFailure.scanFailed(.accessibilityPermissionDenied)

        // when
        let sut = OverlayClickFailureGuidance(failure: failure)

        // then
        XCTAssertTrue(sut.message.contains("permission changed"))
        XCTAssertTrue(sut.message.contains("Recheck Accessibility"))
    }

    func test_missingPressAction은_다른라벨시도를_안내한다() {
        // given
        let failure = OverlaySessionClickFailure.executionFailed(.missingPressAction)

        // when
        let sut = OverlayClickFailureGuidance(failure: failure)

        // then
        XCTAssertTrue(sut.message.contains("no supported action"))
        XCTAssertTrue(sut.message.contains("Try another label"))
    }

    func test_secondConfirmRequired는_위험도를_포함해_재확인을_안내한다() {
        // given
        let failure = OverlaySessionClickFailure.executionFailed(
            .secondConfirmRequired(riskClass: .destructive)
        )

        // when
        let sut = OverlayClickFailureGuidance(failure: failure)

        // then
        XCTAssertEqual(sut.message, "Press Return again to confirm destructive action.")
    }
}
