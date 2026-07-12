import Foundation

/// overlay click 실패를 사용자가 바로 복구할 수 있는 짧은 상태 문구로 변환한다.
///
/// @author suho.do
/// @since 2026-07-12
struct OverlayClickFailureGuidance: Equatable {
    let message: String

    init(failure: OverlaySessionClickFailure) {
        message = Self.message(for: failure)
    }

    init(riskClass: ClickRiskClass) {
        message = "Press Return again to confirm \(riskClass.statusText)."
    }

    private static func message(for failure: OverlaySessionClickFailure) -> String {
        switch failure {
        case .scanFailed(.accessibilityPermissionDenied):
            return "Click failed: permission changed. Recheck Accessibility, then reopen overlay."
        case .scanFailed:
            return "Click failed: target changed. Reopen overlay to rescan current UI."
        case .missingFocusedTarget:
            return "Click failed: no focused target. Type a label or press Tab first."
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
