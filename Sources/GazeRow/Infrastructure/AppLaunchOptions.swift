import Foundation

/// 앱 실행 시 전달되는 로컬 평가/복구용 옵션.
///
/// @author suho.do
/// @since 2026-07-02
struct AppLaunchOptions: Equatable {
    let requestsAccessibilityPermission: Bool
    let showsOverlayOnLaunch: Bool
    let targetBundleIdentifier: String?

    static var current: AppLaunchOptions {
        AppLaunchOptions(arguments: CommandLine.arguments)
    }

    init(arguments: [String]) {
        requestsAccessibilityPermission = arguments.contains("--request-accessibility")
        showsOverlayOnLaunch = arguments.contains("--show-overlay-on-launch")
        targetBundleIdentifier = Self.value(after: "--target-bundle-id", in: arguments)
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
}
