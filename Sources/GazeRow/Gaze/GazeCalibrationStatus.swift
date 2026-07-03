/// Settings에 표시할 gaze 캘리브레이션 상태를 계산하는 순수 값 타입.
///
/// opt-in·카메라 권한·저장된 샘플 수를 바탕으로 캘리브레이션 시작 버튼의 활성화
/// 여부와 사용자 표시 문구를 결정한다. UI 의존이 없어 단위 테스트가 쉽다.
///
/// @author suho.do
/// @since 2026-07-03
struct GazeCalibrationStatus: Equatable {

    let isOptInEnabled: Bool
    let isCameraAuthorized: Bool
    let sampleCount: Int
    let requiredSampleCount: Int

    init(
        isOptInEnabled: Bool,
        isCameraAuthorized: Bool,
        sampleCount: Int,
        requiredSampleCount: Int = 5
    ) {
        self.isOptInEnabled = isOptInEnabled
        self.isCameraAuthorized = isCameraAuthorized
        self.sampleCount = sampleCount
        self.requiredSampleCount = requiredSampleCount
    }

    /// 캘리브레이션을 시작할 수 있는 선행 조건(opt-in + 카메라 권한)이 충족됐는지.
    var canStartCalibration: Bool {
        isOptInEnabled && isCameraAuthorized
    }

    /// 저장된 샘플이 추정에 충분한지(캘리브레이션 완료 여부).
    var isCalibrated: Bool {
        sampleCount >= requiredSampleCount
    }

    /// 사용자에게 표시할 상태 문구.
    var displayText: String {
        if !isOptInEnabled {
            return "Enable gaze focus first"
        }
        if !isCameraAuthorized {
            return "Camera permission required"
        }
        if isCalibrated {
            return "Calibrated (\(sampleCount) points)"
        }
        return "Not calibrated"
    }
}
