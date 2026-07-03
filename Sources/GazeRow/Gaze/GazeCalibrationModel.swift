import CoreGraphics
import Foundation

/// 한 calibration point에서 수집한 eye feature와 화면 좌표.
///
/// @author suho.do
/// @since 2026-07-03
struct GazeCalibrationSample: Equatable, Codable {
    let feature: EyeFeature
    let screenPoint: CGPoint
}

/// Calibration 부족 또는 계산 실패 사유.
///
/// @author suho.do
/// @since 2026-07-03
enum GazeEstimationFailure: Error, Equatable {
    case insufficientCalibrationSamples(required: Int, actual: Int)
    case invalidCalibration
}

/// 5점 이상 calibration sample을 바탕으로 gaze point를 추정한다.
///
/// 첫 구현은 inverse-distance weighting을 사용한다. calibration sample과 동일한
/// feature가 들어오면 해당 screen point를 그대로 반환하고, 그 외에는 가까운
/// sample일수록 큰 가중치를 준다.
///
/// @author suho.do
/// @since 2026-07-03
struct GazeCalibrationModel: Equatable {
    let requiredSampleCount: Int
    private(set) var samples: [GazeCalibrationSample]

    init(
        samples: [GazeCalibrationSample] = [],
        requiredSampleCount: Int = 5
    ) {
        self.samples = samples
        self.requiredSampleCount = max(5, requiredSampleCount)
    }

    var isReady: Bool {
        samples.count >= requiredSampleCount
    }

    mutating func addSample(_ sample: GazeCalibrationSample) {
        samples.append(sample)
    }

    func estimateScreenPoint(for feature: EyeFeature) throws -> CGPoint {
        guard isReady else {
            throw GazeEstimationFailure.insufficientCalibrationSamples(
                required: requiredSampleCount,
                actual: samples.count
            )
        }

        for sample in samples where featureDistance(sample.feature, feature) == 0 {
            return sample.screenPoint
        }

        let weighted = samples.map { sample in
            let distance = max(featureDistance(sample.feature, feature), 0.000_001)
            return (point: sample.screenPoint, weight: 1 / distance)
        }

        let totalWeight = weighted.reduce(CGFloat.zero) { $0 + $1.weight }
        guard totalWeight.isFinite, totalWeight > 0 else {
            throw GazeEstimationFailure.invalidCalibration
        }

        let sum = weighted.reduce(CGPoint.zero) { partial, item in
            CGPoint(
                x: partial.x + item.point.x * item.weight,
                y: partial.y + item.point.y * item.weight
            )
        }

        return CGPoint(x: sum.x / totalWeight, y: sum.y / totalWeight)
    }

    private func featureDistance(_ lhs: EyeFeature, _ rhs: EyeFeature) -> CGFloat {
        let dx = lhs.eyeMidpoint.x - rhs.eyeMidpoint.x
        let dy = lhs.eyeMidpoint.y - rhs.eyeMidpoint.y
        let dd = lhs.interocularDistance - rhs.interocularDistance
        return sqrt(dx * dx + dy * dy + dd * dd)
    }
}
