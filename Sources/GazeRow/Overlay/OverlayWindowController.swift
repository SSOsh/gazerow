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
    private let screenFrameProvider: @MainActor () -> [CGRect]
    private let applicationActivator: @MainActor () -> Void

    init(
        layoutEngine: OverlayLayoutEngine = OverlayLayoutEngine(),
        displayInfoProvider: @escaping @MainActor (CGRect) -> OverlayDisplayInfo = OverlayWindowController.defaultDisplayInfo,
        screenFrameProvider: @escaping @MainActor () -> [CGRect] = {
            NSScreen.screens.map(\.frame)
        },
        applicationActivator: @escaping @MainActor () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
        }
    ) {
        self.layoutEngine = layoutEngine
        self.displayInfoProvider = displayInfoProvider
        self.screenFrameProvider = screenFrameProvider
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
        let panelFrame = OverlayScreenFrameMapper(
            screenFrames: screenFrameProvider()
        ).appKitFrame(fromAXFrame: layout.targetFrame)

        let panel = OverlayPanel(
            contentRect: panelFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.onEscape = { [weak self] in
            self?.close()
            onEscape()
        }
        panel.onKeyboardCommand = onKeyboardCommand
        panel.level = .statusBar
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
        let screens = NSScreen.screens
        let mapper = OverlayScreenFrameMapper(screenFrames: screens.map(\.frame))
        let screen = screens.first { screen in
            mapper.axFrame(fromAppKitFrame: screen.frame).intersects(targetFrame)
        } ?? NSScreen.main

        return OverlayDisplayInfo(
            scaleFactor: screen?.backingScaleFactor ?? 1,
            visibleFrame: screen.map { mapper.axFrame(fromAppKitFrame: $0.visibleFrame) }
        )
    }
}

/// AX top-left screen frame과 AppKit bottom-left window frame을 변환한다.
///
/// @author suho.do
/// @since 2026-07-03
struct OverlayScreenFrameMapper {
    private let screenUnion: CGRect

    init(screenFrames: [CGRect]) {
        self.screenUnion = screenFrames.reduce(CGRect.null) { partialResult, frame in
            partialResult.union(frame)
        }
    }

    func appKitFrame(fromAXFrame axFrame: CGRect) -> CGRect {
        guard !screenUnion.isNull else {
            return axFrame
        }

        return CGRect(
            x: axFrame.minX,
            y: screenUnion.maxY - axFrame.maxY,
            width: axFrame.width,
            height: axFrame.height
        )
    }

    func axFrame(fromAppKitFrame appKitFrame: CGRect) -> CGRect {
        guard !screenUnion.isNull else {
            return appKitFrame
        }

        return CGRect(
            x: appKitFrame.minX,
            y: screenUnion.maxY - appKitFrame.maxY,
            width: appKitFrame.width,
            height: appKitFrame.height
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
