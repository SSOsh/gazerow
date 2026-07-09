import Foundation

/// 앱 실행 시 전달되는 로컬 평가/복구용 옵션.
///
/// @author suho.do
/// @since 2026-07-02
struct AppLaunchOptions: Equatable {
    let requestsAccessibilityPermission: Bool
    let showsOverlayOnLaunch: Bool
    let targetBundleIdentifier: String?
    let printsOverlayLabelMap: Bool
    let clickOverlayLabel: String?
    let printsHotKeyRegistration: Bool
    let queryText: String?
    let queryScopePin: QueryScope?
    let performQueryConfirm: Bool

    var isHotKeyRegistrationProbeOnly: Bool {
        printsHotKeyRegistration
            && !requestsAccessibilityPermission
            && !showsOverlayOnLaunch
            && targetBundleIdentifier == nil
            && !printsOverlayLabelMap
            && clickOverlayLabel == nil
            && queryText == nil
            && queryScopePin == nil
            && !performQueryConfirm
    }

    static var current: AppLaunchOptions {
        AppLaunchOptions(arguments: CommandLine.arguments)
    }

    init(arguments: [String]) {
        requestsAccessibilityPermission = arguments.contains("--request-accessibility")
        showsOverlayOnLaunch = arguments.contains("--show-overlay-on-launch")
        targetBundleIdentifier = Self.value(after: "--target-bundle-id", in: arguments)
        printsOverlayLabelMap = arguments.contains("--print-overlay-label-map")
        clickOverlayLabel = Self.value(after: "--click-overlay-label", in: arguments)
        printsHotKeyRegistration = arguments.contains("--print-hotkey-registration")
        queryText = Self.value(after: "--query-text", in: arguments)
        queryScopePin = Self.queryScope(after: "--query-scope-pin", in: arguments)
        performQueryConfirm = arguments.contains("--perform-query-confirm")
    }

    private static func value(after option: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: option) else {
            return nil
        }

        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            return nil
        }

        let value = arguments[valueIndex]
        return value.hasPrefix("--") ? nil : value
    }

    private static func queryScope(after option: String, in arguments: [String]) -> QueryScope? {
        guard let value = value(after: option, in: arguments) else {
            return nil
        }

        return QueryScope(rawValue: value)
    }
}
