import AppKit
import SwiftUI

/// transparent overlay panel lifecycle을 관리한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class OverlayWindowController {
    private var panel: OverlayPanel?
    private var currentLayout: OverlayLayout?
    private let layoutEngine: OverlayLayoutEngine
    private let displayInfoProvider: @MainActor (CGRect) -> OverlayDisplayInfo
    private let applicationActivator: @MainActor () -> Void

    init(
        layoutEngine: OverlayLayoutEngine = OverlayLayoutEngine(),
        displayInfoProvider: @escaping @MainActor (CGRect) -> OverlayDisplayInfo = OverlayWindowController.defaultDisplayInfo,
        applicationActivator: @escaping @MainActor () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
        }
    ) {
        self.layoutEngine = layoutEngine
        self.displayInfoProvider = displayInfoProvider
        self.applicationActivator = applicationActivator
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(
        targetFrame: CGRect,
        candidates: [ClickableCandidate],
        labels: [String] = [],
        onEscape: @escaping () -> Void = {},
        onKeyboardCommand: @MainActor @escaping (FocusKeyboardCommand) -> Void = { _ in }
    ) -> OverlayLayout {
        let layout = layoutEngine.makeLayout(
            targetFrame: targetFrame,
            candidates: candidates,
            labels: labels,
            displayInfo: displayInfoProvider(targetFrame)
        )

        show(
            layout: layout,
            onEscape: onEscape,
            onKeyboardCommand: onKeyboardCommand
        )
        return layout
    }

    func show(
        layout: OverlayLayout,
        onEscape: @escaping () -> Void = {},
        onKeyboardCommand: @MainActor @escaping (FocusKeyboardCommand) -> Void = { _ in }
    ) {
        close()

        let panel = OverlayPanel(
            contentRect: layout.targetFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.onEscape = { [weak self] in
            self?.close()
            onEscape()
        }
        panel.onKeyboardCommand = onKeyboardCommand
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.panel = panel
        currentLayout = layout
        render(layout: layout, focusedLabelID: nil)
        applicationActivator()
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func updateFocus(focusedLabelID: Int?) {
        guard let currentLayout else {
            return
        }

        render(layout: currentLayout, focusedLabelID: focusedLabelID)
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
        currentLayout = nil
    }

    private func render(layout: OverlayLayout, focusedLabelID: Int?) {
        panel?.contentView = NSHostingView(
            rootView: OverlayView(
                layout: layout,
                focusedLabelID: focusedLabelID
            )
        )
    }

    static func defaultDisplayInfo(for targetFrame: CGRect) -> OverlayDisplayInfo {
        let screen = NSScreen.screens.first { screen in
            screen.frame.intersects(targetFrame)
        } ?? NSScreen.main

        return OverlayDisplayInfo(
            scaleFactor: screen?.backingScaleFactor ?? 1,
            visibleFrame: screen?.visibleFrame
        )
    }
}

private final class OverlayPanel: NSPanel {
    var onEscape: () -> Void = {}
    var onKeyboardCommand: @MainActor (FocusKeyboardCommand) -> Void = { _ in }
    private let keyboardCommandMapper = FocusKeyboardCommandMapper()

    override var canBecomeKey: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        let input = FocusKeyboardInput(
            keyCode: event.keyCode,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            isShiftPressed: event.modifierFlags.contains(.shift)
        )

        guard let command = keyboardCommandMapper.command(for: input) else {
            super.keyDown(with: event)
            return
        }

        if command == .closeOverlay {
            onEscape()
            return
        }

        onKeyboardCommand(command)
    }
}
