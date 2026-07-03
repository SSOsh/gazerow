import CoreGraphics
import XCTest
@testable import GazeRow

/// `GazeCalibrationSession` 수집 로직 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeCalibrationSessionTests: XCTestCase {

    private let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)

    private func makeFeature(_ seed: CGFloat) -> EyeFeature {
        EyeFeature(
            leftEyeCenter: CGPoint(x: seed, y: seed),
            rightEyeCenter: CGPoint(x: seed + 0.1, y: seed),
            eyeMidpoint: CGPoint(x: seed + 0.05, y: seed),
            interocularDistance: 0.1,
            noseCenter: nil,
            faceCenter: CGPoint(x: seed, y: seed)
        )
    }

    func test_초기상태는_미완료이고_인덱스0() {
        // given
        let sut = GazeCalibrationSession(screenBounds: bounds, normalizedTargets: [CGPoint(x: 0.5, y: 0.5)])

        // then
        XCTAssertFalse(sut.isComplete)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.totalTargetCount, 1)
        XCTAssertTrue(sut.samples.isEmpty)
    }

    func test_currentScreenPoint는_정규화좌표를_bounds로_매핑() {
        // given
        let sut = GazeCalibrationSession(
            screenBounds: CGRect(x: 100, y: 200, width: 1_000, height: 800),
            normalizedTargets: [CGPoint(x: 0.5, y: 0.25)]
        )

        // then
        XCTAssertEqual(sut.currentScreenPoint, CGPoint(x: 100 + 500, y: 200 + 200))
    }

    func test_record하면_현재타깃_화면좌표로_샘플_추가하고_전진() {
        // given
        var sut = GazeCalibrationSession(
            screenBounds: bounds,
            normalizedTargets: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 1.0, y: 1.0)]
        )
        let feature = makeFeature(0.3)

        // when
        sut.record(feature: feature)

        // then
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(sut.samples.count, 1)
        XCTAssertEqual(sut.samples.first?.feature, feature)
        XCTAssertEqual(sut.samples.first?.screenPoint, CGPoint(x: 0, y: 0))
        XCTAssertFalse(sut.isComplete)
    }

    func test_모든타깃_record하면_완료되고_currentTarget은_nil() {
        // given
        var sut = GazeCalibrationSession(
            screenBounds: bounds,
            normalizedTargets: [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 1.0, y: 1.0)]
        )

        // when
        sut.record(feature: makeFeature(0.1))
        sut.record(feature: makeFeature(0.2))

        // then
        XCTAssertTrue(sut.isComplete)
        XCTAssertNil(sut.currentNormalizedTarget)
        XCTAssertNil(sut.currentScreenPoint)
        XCTAssertEqual(sut.samples.count, 2)
        XCTAssertEqual(sut.samples.last?.screenPoint, CGPoint(x: 1_000, y: 800))
    }

    func test_완료후_record는_무시된다() {
        // given
        var sut = GazeCalibrationSession(
            screenBounds: bounds,
            normalizedTargets: [CGPoint(x: 0.5, y: 0.5)]
        )
        sut.record(feature: makeFeature(0.1))

        // when
        sut.record(feature: makeFeature(0.9))

        // then
        XCTAssertEqual(sut.samples.count, 1)
        XCTAssertEqual(sut.currentIndex, 1)
    }

    func test_기본타깃은_9점_3x3() {
        // given
        let sut = GazeCalibrationSession(screenBounds: bounds)

        // then
        XCTAssertEqual(sut.totalTargetCount, 9)
    }
}
