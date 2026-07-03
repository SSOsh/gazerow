import CoreGraphics
import XCTest
@testable import GazeRow

/// GazeCalibrationModel 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeCalibrationModelTests: XCTestCase {

    func test_5개미만_sample이면_estimate실패() {
        // given
        let sut = GazeCalibrationModel(
            samples: [
                makeSample(x: 0.1, y: 0.1, screenX: 10, screenY: 10)
            ]
        )

        // when & then
        XCTAssertThrowsError(try sut.estimateScreenPoint(for: makeFeature(x: 0.1, y: 0.1))) { error in
            XCTAssertEqual(
                error as? GazeEstimationFailure,
                .insufficientCalibrationSamples(required: 5, actual: 1)
            )
        }
    }

    func test_동일한_feature는_해당_screenPoint를_반환() throws {
        // given
        let targetFeature = makeFeature(x: 0.5, y: 0.5)
        let sut = GazeCalibrationModel(
            samples: [
                makeSample(x: 0.1, y: 0.1, screenX: 0, screenY: 0),
                makeSample(x: 0.9, y: 0.1, screenX: 100, screenY: 0),
                makeSample(x: 0.1, y: 0.9, screenX: 0, screenY: 100),
                makeSample(x: 0.9, y: 0.9, screenX: 100, screenY: 100),
                GazeCalibrationSample(feature: targetFeature, screenPoint: CGPoint(x: 50, y: 50))
            ]
        )

        // when
        let point = try sut.estimateScreenPoint(for: targetFeature)

        // then
        XCTAssertEqual(point, CGPoint(x: 50, y: 50))
    }

    func test_addSample_5개가되면_ready() {
        // given
        var sut = GazeCalibrationModel()

        // when
        for index in 0..<5 {
            sut.addSample(makeSample(x: CGFloat(index) / 10, y: 0.5, screenX: CGFloat(index), screenY: 0))
        }

        // then
        XCTAssertTrue(sut.isReady)
    }

    private func makeSample(
        x: CGFloat,
        y: CGFloat,
        screenX: CGFloat,
        screenY: CGFloat
    ) -> GazeCalibrationSample {
        GazeCalibrationSample(
            feature: makeFeature(x: x, y: y),
            screenPoint: CGPoint(x: screenX, y: screenY)
        )
    }

    private func makeFeature(x: CGFloat, y: CGFloat) -> EyeFeature {
        EyeFeature(
            leftEyeCenter: CGPoint(x: x - 0.1, y: y),
            rightEyeCenter: CGPoint(x: x + 0.1, y: y),
            eyeMidpoint: CGPoint(x: x, y: y),
            interocularDistance: 0.2,
            noseCenter: nil,
            faceCenter: CGPoint(x: x, y: y)
        )
    }
}
