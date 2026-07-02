import AppKit

/// frontmost app 조회 abstraction.
///
/// 테스트에서는 AppKit 전역 상태 없이 snapshot provider를 주입한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
protocol FrontmostApplicationProviding {
    func frontmostApplication() -> TargetApplication?
}

/// `NSWorkspace.frontmostApplication` 기반 provider.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct NSWorkspaceFrontmostApplicationProvider: FrontmostApplicationProviding {

    func frontmostApplication() -> TargetApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return TargetApplication(
            localizedName: application.localizedName ?? "Unknown Application",
            bundleIdentifier: application.bundleIdentifier ?? "unknown.bundle",
            processIdentifier: application.processIdentifier
        )
    }
}
