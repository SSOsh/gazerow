@preconcurrency import AppKit

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

    nonisolated init() {}

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

/// GazeRow가 frontmost가 된 상태에서는 직전에 활성화된 외부 앱을 반환한다.
///
/// 메뉴바 메뉴나 Settings window에서 overlay를 실행하면 `NSWorkspace.frontmostApplication`
/// 이 GazeRow 자기 자신을 가리킬 수 있다. 이 provider는 그런 경우 직전 non-GazeRow
/// 앱을 target으로 사용해 사용자가 보고 있던 앱 위에 overlay를 띄운다.
///
/// @author suho.do
/// @since 2026-07-03
@MainActor
final class RecentNonSelfApplicationProvider: FrontmostApplicationProviding {
    private static let ignoredBundleIdentifiers: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.dock",
        "com.apple.notificationcenterui",
        "com.apple.systemuiserver"
    ]

    private let ownBundleIdentifier: String
    private let currentApplicationProvider: any FrontmostApplicationProviding
    private let notificationCenter: NotificationCenter
    private var observer: NSObjectProtocol?
    private(set) var lastNonSelfApplication: TargetApplication?

    init(
        ownBundleIdentifier: String = AppState.bundleIdentifier,
        currentApplicationProvider: any FrontmostApplicationProviding = NSWorkspaceFrontmostApplicationProvider(),
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
    ) {
        self.ownBundleIdentifier = ownBundleIdentifier
        self.currentApplicationProvider = currentApplicationProvider
        self.notificationCenter = notificationCenter
        recordIfNonSelf(currentApplicationProvider.frontmostApplication())
        installActivationObserver()
    }

    deinit {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }

    func frontmostApplication() -> TargetApplication? {
        guard let current = currentApplicationProvider.frontmostApplication() else {
            return lastNonSelfApplication
        }

        guard current.bundleIdentifier == ownBundleIdentifier else {
            guard isRecordable(current) else {
                return lastNonSelfApplication
            }
            recordIfNonSelf(current)
            return current
        }

        return lastNonSelfApplication
    }

    func recordIfNonSelf(_ application: TargetApplication?) {
        guard let application,
              isRecordable(application) else {
            return
        }

        lastNonSelfApplication = application
    }

    private func isRecordable(_ application: TargetApplication) -> Bool {
        application.bundleIdentifier != ownBundleIdentifier
            && !Self.ignoredBundleIdentifiers.contains(application.bundleIdentifier)
    }

    private func installActivationObserver() {
        observer = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let runningApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else {
                return
            }

            Task { @MainActor in
                self?.recordIfNonSelf(TargetApplication(runningApplication: runningApplication))
            }
        }
    }
}

private extension TargetApplication {
    init(runningApplication: NSRunningApplication) {
        self.init(
            localizedName: runningApplication.localizedName ?? "Unknown Application",
            bundleIdentifier: runningApplication.bundleIdentifier ?? "unknown.bundle",
            processIdentifier: runningApplication.processIdentifier
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
