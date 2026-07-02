import AppKit

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

    /// onboarding 완료 여부 판정용 상태.
    private let onboarding = OnboardingState()

    /// 메뉴바 activation에서 overlay session을 시작하는 runtime coordinator.
    private let overlaySessionController = OverlaySessionController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 메뉴바 앱: Dock 아이콘 없이 accessory 모드로 동작.
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        AppLogger.lifecycle.info("app launched")

        // 첫 실행이면 Settings를 열어 onboarding 시트가 뜨게 한다.
        if !onboarding.hasCompleted {
            openSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
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
            keyEquivalent: ""
        )
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
        case .failure(let failure):
            AppLogger.overlay.info("overlay start failed reason=\(failure.logCode, privacy: .public)")
        }
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
