import Foundation

/// 앱 실행 시 전달되는 로컬 평가/복구용 옵션.
///
/// @author suho.do
/// @since 2026-07-02
struct AppLaunchOptions: Equatable {
    let requestsAccessibilityPermission: Bool

    static var current: AppLaunchOptions {
        AppLaunchOptions(arguments: CommandLine.arguments)
    }

    init(arguments: [String]) {
        requestsAccessibilityPermission = arguments.contains("--request-accessibility")
    }
}
