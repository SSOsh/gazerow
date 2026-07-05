import Foundation

/// overlay activation 실패를 사용자가 이해할 수 있는 안내 문구로 변환한다.
///
/// @author suho.do
/// @since 2026-07-05
struct OverlayStartFailureGuidance: Equatable {
    let title: String
    let message: String
    let actionButtonTitle: String

    init(
        failure: OverlaySessionStartFailure,
        language: AppLanguage = AppLanguageSettings().selectedLanguage
    ) {
        let content = Self.content(for: failure, language: language)
        title = content.title
        message = content.message
        actionButtonTitle = content.actionButtonTitle
    }

    private static func content(
        for failure: OverlaySessionStartFailure,
        language: AppLanguage
    ) -> (title: String, message: String, actionButtonTitle: String) {
        switch (failure, language) {
        case (.sessionDisabled, .korean):
            (
                "GazeRow가 비활성화되어 있습니다",
                "메뉴바의 Enable GazeRow를 켠 뒤 다시 Control+Option+Space를 누르세요.",
                "확인"
            )
        case (.sessionDisabled, .english):
            (
                "GazeRow is disabled",
                "Enable GazeRow from the menu bar, then press Control+Option+Space again.",
                "OK"
            )
        case (.targetResolutionFailed(.noFrontmostApplication), .korean),
             (.targetResolutionFailed(.invalidProcessIdentifier), .korean),
             (.targetResolutionFailed(.focusedWindowUnavailable), .korean),
             (.targetResolutionFailed(.windowFrameUnavailable), .korean),
             (.targetResolutionFailed(.invalidWindowFrame), .korean):
            (
                "오버레이를 띄울 창을 찾지 못했습니다",
                "클릭하려는 앱 창을 한 번 클릭한 뒤 다시 Control+Option+Space를 누르세요. 메뉴바, Control Center, 알림 센터 위에서는 대상 창을 찾지 못할 수 있습니다.",
                "확인"
            )
        case (.targetResolutionFailed(.noFrontmostApplication), .english),
             (.targetResolutionFailed(.invalidProcessIdentifier), .english),
             (.targetResolutionFailed(.focusedWindowUnavailable), .english),
             (.targetResolutionFailed(.windowFrameUnavailable), .english),
             (.targetResolutionFailed(.invalidWindowFrame), .english):
            (
                "No target window found",
                "Click the app window you want to control, then press Control+Option+Space again. Menu bar, Control Center, and Notification Center surfaces may not expose a target window.",
                "OK"
            )
        case (.targetResolutionFailed(.accessibilityPermissionDenied), .korean),
             (.scanFailed(.accessibilityPermissionDenied), .korean):
            (
                "손쉬운 사용 권한이 필요합니다",
                "시스템 설정에서 GazeRow의 손쉬운 사용 권한을 허용한 뒤 다시 시도하세요.",
                "확인"
            )
        case (.targetResolutionFailed(.accessibilityPermissionDenied), .english),
             (.scanFailed(.accessibilityPermissionDenied), .english):
            (
                "Accessibility permission required",
                "Grant Accessibility permission to GazeRow in System Settings, then try again.",
                "OK"
            )
        case (.scanFailed, .korean):
            (
                "클릭 가능한 요소를 읽지 못했습니다",
                "대상 앱 창이 응답 중인지 확인한 뒤 다시 Control+Option+Space를 누르세요.",
                "확인"
            )
        case (.scanFailed, .english):
            (
                "Could not read clickable elements",
                "Make sure the target app window is responsive, then press Control+Option+Space again.",
                "OK"
            )
        case (.noCandidates, .korean):
            (
                "선택 가능한 요소가 없습니다",
                "현재 창에서 GazeRow가 클릭 가능한 UI 요소를 찾지 못했습니다. 다른 영역이나 다른 창을 선택한 뒤 다시 시도하세요.",
                "확인"
            )
        case (.noCandidates, .english):
            (
                "No clickable elements found",
                "GazeRow could not find clickable UI elements in the current window. Try another area or another window.",
                "OK"
            )
        }
    }
}
