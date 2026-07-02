import AppKit
import SwiftUI

/// transparent overlay panel lifecycle을 관리한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class OverlayWindowController {
    private var panel: OverlayPanel?
    private let layoutEngine: OverlayLayoutEngine
    private let displayInfoProvider: (CGRect) -> OverlayDisplayInfo

    init(
        layoutEngine: OverlayLayoutEngine = OverlayLayoutEngine(),
        displayInfoProvider: @escaping (CGRect) -> OverlayDisplayInfo = OverlayWindowController.defaultDisplayInfo
    ) {
        self.layoutEngine = layoutEngine
        self.displayInfoProvider = displayInfoProvider
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(
        targetFrame: CGRect,
        candidates: [ClickableCandidate],
        labels: [String] = [],
        onEscape: @escaping () -> Void = {}
    ) -> OverlayLayout {
        let layout = layoutEngine.makeLayout(
            targetFrame: targetFrame,
            candidates: candidates,
            labels: labels,
            displayInfo: displayInfoProvider(targetFrame)
        )

        show(layout: layout, onEscape: onEscape)
        return layout
    }

    func show(layout: OverlayLayout, onEscape: @escaping () -> Void = {}) {
        close()

        let panel = OverlayPanel(
            contentRect: layout.targetFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.onEscape = { [weak self] in
            self?.close()
            onEscape()
        }
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: OverlayView(layout: layout))

        self.panel = panel
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
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

    override var canBecomeKey: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape()
            return
        }

        super.keyDown(with: event)
    }
}
