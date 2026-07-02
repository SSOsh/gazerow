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

    /// MVP 모드. Baseline만 지원하며 gaze는 Post-MVP.
    static let mvpMode = "Baseline only"

    /// gaze 기능 상태. MVP baseline에서는 비활성.
    static let gazeStatus = "Disabled / Post-MVP"

    /// Settings에 노출하는 개인정보/데이터 접근 안내 문구.
    static let privacyNotice = """
    GazeRow is a local macOS keyboard-click utility.
    Baseline MVP does not use camera, screen recording, or external telemetry.
    """

    /// Accessibility 권한 안내 문구.
    ///
    /// PR-006에 따라 데이터 접근 범위를 기능 가치보다 먼저 설명한다.
    static let accessibilityRationale = """
    GazeRow reads the accessibility tree of the frontmost app to find \
    clickable elements and to click them on your behalf. Without Accessibility \
    permission, overlay activation is unavailable.
    """
}
