import Foundation

/// frontmost app + focused window 기반 target resolver.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct TargetResolver {
    private let frontmostApplicationProvider: FrontmostApplicationProviding
    private let accessibilityClient: AccessibilityTargetClient
    private let dateProvider: () -> Date

    nonisolated init(
        frontmostApplicationProvider: FrontmostApplicationProviding = NSWorkspaceFrontmostApplicationProvider(),
        accessibilityClient: AccessibilityTargetClient = AXAccessibilityTargetClient(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.frontmostApplicationProvider = frontmostApplicationProvider
        self.accessibilityClient = accessibilityClient
        self.dateProvider = dateProvider
    }

    func resolve() -> Result<TargetContext, TargetResolutionFailure> {
        guard let application = frontmostApplicationProvider.frontmostApplication() else {
            return .failure(.noFrontmostApplication)
        }

        guard application.processIdentifier > 0 else {
            return .failure(.invalidProcessIdentifier(application.processIdentifier))
        }

        switch accessibilityClient.focusedWindow(for: application) {
        case .success(let window):
            return resolveContext(application: application, window: window)
        case .failure(let failure):
            return .failure(mapFailure(failure, bundleIdentifier: application.bundleIdentifier))
        }
    }

    private func resolveContext(
        application: TargetApplication,
        window: TargetWindow
    ) -> Result<TargetContext, TargetResolutionFailure> {
        guard window.hasUsableFrame else {
            return .failure(
                .invalidWindowFrame(
                    bundleIdentifier: application.bundleIdentifier,
                    frame: window.frame
                )
            )
        }

        return .success(
            TargetContext(
                application: application,
                window: window,
                resolvedAt: dateProvider()
            )
        )
    }

    private func mapFailure(
        _ failure: AccessibilityReadFailure,
        bundleIdentifier: String
    ) -> TargetResolutionFailure {
        switch failure {
        case .permissionDenied:
            .accessibilityPermissionDenied
        case .focusedWindowUnavailable(let reason):
            .focusedWindowUnavailable(bundleIdentifier: bundleIdentifier, reason: reason)
        case .frameUnavailable(let reason):
            .windowFrameUnavailable(bundleIdentifier: bundleIdentifier, reason: reason)
        }
    }
}
