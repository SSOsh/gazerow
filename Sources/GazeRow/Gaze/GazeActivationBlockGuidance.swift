/// gaze 실행이 차단됐을 때 사용자에게 보여줄 안내 문구.
///
/// 차단 사유별로 "무엇이 부족한지"와 "다음에 무엇을 눌러야 하는지"를 설명해,
/// 시스템 설정 창만 조용히 뜨는 혼란을 막는다. UI 의존이 없는 순수 타입이라
/// 단위 테스트가 쉽다. AppDelegate가 이 문구로 alert를 띄운다.
///
/// @author suho.do
/// @since 2026-07-03
struct GazeActivationBlockGuidance: Equatable {

    /// alert 제목.
    let title: String

    /// alert 본문 설명.
    let message: String

    /// 사용자가 다음 단계로 이동할 버튼 제목.
    let actionButtonTitle: String

    /// 취소 버튼 제목.
    let cancelButtonTitle: String

    init(
        reason: GazeActivationBlockReason,
        language: AppLanguage = AppLanguageSettings().selectedLanguage
    ) {
        switch (reason, language) {
        case (.optInDisabled, .english):
            title = "Gaze focus is off"
            message = """
            Gaze focus (Control+Shift+Space) needs to be turned on first. \
            In Settings, enable "Experimental gaze focus", grant camera access, \
            then calibrate your gaze.
            """
            actionButtonTitle = "Open Settings"
            cancelButtonTitle = "Cancel"

        case (.optInDisabled, .korean):
            title = "Gaze focus가 꺼져 있습니다"
            message = """
            Gaze focus(Control+Shift+Space)를 사용하려면 먼저 켜야 합니다. \
            Settings에서 "실험적 gaze focus 사용"을 켜고 카메라 권한을 허용한 뒤, \
            gaze 캘리브레이션을 진행하세요.
            """
            actionButtonTitle = "설정 열기"
            cancelButtonTitle = "취소"

        case (.cameraPermissionDenied, .english):
            title = "Camera access needed"
            message = """
            Gaze focus uses the camera to estimate where you are looking. \
            Grant camera access to GazeRow in System Settings, then come back \
            and calibrate your gaze.
            """
            actionButtonTitle = "Open Camera Settings"
            cancelButtonTitle = "Cancel"

        case (.cameraPermissionDenied, .korean):
            title = "카메라 권한이 필요합니다"
            message = """
            Gaze focus는 카메라를 사용해 사용자가 바라보는 위치를 추정합니다. \
            시스템 설정에서 GazeRow의 카메라 접근을 허용한 뒤 돌아와 \
            gaze 캘리브레이션을 진행하세요.
            """
            actionButtonTitle = "카메라 설정 열기"
            cancelButtonTitle = "취소"

        case (.calibrationUnavailable, .english):
            title = "Calibration required"
            message = """
            Gaze focus needs a one-time calibration to map your eyes to the screen. Follow these steps:

            1. Click "Open Settings" below.
            2. In Settings, find "Gaze calibration" and click "Calibrate…".
            3. Look at each dot as it appears; samples are saved automatically.

            When calibration finishes, run gaze focus with Control+Shift+Space.
            """
            actionButtonTitle = "Open Settings"
            cancelButtonTitle = "Cancel"

        case (.calibrationUnavailable, .korean):
            title = "캘리브레이션이 필요합니다"
            message = """
            Gaze focus를 쓰려면 눈과 화면을 맞추는 캘리브레이션을 한 번 해야 합니다. 다음 순서로 진행하세요.

            1. 아래 '설정 열기'를 누릅니다.
            2. Settings의 'Gaze 캘리브레이션' 항목에서 '캘리브레이션…' 버튼을 누릅니다.
            3. 화면에 나타나는 점을 순서대로 잠시 바라보면 자동으로 저장됩니다.

            캘리브레이션이 끝나면 Control+Shift+Space로 gaze focus를 실행할 수 있습니다.
            """
            actionButtonTitle = "설정 열기"
            cancelButtonTitle = "취소"
        }
    }
}
