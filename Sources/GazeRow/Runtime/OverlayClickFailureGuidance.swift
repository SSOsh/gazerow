import Foundation

/// overlay click 실패를 사용자가 바로 복구할 수 있는 짧은 상태 문구로 변환한다.
///
/// @author suho.do
/// @since 2026-07-12
struct OverlayClickFailureGuidance: Equatable {
    let message: String

    init(failure: OverlaySessionClickFailure, language: AppLanguage = .english) {
        message = Self.message(for: failure, language: language)
    }

    init(riskClass: ClickRiskClass) {
        message = "Press Return again to confirm \(riskClass.statusText)."
    }

    static func rescanFailureMessage(language: AppLanguage) -> String {
        language == .korean
            ? "화면을 다시 읽지 못했습니다. 잠시 후 다시 시도하세요."
            : "The screen could not be rescanned. Try again shortly."
    }

    private static func message(for failure: OverlaySessionClickFailure, language: AppLanguage) -> String {
        switch failure {
        case .scanFailed(.accessibilityPermissionDenied):
            return "Click failed: permission changed. Recheck Accessibility, then reopen overlay."
        case .scanFailed:
            return "Click failed: target changed. Reopen overlay to rescan current UI."
        case .missingFocusedTarget:
            return "Click failed: no focused target. Type a label or press Tab first."
        case .selectedTargetUnavailable:
            return language == .korean
                ? "선택한 요소가 더 이상 없습니다. 라벨을 갱신했습니다."
                : "The selected element is no longer available. Labels were refreshed."
        case .selectedTargetChanged:
            return language == .korean
                ? "화면이 변경되어 라벨을 갱신했습니다. 다시 선택하세요."
                : "The screen changed, so labels were refreshed. Select again."
        case .selectedTargetAmbiguous:
            return language == .korean
                ? "대상을 확실히 구분할 수 없어 클릭하지 않았습니다."
                : "The target could not be identified safely, so no click was performed."
        case .executionFailed(let failure):
            return message(for: failure)
        }
    }

    private static func message(for failure: ClickExecutionFailure) -> String {
        switch failure {
        case .missingPressAction:
            return "Click failed: no supported action. Try another label."
        case .secondConfirmRequired(let riskClass):
            return "Press Return again to confirm \(riskClass.statusText)."
        case .axPressFailed:
            return "Click failed: accessibility action failed. Reopen overlay and try again."
        case .coordinateFallbackDisabled:
            return "Click failed: coordinate fallback is off. Try another label."
        case .coordinateFallbackFailed:
            return "Click failed: coordinate fallback failed. Check the target window."
        }
    }
}
