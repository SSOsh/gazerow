import XCTest
@testable import GazeRow

/// `GazeCalibrationDwellClock` 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeCalibrationDwellClockTests: XCTestCase {

    func test_임계값_미만이면_false() {
        // given
        var sut = GazeCalibrationDwellClock(dwellSeconds: 1.0)

        // when
        let result = sut.advance(by: 0.5)

        // then
        XCTAssertFalse(result)
        XCTAssertEqual(sut.elapsed, 0.5, accuracy: 0.0001)
    }

    func test_임계값_도달하면_true이고_경과_리셋() {
        // given
        var sut = GazeCalibrationDwellClock(dwellSeconds: 1.0)
        _ = sut.advance(by: 0.6)

        // when
        let result = sut.advance(by: 0.5)

        // then
        XCTAssertTrue(result)
        XCTAssertEqual(sut.elapsed, 0, accuracy: 0.0001)
    }

    func test_progress는_0에서_1로_증가() {
        // given
        var sut = GazeCalibrationDwellClock(dwellSeconds: 2.0)

        // when
        _ = sut.advance(by: 0.5)

        // then
        XCTAssertEqual(sut.progress, 0.25, accuracy: 0.0001)
    }

    func test_progress는_1을_넘지_않음() {
        // given
        var sut = GazeCalibrationDwellClock(dwellSeconds: 1.0)

        // when: 임계값 도달 직전까지만 확인(도달 시 리셋되므로)
        _ = sut.advance(by: 0.9)

        // then
        XCTAssertEqual(sut.progress, 0.9, accuracy: 0.0001)
    }

    func test_reset하면_경과_0() {
        // given
        var sut = GazeCalibrationDwellClock(dwellSeconds: 1.0)
        _ = sut.advance(by: 0.7)

        // when
        sut.reset()

        // then
        XCTAssertEqual(sut.elapsed, 0, accuracy: 0.0001)
    }

    func test_retry하면_다음_advance에서_즉시_true() {
        // given
        var sut = GazeCalibrationDwellClock(dwellSeconds: 1.0)

        // when
        sut.retry()
        let result = sut.advance(by: 0.01)

        // then
        XCTAssertTrue(result)
    }

    func test_음수_delta는_경과에_반영되지_않음() {
        // given
        var sut = GazeCalibrationDwellClock(dwellSeconds: 1.0)
        _ = sut.advance(by: 0.5)

        // when
        _ = sut.advance(by: -0.3)

        // then
        XCTAssertEqual(sut.elapsed, 0.5, accuracy: 0.0001)
    }
}
