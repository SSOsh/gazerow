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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 메뉴바 앱: Dock 아이콘 없이 accessory 모드로 동작.
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        AppLogger.lifecycle.info("app launched")
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

    /// 앱을 종료한다.
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
