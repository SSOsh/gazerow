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

/// 지정한 bundle identifier의 실행 중인 앱을 target application으로 반환한다.
///
/// TICKET-010 로컬 평가에서 launch 중 frontmost 앱이 바뀌는 문제를 피하기 위한
/// 명시적 target 선택 provider다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct BundleIdentifierApplicationProvider: FrontmostApplicationProviding {
    private let bundleIdentifier: String
    private let runningApplications: () -> [NSRunningApplication]

    init(
        bundleIdentifier: String,
        runningApplications: @escaping () -> [NSRunningApplication] = {
            NSWorkspace.shared.runningApplications
        }
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.runningApplications = runningApplications
    }

    func frontmostApplication() -> TargetApplication? {
        runningApplications()
            .first { $0.bundleIdentifier == bundleIdentifier }
            .map {
                TargetApplication(
                    localizedName: $0.localizedName ?? "Unknown Application",
                    bundleIdentifier: $0.bundleIdentifier ?? bundleIdentifier,
                    processIdentifier: $0.processIdentifier
                )
            }
    }
}
