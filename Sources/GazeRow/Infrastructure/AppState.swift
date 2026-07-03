import Foundation

/// 앱 전역 메타데이터와 MVP 모드 상태.
///
/// TICKET-001 범위에서는 정적 표시 정보만 담는다.
/// 권한 상태, gaze 상태 등 동적 값은 후속 티켓에서 추가한다.
///
/// @author suho.do
/// @since 2026-07-02
enum AppState {

    /// 앱 표시 이름.
    static let appName = "GazeRow"

    /// Bundle identifier. 외부 배포 전 변경 가능.
    static let bundleIdentifier = "dev.local.gazerow"

    /// 빌드 버전 placeholder. Xcode 이관 후 Info.plist 값으로 대체 예정.
    static let versionPlaceholder = "0.1.0 (dev)"

    /// MVP 모드. Baseline은 키보드 기반이며 camera gaze는 명시 opt-in이다.
    static let mvpMode = "Baseline + experimental opt-in"

    /// gaze 기능 상태. 기본값은 비활성이며 Settings에서 명시적으로 켜야 한다.
    static let gazeStatus = "Off by default / experimental opt-in"

    /// Settings에 노출하는 개인정보/데이터 접근 안내 문구.
    static let privacyNotice = """
    GazeRow is a local macOS keyboard-click utility.
    Camera gaze focus is experimental and only runs after explicit opt-in.
    GazeRow does not use screen recording or external telemetry.
    """

    /// Camera gaze focus 권한/데이터 처리 안내 문구.
    static let cameraRationale = """
    Camera gaze focus uses local webcam frames to estimate eye landmarks for focus movement only.
    Frames and raw face/eye data are not stored, and clicks still require keyboard confirmation.
    """

    /// Accessibility 권한 안내 문구.
    ///
    /// PR-006에 따라 데이터 접근 범위를 기능 가치보다 먼저 설명한다.
    static let accessibilityRationale = """
    GazeRow reads the accessibility tree of the frontmost app to find \
    clickable elements and to click them on your behalf. Without Accessibility \
    permission, overlay activation is unavailable.
    """

    /// 앱 상태/권한 설명의 언어별 문구.
    ///
    /// @author suho.do
    /// @since 2026-07-03
    struct LocalizedText: Equatable {
        let mvpMode: String
        let gazeStatus: String
        let privacyNotice: String
        let cameraRationale: String
        let accessibilityRationale: String
    }

    static func localized(for language: AppLanguage) -> LocalizedText {
        switch language {
        case .english:
            LocalizedText(
                mvpMode: mvpMode,
                gazeStatus: gazeStatus,
                privacyNotice: privacyNotice,
                cameraRationale: cameraRationale,
                accessibilityRationale: accessibilityRationale
            )
        case .korean:
            LocalizedText(
                mvpMode: "기본 모드 + 실험 기능 선택 사용",
                gazeStatus: "기본 꺼짐 / 실험 기능 선택 사용",
                privacyNotice: """
                GazeRow는 로컬 macOS 키보드 클릭 유틸리티입니다.
                카메라 gaze focus는 실험 기능이며 명시적으로 켠 뒤에만 동작합니다.
                GazeRow는 화면 녹화나 외부 텔레메트리를 사용하지 않습니다.
                """,
                cameraRationale: """
                Camera gaze focus는 로컬 웹캠 프레임으로 눈 landmark를 추정해 focus 이동에만 사용합니다.
                프레임과 원본 얼굴/눈 데이터는 저장하지 않으며, 클릭은 계속 키보드 확인이 필요합니다.
                """,
                accessibilityRationale: """
                GazeRow는 맨 앞 앱의 접근성 트리를 읽어 클릭 가능한 요소를 찾고, 사용자의 명시 입력 후 해당 요소를 클릭합니다.
                Accessibility 권한이 없으면 overlay 활성화를 사용할 수 없습니다.
                """
            )
        }
    }
}
