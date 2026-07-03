import AppKit
import Darwin

/// AppKit lifecycle과 메뉴바 status item을 담당하는 delegate.
///
/// activation policy를 `.accessory`로 설정해 Dock 아이콘 없이
/// 메뉴바 utility로 동작하게 한다.
///
/// - Note: TICKET-001 범위. global hotkey/event tap/overlay/click은 다루지 않는다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// 메뉴바에 표시되는 status item. 강한 참조로 생명주기 동안 유지한다.
    private var statusItem: NSStatusItem?

    /// kill switch 메뉴 항목. 세션 상태에 따라 타이틀을 갱신한다.
    private var sessionMenuItem: NSMenuItem?

    /// overlay activation global keyDown monitor token.
    private var globalShortcutMonitor: Any?

    /// overlay activation local keyDown monitor token.
    private var localShortcutMonitor: Any?

    /// onboarding 완료 여부 판정용 상태.
    private let onboarding = OnboardingState()

    /// Accessibility 권한 요청/설정 이동을 담당한다.
    private let permissionManager = PermissionManager()

    /// 실행 시 전달된 로컬 평가/복구 옵션.
    private let launchOptions = AppLaunchOptions.current

    /// 메뉴바 activation에서 overlay session을 시작하는 runtime coordinator.
    private lazy var overlaySessionController = OverlaySessionController(
        targetResolver: makeTargetResolver(),
        clickResultObserver: { [weak self] result in
            self?.printOverlayClickResultIfNeeded(result)
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 메뉴바 앱: Dock 아이콘 없이 accessory 모드로 동작.
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        installOverlayActivationShortcut()
        AppLogger.lifecycle.info("app launched")

        // 첫 실행이면 Settings를 열어 onboarding 시트가 뜨게 한다.
        if !onboarding.hasCompleted {
            openSettings()
        }

        requestAccessibilityPermissionIfRequested()
        showOverlayIfRequested()
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeOverlayActivationShortcut()
        AppLogger.lifecycle.info("app terminated")
    }

    // MARK: - Status Item

    /// 메뉴바 status item과 메뉴(Open Settings, Quit)를 구성한다.
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "cursorarrow.rays",
                accessibilityDescription: "GazeRow"
            )
            button.image?.isTemplate = true
        }

        item.menu = buildMenu()
        statusItem = item
    }

    /// status item 메뉴를 생성한다.
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let openSettings = NSMenuItem(
            title: "Open Settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        openSettings.target = self
        menu.addItem(openSettings)

        let showOverlay = NSMenuItem(
            title: "Show Overlay",
            action: #selector(showOverlay),
            keyEquivalent: " "
        )
        showOverlay.keyEquivalentModifierMask = [.command, .shift]
        showOverlay.target = self
        menu.addItem(showOverlay)

        menu.addItem(.separator())

        // kill switch: 세션 즉시 중단/재개 경로 (SD-006).
        let session = NSMenuItem(
            title: sessionMenuTitle(),
            action: #selector(toggleSession),
            keyEquivalent: ""
        )
        session.target = self
        menu.addItem(session)
        sessionMenuItem = session

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit GazeRow",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    // MARK: - Menu Actions

    /// Settings window를 연다.
    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)

        // macOS 14+ 에서 SwiftUI Settings scene을 여는 표준 selector.
        if #available(macOS 14.0, *) {
            NSApp.sendAction(
                Selector(("showSettingsWindow:")),
                to: nil,
                from: nil
            )
        } else {
            NSApp.sendAction(
                Selector(("showPreferencesWindow:")),
                to: nil,
                from: nil
            )
        }

        AppLogger.lifecycle.info("settings opened")
    }

    /// 세션 활성/비활성(kill switch)을 토글하고 메뉴 타이틀을 갱신한다.
    @objc private func toggleSession() {
        SessionController.shared.toggle()
        sessionMenuItem?.title = sessionMenuTitle()
    }

    /// 현재 frontmost window를 기준으로 overlay session을 시작한다.
    @objc private func showOverlay() {
        switch overlaySessionController.start() {
        case .success(let snapshot):
            AppLogger.overlay.info(
                "overlay shown bundle=\(snapshot.context.application.bundleIdentifier, privacy: .public) labels=\(snapshot.layout.metrics.labelCount, privacy: .public)"
            )
            printOverlayLaunchResultIfNeeded(
                OverlayLaunchReporter.success(labelCount: snapshot.layout.metrics.labelCount)
            )
            printOverlayLabelMapIfNeeded(snapshot)
        case .failure(let failure):
            AppLogger.overlay.info("overlay start failed reason=\(failure.logCode, privacy: .public)")
            printOverlayLaunchResultIfNeeded(
                OverlayLaunchReporter.failure(logCode: failure.logCode)
            )
            requestAccessibilityPermissionIfNeeded(for: failure)
        }
    }

    /// 앱 안팎에서 동작하는 overlay activation shortcut monitor를 설치한다.
    private func installOverlayActivationShortcut() {
        globalShortcutMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let input = OverlayActivationShortcutInput(event: event)
            guard OverlayActivationShortcut.defaultShortcut.matches(input) else {
                return
            }

            Task { @MainActor in
                self?.showOverlay()
            }
        }

        localShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let input = OverlayActivationShortcutInput(event: event)

            guard OverlayActivationShortcut.defaultShortcut.matches(input) else {
                return event
            }

            Task { @MainActor in
                self?.showOverlay()
            }
            return nil
        }
    }

    /// overlay activation shortcut monitor를 제거한다.
    private func removeOverlayActivationShortcut() {
        if let globalShortcutMonitor {
            NSEvent.removeMonitor(globalShortcutMonitor)
            self.globalShortcutMonitor = nil
        }

        if let localShortcutMonitor {
            NSEvent.removeMonitor(localShortcutMonitor)
            self.localShortcutMonitor = nil
        }
    }

    /// Accessibility 권한 부족으로 overlay activation이 실패하면 권한 요청 동선을 연다.
    private func requestAccessibilityPermissionIfNeeded(for failure: OverlaySessionStartFailure) {
        guard failure.requiresAccessibilityPermission else {
            return
        }

        permissionManager.requestAccessibilityPermission()
        permissionManager.openAccessibilitySettings()
    }

    /// 평가자가 CLI로 앱을 실행할 때 권한 요청 동선을 바로 열 수 있게 한다.
    private func requestAccessibilityPermissionIfRequested() {
        guard launchOptions.requestsAccessibilityPermission else {
            return
        }

        permissionManager.requestAccessibilityPermission()
        permissionManager.openAccessibilitySettings()
        AppLogger.permission.info("accessibility request launched from startup option")
    }

    /// TICKET-010 수동 평가에서 메뉴바 클릭 없이 overlay activation을 재현한다.
    private func showOverlayIfRequested() {
        guard launchOptions.showsOverlayOnLaunch else {
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            printOverlayLaunchResultIfNeeded(
                OverlayLaunchReporter.starting(bundleIdentifier: launchOptions.targetBundleIdentifier)
            )
            showOverlay()
        }
    }

    /// launch option에 명시 target이 있으면 해당 앱을 우선 대상으로 삼는다.
    private func makeTargetResolver() -> TargetResolver {
        guard let bundleIdentifier = launchOptions.targetBundleIdentifier else {
            return TargetResolver()
        }

        return TargetResolver(
            frontmostApplicationProvider: BundleIdentifierApplicationProvider(
                bundleIdentifier: bundleIdentifier
            )
        )
    }

    /// 런치 옵션 기반 smoke 실행에서만 stdout 결과를 남긴다.
    private func printOverlayLaunchResultIfNeeded(_ message: String) {
        guard launchOptions.showsOverlayOnLaunch else {
            return
        }

        print(message)
        fflush(stdout)
    }

    /// 로컬 평가용 label map을 stdout에 출력한다.
    private func printOverlayLabelMapIfNeeded(_ snapshot: OverlaySessionSnapshot) {
        guard launchOptions.printsOverlayLabelMap else {
            return
        }

        OverlayLaunchReporter
            .labelMap(layout: snapshot.layout, candidates: snapshot.scanResult.candidates)
            .forEach { message in
                print(message)
                fflush(stdout)
            }
    }

    /// 런치 옵션 기반 평가에서 keyboard confirm click 결과를 stdout에 출력한다.
    private func printOverlayClickResultIfNeeded(
        _ result: Result<ClickExecutionSuccess, OverlaySessionClickFailure>
    ) {
        guard launchOptions.showsOverlayOnLaunch else {
            return
        }

        print(OverlayLaunchReporter.clickResult(result))
        fflush(stdout)
    }

    /// 현재 세션 상태에 맞는 kill switch 메뉴 타이틀.
    private func sessionMenuTitle() -> String {
        SessionController.shared.isEnabled ? "Disable GazeRow" : "Enable GazeRow"
    }

    /// 앱을 종료한다.
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
