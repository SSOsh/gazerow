import XCTest
@testable import GazeRow

/// `GazeCalibrationStatus` 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeCalibrationStatusTests: XCTestCase {

    func test_optIn과_권한_있으면_시작가능() {
        // given
        let sut = GazeCalibrationStatus(
            isOptInEnabled: true,
            isCameraAuthorized: true,
            sampleCount: 0
        )

        // then
        XCTAssertTrue(sut.canStartCalibration)
    }

    func test_optIn_off이면_시작불가() {
        // given
        let sut = GazeCalibrationStatus(
            isOptInEnabled: false,
            isCameraAuthorized: true,
            sampleCount: 0
        )

        // then
        XCTAssertFalse(sut.canStartCalibration)
        XCTAssertEqual(sut.displayText, "Enable gaze focus first")
    }

    func test_권한없으면_시작불가_문구() {
        // given
        let sut = GazeCalibrationStatus(
            isOptInEnabled: true,
            isCameraAuthorized: false,
            sampleCount: 0
        )

        // then
        XCTAssertFalse(sut.canStartCalibration)
        XCTAssertEqual(sut.displayText, "Camera permission required")
    }

    func test_샘플_충분하면_calibrated() {
        // given
        let sut = GazeCalibrationStatus(
            isOptInEnabled: true,
            isCameraAuthorized: true,
            sampleCount: 9
        )

        // then
        XCTAssertTrue(sut.isCalibrated)
        XCTAssertEqual(sut.displayText, "Calibrated (9 points)")
    }

    func test_샘플_부족하면_not_calibrated() {
        // given
        let sut = GazeCalibrationStatus(
            isOptInEnabled: true,
            isCameraAuthorized: true,
            sampleCount: 3
        )

        // then
        XCTAssertFalse(sut.isCalibrated)
        XCTAssertEqual(sut.displayText, "Not calibrated")
    }

    func test_경계값_요구수와_동일하면_calibrated() {
        // given
        let sut = GazeCalibrationStatus(
            isOptInEnabled: true,
            isCameraAuthorized: true,
            sampleCount: 5,
            requiredSampleCount: 5
        )

        // then
        XCTAssertTrue(sut.isCalibrated)
    }
}
