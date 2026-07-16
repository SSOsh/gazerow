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
                "메뉴바의 Enable GazeRow를 켠 뒤 다시 Command+Shift+Space를 누르세요.",
                "확인"
            )
        case (.sessionDisabled, .english):
            (
                "GazeRow is disabled",
                "Enable GazeRow from the menu bar, then press Command+Shift+Space again.",
                "OK"
            )
        case (.targetResolutionFailed(.noFrontmostApplication), .korean),
             (.targetResolutionFailed(.invalidProcessIdentifier), .korean),
             (.targetResolutionFailed(.focusedWindowUnavailable), .korean),
             (.targetResolutionFailed(.windowFrameUnavailable), .korean),
             (.targetResolutionFailed(.invalidWindowFrame), .korean):
            (
                "오버레이를 띄울 창을 찾지 못했습니다",
                "클릭하려는 앱 창을 한 번 클릭한 뒤 다시 Command+Shift+Space를 누르세요. 메뉴바, Control Center, 알림 센터 위에서는 대상 창을 찾지 못할 수 있습니다.",
                "확인"
            )
        case (.targetResolutionFailed(.noFrontmostApplication), .english),
             (.targetResolutionFailed(.invalidProcessIdentifier), .english),
             (.targetResolutionFailed(.focusedWindowUnavailable), .english),
             (.targetResolutionFailed(.windowFrameUnavailable), .english),
             (.targetResolutionFailed(.invalidWindowFrame), .english):
            (
                "No target window found",
                "Click the app window you want to control, then press Command+Shift+Space again. Menu bar, Control Center, and Notification Center surfaces may not expose a target window.",
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
                "대상 앱 창이 응답 중인지 확인한 뒤 다시 Command+Shift+Space를 누르세요.",
                "확인"
            )
        case (.scanFailed, .english):
            (
                "Could not read clickable elements",
                "Make sure the target app window is responsive, then press Command+Shift+Space again.",
                "OK"
            )
        case (.noCandidates, .korean):
            (
                "선택 가능한 요소가 없습니다",
                noCandidatesMessage(for: failure, language: language),
                "확인"
            )
        case (.noCandidates, .english):
            (
                "No clickable elements found",
                noCandidatesMessage(for: failure, language: language),
                "OK"
            )
        }
    }

    private static func noCandidatesMessage(
        for failure: OverlaySessionStartFailure,
        language: AppLanguage
    ) -> String {
        guard case .noCandidates(let context, let scanResult) = failure else {
            return ""
        }

        let appName = context.application.localizedName
        let reason = noCandidatesReason(context: context, scanResult: scanResult, language: language)

        if language == .korean {
            return "\(appName) 창에서 클릭 가능한 UI 요소를 찾지 못했습니다. \(reason)"
        }

        return "GazeRow could not find clickable UI elements in \(appName). \(reason)"
    }

    private static func noCandidatesReason(
        context: TargetContext,
        scanResult: AccessibilityScanResult,
        language: AppLanguage
    ) -> String {
        if scanResult.didTimeout {
            return language == .korean
                ? "스캔 시간이 초과됐습니다. 창이 안정된 뒤 다시 overlay를 여세요."
                : "The scan timed out. Let the window settle, then reopen the overlay."
        }

        if scanResult.didHitNodeLimit {
            return language == .korean
                ? "UI 요소가 너무 많아 일부만 읽었습니다. 더 좁은 영역이나 다른 창에서 다시 시도하세요."
                : "The window exposed too many UI elements. Try a smaller area or another window."
        }

        if scanResult.didHitDepthLimit {
            return language == .korean
                ? "깊은 UI 계층 일부를 읽지 못했습니다. 다른 영역을 선택한 뒤 다시 시도하세요."
                : "Some deep UI groups were skipped. Try another area, then reopen the overlay."
        }

        if scanResult.failedChildReadCount > 0 {
            return language == .korean
                ? "일부 UI 그룹을 읽지 못했습니다. 대상 창을 한 번 클릭한 뒤 다시 시도하세요."
                : "Some UI groups could not be read. Click the target window, then try again."
        }

        if scanResult.nodesVisited <= 1 {
            return language == .korean
                ? "현재 창이 접근성 요소를 거의 노출하지 않습니다. 다른 창이나 앱에서 다시 시도하세요."
                : "The window exposed almost no accessibility elements. Try another window or app."
        }

        if let baseline = AppCandidateQualityBaseline.baseline(
            for: context.application.bundleIdentifier
        ),
           baseline.isBelowBaseline(candidateCount: scanResult.candidateCount) {
            return language == .korean
                ? "\(baseline.displayName)는 평가된 지원 앱입니다. 대상 창을 한 번 클릭해 focus를 되돌린 뒤 다시 overlay를 여세요. 계속 0개면 후보 수 회귀로 기록하세요."
                : "\(baseline.displayName) is a supported baseline app. Click the target window to restore focus, then reopen the overlay. If it stays at 0, record it as a candidate-count regression."
        }

        return language == .korean
            ? "현재 화면에는 지원되는 click action이 없을 수 있습니다. 다른 영역이나 다른 창을 선택하세요."
            : "This screen may not expose supported click actions. Try another area or another window."
    }
}
