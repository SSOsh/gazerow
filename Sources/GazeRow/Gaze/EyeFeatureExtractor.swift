import CoreGraphics
import Foundation

/// gaze estimation에 쓰는 비식별 eye feature.
///
/// raw camera frame이나 원본 얼굴 이미지를 저장하지 않고, normalized landmark에서
/// 계산한 중심점과 거리만 보관한다.
///
/// @author suho.do
/// @since 2026-07-03
struct EyeFeature: Equatable, Codable {
    let leftEyeCenter: CGPoint
    let rightEyeCenter: CGPoint
    let eyeMidpoint: CGPoint
    let interocularDistance: CGFloat
    let noseCenter: CGPoint?
    let faceCenter: CGPoint
}

/// Vision landmark에서 gaze calibration용 eye feature를 계산한다.
///
/// @author suho.do
/// @since 2026-07-03
struct EyeFeatureExtractor {

    func extract(from detection: FaceLandmarkDetection) -> EyeFeature? {
        guard let leftEyeCenter = center(of: detection.leftEye),
              let rightEyeCenter = center(of: detection.rightEye) else {
            return nil
        }

        let distance = hypot(
            leftEyeCenter.x - rightEyeCenter.x,
            leftEyeCenter.y - rightEyeCenter.y
        )

        guard distance > 0 else {
            return nil
        }

        return EyeFeature(
            leftEyeCenter: leftEyeCenter,
            rightEyeCenter: rightEyeCenter,
            eyeMidpoint: CGPoint(
                x: (leftEyeCenter.x + rightEyeCenter.x) / 2,
                y: (leftEyeCenter.y + rightEyeCenter.y) / 2
            ),
            interocularDistance: distance,
            noseCenter: center(of: detection.nose),
            faceCenter: CGPoint(
                x: detection.boundingBox.midX,
                y: detection.boundingBox.midY
            )
        )
    }

    private func center(of points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else {
            return nil
        }

        let sum = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }

        return CGPoint(
            x: sum.x / CGFloat(points.count),
            y: sum.y / CGFloat(points.count)
        )
    }
}
