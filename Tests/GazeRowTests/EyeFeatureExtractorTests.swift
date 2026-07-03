import CoreGraphics
import XCTest
@testable import GazeRow

/// EyeFeatureExtractor 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class EyeFeatureExtractorTests: XCTestCase {

    func test_extract_눈중심과_동공간거리를_계산() throws {
        // given
        let detection = FaceLandmarkDetection(
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.5),
            confidence: 0.9,
            leftEye: [CGPoint(x: 0.2, y: 0.4), CGPoint(x: 0.4, y: 0.4)],
            rightEye: [CGPoint(x: 0.6, y: 0.4), CGPoint(x: 0.8, y: 0.4)],
            faceContour: [],
            nose: [CGPoint(x: 0.5, y: 0.2)]
        )
        let sut = EyeFeatureExtractor()

        // when
        let feature = try XCTUnwrap(sut.extract(from: detection))

        // then
        XCTAssertEqual(feature.leftEyeCenter.x, 0.3, accuracy: 0.0001)
        XCTAssertEqual(feature.rightEyeCenter.x, 0.7, accuracy: 0.0001)
        XCTAssertEqual(feature.eyeMidpoint.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(feature.interocularDistance, 0.4, accuracy: 0.0001)
        XCTAssertEqual(feature.noseCenter?.x, 0.5)
        XCTAssertEqual(feature.faceCenter.x, 0.4, accuracy: 0.0001)
    }

    func test_extract_눈좌표가_없으면_nil() {
        // given
        let detection = FaceLandmarkDetection(
            boundingBox: .zero,
            confidence: 0.9,
            leftEye: [],
            rightEye: [CGPoint(x: 0.6, y: 0.4)],
            faceContour: [],
            nose: []
        )
        let sut = EyeFeatureExtractor()

        // when
        let feature = sut.extract(from: detection)

        // then
        XCTAssertNil(feature)
    }
}
