import XCTest
@testable import GazeRow

/// `GazeActivationGate` 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeActivationGateTests: XCTestCase {

    func test_모든_조건_충족이면_proceed() {
        // given
        let sut = makeSUT(optIn: true, authorized: true, ready: true)

        // when
        let result = sut.evaluate()

        // then
        XCTAssertEqual(result, .proceed)
    }

    func test_optIn_off이면_optInDisabled() {
        // given
        let sut = makeSUT(optIn: false, authorized: true, ready: true)

        // when
        let result = sut.evaluate()

        // then
        XCTAssertEqual(result, .blocked(.optInDisabled))
    }

    func test_권한없으면_cameraPermissionDenied() {
        // given
        let sut = makeSUT(optIn: true, authorized: false, ready: true)

        // when
        let result = sut.evaluate()

        // then
        XCTAssertEqual(result, .blocked(.cameraPermissionDenied))
    }

    func test_캘리브레이션_미완료면_calibrationUnavailable() {
        // given
        let sut = makeSUT(optIn: true, authorized: true, ready: false)

        // when
        let result = sut.evaluate()

        // then
        XCTAssertEqual(result, .blocked(.calibrationUnavailable))
    }

    func test_우선순위는_optIn_권한_캘리브레이션_순서() {
        // given: 모두 실패 상태여도 optIn을 먼저 보고
        let sut = makeSUT(optIn: false, authorized: false, ready: false)

        // when
        let result = sut.evaluate()

        // then
        XCTAssertEqual(result, .blocked(.optInDisabled))
    }

    private func makeSUT(
        optIn: Bool,
        authorized: Bool,
        ready: Bool
    ) -> GazeActivationGate {
        GazeActivationGate(
            isOptInEnabled: { optIn },
            isCameraAuthorized: { authorized },
            isCalibrationReady: { ready }
        )
    }
}
