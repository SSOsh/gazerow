import CoreGraphics

/// EyeFeature를 화면 좌표 gaze point로 변환한다.
///
/// @author suho.do
/// @since 2026-07-03
struct GazePointEstimator {
    private let calibrationModel: GazeCalibrationModel

    init(calibrationModel: GazeCalibrationModel) {
        self.calibrationModel = calibrationModel
    }

    var isReady: Bool {
        calibrationModel.isReady
    }

    func estimatePoint(for feature: EyeFeature) throws -> CGPoint {
        try calibrationModel.estimateScreenPoint(for: feature)
    }
}
