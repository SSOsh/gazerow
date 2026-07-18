import Foundation

/// 특정 브라우저에 대한 Automation(Apple Events) 권한 상태.
///
/// @author suho.do
/// @since 2026-07-18
enum BrowserAutomationPermissionStatus: Equatable {
    /// Apple Event를 보낼 수 있다.
    case authorized
    /// 아직 사용자가 권한 팝업에 응답하지 않았다(최초 실행 등).
    case notDetermined
    /// 사용자가 권한을 거부했다.
    case denied
    /// 대상 브라우저가 실행 중이 아니거나 그 외 원인으로 판단할 수 없다.
    case unavailable
}

/// AppleScript probe 실행 1회의 원시 결과.
///
/// @author suho.do
/// @since 2026-07-18
enum BrowserAutomationProbeOutcome: Equatable {
    case success
    case notPermitted
    case notDetermined
    case other
}

/// 브라우저 창의 열린 탭 개수를 조회하기 전에, Automation 권한이 거부됐는지 미리 확인한다.
///
/// 별도의 Carbon `AEDeterminePermissionToAutomateTarget` API 대신, 실제로 사용하는 것과
/// 동일한 부작용 없는 최소 스크립트를 실행해 `NSAppleScript`의 오류 코드
/// (`NSAppleScriptErrorNumber`)로 상태를 판별한다. `-1743`은 거부(errAEEventNotPermitted),
/// `-1744`는 아직 미결정(errAEEventWouldRequireUserConsent)에 해당한다.
///
/// @author suho.do
/// @since 2026-07-18
struct BrowserAutomationPermissionChecker {

    func status(
        for profile: BrowserTabCountFetcher.BrowserProfile,
        probeRunner: (String) -> BrowserAutomationProbeOutcome = Self.runProbeScript
    ) -> BrowserAutomationPermissionStatus {
        switch probeRunner(Self.probeScript(for: profile)) {
        case .success:
            .authorized
        case .notPermitted:
            .denied
        case .notDetermined:
            .notDetermined
        case .other:
            .unavailable
        }
    }

    private static func probeScript(for profile: BrowserTabCountFetcher.BrowserProfile) -> String {
        "tell application id \"\(profile.scriptingID)\" to return true"
    }

    private static func runProbeScript(_ source: String) -> BrowserAutomationProbeOutcome {
        guard let script = NSAppleScript(source: source) else {
            return .other
        }

        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        guard let error else {
            return .success
        }

        switch error["NSAppleScriptErrorNumber"] as? Int {
        case -1743:
            return .notPermitted
        case -1744:
            return .notDetermined
        default:
            return .other
        }
    }
}
