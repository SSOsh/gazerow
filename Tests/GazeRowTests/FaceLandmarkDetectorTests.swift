import CoreGraphics
import CoreVideo
import XCTest
@testable import GazeRow

/// FaceLandmarkDetector 단위 테스트.
///
/// 실제 webcam이나 얼굴 이미지를 저장하지 않고, 코드로 생성한 빈 pixel buffer fixture로
/// Vision 파이프라인이 throw 없이 동작하는지와 orientation 인자가 수용되는지 검증한다.
/// 얼굴이 없는 frame에서는 어떤 orientation에서도 빈 결과를 반환해야 한다.
///
/// @author suho.do
/// @since 2026-09-12
final class FaceLandmarkDetectorTests: XCTestCase {

    func test_얼굴없는_프레임은_orientation별로_빈결과를_반환하고_throw하지_않는다() throws {
        // given
        let sut = FaceLandmarkDetector()
        let buffer = makePixelBuffer(width: 64, height: 64)
        let orientations: [CGImagePropertyOrientation] = [.up, .down, .left, .right]

        // when & then
        for orientation in orientations {
            let result = try sut.detect(in: buffer, orientation: orientation)
            XCTAssertTrue(result.isEmpty, "orientation \(orientation) 에서 얼굴없는 frame이 비어있지 않았다")
        }
    }

    func test_GazeFaceLandmarkDetecting_기본_detect도_빈_프레임에서_빈결과() throws {
        // given
        let sut: any GazeFaceLandmarkDetecting = FaceLandmarkDetector()
        let buffer = makePixelBuffer(width: 64, height: 64)

        // when
        let result = try sut.detect(in: buffer)

        // then
        XCTAssertTrue(result.isEmpty)
    }

    private func makePixelBuffer(width: Int, height: Int) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            fatalError("테스트용 pixel buffer 생성 실패 (status=\(status))")
        }
        return pixelBuffer
    }
}
