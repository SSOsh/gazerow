import XCTest
@testable import GazeRow

/// `GazeActivationBlockGuidance` 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeActivationBlockGuidanceTests: XCTestCase {

    func test_optIn차단이면_설정열기_안내() {
        // given
        let sut = GazeActivationBlockGuidance(reason: .optInDisabled)

        // then
        XCTAssertEqual(sut.actionButtonTitle, "Open Settings")
        XCTAssertEqual(sut.cancelButtonTitle, "Cancel")
        XCTAssertTrue(sut.message.contains("gaze focus"))
        XCTAssertFalse(sut.title.isEmpty)
    }

    func test_권한차단이면_카메라설정_안내() {
        // given
        let sut = GazeActivationBlockGuidance(reason: .cameraPermissionDenied)

        // then
        XCTAssertEqual(sut.actionButtonTitle, "Open Camera Settings")
        XCTAssertEqual(sut.cancelButtonTitle, "Cancel")
        XCTAssertTrue(sut.message.contains("camera"))
        XCTAssertFalse(sut.title.isEmpty)
    }

    func test_캘리브레이션차단이면_설정열기_안내() {
        // given
        let sut = GazeActivationBlockGuidance(reason: .calibrationUnavailable)

        // then
        XCTAssertEqual(sut.actionButtonTitle, "Open Settings")
        XCTAssertEqual(sut.cancelButtonTitle, "Cancel")
        XCTAssertTrue(sut.message.contains("Calibrate"))
        XCTAssertFalse(sut.title.isEmpty)
    }

    func test_한국어_캘리브레이션차단이면_한국어안내() {
        // given
        let sut = GazeActivationBlockGuidance(
            reason: .calibrationUnavailable,
            language: .korean
        )

        // then
        XCTAssertEqual(sut.title, "캘리브레이션이 필요합니다")
        XCTAssertEqual(sut.actionButtonTitle, "설정 열기")
        XCTAssertEqual(sut.cancelButtonTitle, "취소")
        XCTAssertTrue(sut.message.contains("캘리브레이션"))
    }

    func test_캘리브레이션안내는_구체적_단계와_버튼을_설명한다() {
        // given
        let korean = GazeActivationBlockGuidance(
            reason: .calibrationUnavailable,
            language: .korean
        )
        let english = GazeActivationBlockGuidance(
            reason: .calibrationUnavailable,
            language: .english
        )

        // then: Settings 위치 · 실제 버튼 라벨 · 활성화 단축키를 단계별로 안내한다.
        XCTAssertTrue(korean.message.contains("Gaze 캘리브레이션"))
        XCTAssertTrue(korean.message.contains("캘리브레이션…"))
        XCTAssertTrue(korean.message.contains("Control+Shift+Space"))
        XCTAssertTrue(korean.message.contains("1."))

        XCTAssertTrue(english.message.contains("Gaze calibration"))
        XCTAssertTrue(english.message.contains("Calibrate…"))
        XCTAssertTrue(english.message.contains("Control+Shift+Space"))
        XCTAssertTrue(english.message.contains("1."))
    }

    func test_사유마다_설명이_구분된다() {
        // given
        let optIn = GazeActivationBlockGuidance(reason: .optInDisabled)
        let permission = GazeActivationBlockGuidance(reason: .cameraPermissionDenied)
        let calibration = GazeActivationBlockGuidance(reason: .calibrationUnavailable)

        // then
        XCTAssertNotEqual(optIn, permission)
        XCTAssertNotEqual(permission, calibration)
        XCTAssertNotEqual(optIn, calibration)
    }
}
