import CoreGraphics
import CoreVideo
@preconcurrency import Vision

/// Vision face landmark detection 결과.
///
/// 좌표는 Vision normalized coordinate를 그대로 유지한다. raw frame이나 얼굴 이미지는
/// 저장하지 않는다.
///
/// @author suho.do
/// @since 2026-07-03
struct FaceLandmarkDetection: Equatable {
    let boundingBox: CGRect
    let confidence: Float
    let leftEye: [CGPoint]
    let rightEye: [CGPoint]
    let faceContour: [CGPoint]
    let nose: [CGPoint]
}

/// Apple Vision 기반 얼굴/눈 landmark detector.
///
/// @author suho.do
/// @since 2026-07-03
struct FaceLandmarkDetector {

    func detect(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) throws -> [FaceLandmarkDetection] {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation
        )

        try handler.perform([request])

        return (request.results ?? []).compactMap(Self.makeDetection)
    }

    private static func makeDetection(_ observation: VNFaceObservation) -> FaceLandmarkDetection? {
        guard let landmarks = observation.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            return nil
        }

        return FaceLandmarkDetection(
            boundingBox: observation.boundingBox,
            confidence: observation.confidence,
            leftEye: Array(leftEye.normalizedPoints),
            rightEye: Array(rightEye.normalizedPoints),
            faceContour: Array(landmarks.faceContour?.normalizedPoints ?? []),
            nose: Array(landmarks.nose?.normalizedPoints ?? [])
        )
    }
}

extension FaceLandmarkDetector: GazeFaceLandmarkDetecting {
    func detect(in pixelBuffer: CVPixelBuffer) throws -> [FaceLandmarkDetection] {
        try detect(in: pixelBuffer, orientation: .up)
    }
}
