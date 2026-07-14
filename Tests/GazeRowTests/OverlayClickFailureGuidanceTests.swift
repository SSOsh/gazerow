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

    func test_selectedTargetChanged는_언어별로_새선택을_안내한다() {
        // given
        let failure = OverlaySessionClickFailure.selectedTargetChanged(labelID: 2)

        // when
        let english = OverlayClickFailureGuidance(failure: failure, language: .english)
        let korean = OverlayClickFailureGuidance(failure: failure, language: .korean)

        // then
        XCTAssertEqual(english.message, "The screen changed, so labels were refreshed. Select again.")
        XCTAssertEqual(korean.message, "화면이 변경되어 라벨을 갱신했습니다. 다시 선택하세요.")
    }

    func test_rescanFailureMessage는_언어별로_안내한다() {
        // when
        let english = OverlayClickFailureGuidance.rescanFailureMessage(language: .english)
        let korean = OverlayClickFailureGuidance.rescanFailureMessage(language: .korean)

        // then
        XCTAssertEqual(english, "The screen could not be rescanned. Try again shortly.")
        XCTAssertEqual(korean, "화면을 다시 읽지 못했습니다. 잠시 후 다시 시도하세요.")
    }
}
