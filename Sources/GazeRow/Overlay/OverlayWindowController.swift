import AppKit
import Carbon.HIToolbox
import SwiftUI

/// transparent overlay panel lifecycle을 관리한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class OverlayWindowController {
    private var panel: OverlayPanel?
    private var currentLayout: OverlayLayout?
    private var currentStatus = OverlayInteractionStatus()
    private let layoutEngine: OverlayLayoutEngine
    private let displayInfoProvider: @MainActor (CGRect) -> OverlayDisplayInfo
    private let screenFrameProvider: @MainActor () -> [CGRect]
    private let applicationActivator: @MainActor () -> Void
    private let keyboardEventTapFactory: @MainActor (
        @escaping @MainActor @Sendable (FocusKeyboardCommand) -> Void
    ) -> any OverlayKeyboardEventTapping
    /// 렌더 시점마다 최신 appearance 설정을 읽어 오도록 provider로 주입한다.
    private let appearanceProvider: @MainActor () -> OverlayAppearance
    private var keyboardEventTap: (any OverlayKeyboardEventTapping)?

    init(
        layoutEngine: OverlayLayoutEngine = OverlayLayoutEngine(),
        displayInfoProvider: @escaping @MainActor (CGRect) -> OverlayDisplayInfo = OverlayWindowController.defaultDisplayInfo,
        screenFrameProvider: @escaping @MainActor () -> [CGRect] = {
            NSScreen.screens.map(\.frame)
        },
        applicationActivator: @escaping @MainActor () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
        },
        keyboardEventTapFactory: @escaping @MainActor (
            @escaping @MainActor @Sendable (FocusKeyboardCommand) -> Void
        ) -> any OverlayKeyboardEventTapping = { handler in
            OverlayKeyboardEventTap(onKeyboardCommand: handler)
        },
        appearanceProvider: @escaping @MainActor () -> OverlayAppearance = {
            OverlayAppearanceSettings().appearance
        }
    ) {
        self.layoutEngine = layoutEngine
        self.displayInfoProvider = displayInfoProvider
        self.screenFrameProvider = screenFrameProvider
        self.applicationActivator = applicationActivator
        self.keyboardEventTapFactory = keyboardEventTapFactory
        self.appearanceProvider = appearanceProvider
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    /// 표시 중인 overlay panel이 앱 비활성 상태에서도 유지되는지 여부.
    ///
    /// LSUIElement 앱은 overlay 표시 시 자기 앱을 활성화하지 않으므로, panel이
    /// `hidesOnDeactivate`로 자동 숨김되면 화면에 나타나지 않는다.
    var persistsWhileAppInactive: Bool {
        panel?.hidesOnDeactivate == false
    }

    var acceptsMouseInput: Bool {
        panel?.ignoresMouseEvents == false
    }

    func show(
        targetFrame: CGRect,
        candidates: [ClickableCandidate],
        labels: [String] = [],
        onEscape: @escaping () -> Void = {},
        onKeyboardCommand: @MainActor @escaping (FocusKeyboardCommand) -> Void = { _ in },
        onScopeSelection: @MainActor @escaping (QueryScope) -> Void = { _ in }
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
            onKeyboardCommand: onKeyboardCommand,
            onScopeSelection: onScopeSelection
        )
        return layout
    }

    func show(
        layout: OverlayLayout,
        onEscape: @escaping () -> Void = {},
        onKeyboardCommand: @MainActor @escaping (FocusKeyboardCommand) -> Void = { _ in },
        onScopeSelection: @MainActor @escaping (QueryScope) -> Void = { _ in }
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
        panel.onScopeSelection = onScopeSelection
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        // NSPanel은 hidesOnDeactivate 기본값이 true라 앱 비활성 시 자동 숨김된다.
        // overlay는 앱을 활성화하지 않고(사용자 앱 포커스 유지) 표시해야 하므로 끈다.
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.panel = panel
        currentLayout = layout
        currentStatus = OverlayInteractionStatus()
        render(layout: layout, status: currentStatus)
        panel.orderFrontRegardless()
        prepareKeyboardCapture(
            onKeyboardCommand: onKeyboardCommand,
            panel: panel
        )
    }

    func updateFocus(focusedLabelID: Int?) {
        updateStatus(
            OverlayInteractionStatus(
                focusedLabel: labelText(for: focusedLabelID),
                typedLabelBuffer: currentStatus.typedLabelBuffer,
                queryBuffer: currentStatus.queryBuffer,
                activeScope: currentStatus.activeScope,
                pinnedScope: currentStatus.pinnedScope,
                matchCount: currentStatus.matchCount,
                matchIndex: currentStatus.matchIndex,
                focusedDisplayName: currentStatus.focusedDisplayName,
                enterActionHint: currentStatus.enterActionHint,
                message: currentStatus.message,
                tone: currentStatus.tone
            )
        )
    }

    func updateStatus(_ status: OverlayInteractionStatus) {
        guard let currentLayout else {
            return
        }

        currentStatus = status
        render(layout: currentLayout, status: status)
    }

    func setMouseInputEnabled(_ isEnabled: Bool) {
        panel?.ignoresMouseEvents = !isEnabled
    }

    func close() {
        keyboardEventTap?.stop()
        keyboardEventTap = nil
        panel?.orderOut(nil)
        panel = nil
        currentLayout = nil
        currentStatus = OverlayInteractionStatus()
    }

    private func prepareKeyboardCapture(
        onKeyboardCommand: @escaping @MainActor (FocusKeyboardCommand) -> Void,
        panel: OverlayPanel
    ) {
        let eventTap = keyboardEventTapFactory { command in
            onKeyboardCommand(command)
        }
        keyboardEventTap = eventTap

        guard eventTap.start() else {
            AppLogger.overlay.info("overlay keyboard event tap unavailable; activating app fallback")
            activateKeyboardFocusFallback(panel: panel)
            return
        }

        AppLogger.overlay.info("overlay keyboard event tap enabled")
    }

    private func activateKeyboardFocusFallback(panel: OverlayPanel) {
        applicationActivator()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func render(layout: OverlayLayout, status: OverlayInteractionStatus) {
        panel?.contentView = NSHostingView(
            rootView: OverlayView(
                layout: layout,
                focusedLabelID: focusedLabelID(for: status.focusedLabel),
                status: status,
                appearance: appearanceProvider(),
                onScopeSelection: { [weak self] scope in
                    self?.panel?.onScopeSelection(scope)
                }
            )
        )
    }

    private func labelText(for focusedLabelID: Int?) -> String? {
        guard let focusedLabelID else {
            return nil
        }

        return currentLayout?.labels.first { $0.id == focusedLabelID }?.text
    }

    private func focusedLabelID(for labelText: String?) -> Int? {
        guard let labelText else {
            return nil
        }

        return currentLayout?.labels.first { $0.text == labelText }?.id
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
    var onScopeSelection: @MainActor (QueryScope) -> Void = { _ in }
    private var keyboardRouter = OverlayKeyboardCommandRouter()

    override var canBecomeKey: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        let input = FocusKeyboardInput(
            keyCode: event.keyCode,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            isShiftPressed: event.modifierFlags.contains(.shift)
        )

        guard let command = keyboardRouter.command(for: input) else {
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

/// overlay 표시 중 앱 활성화 없이 keyboard 입력을 가로채는 event tap.
///
/// @author suho.do
/// @since 2026-07-04
@MainActor
protocol OverlayKeyboardEventTapping: AnyObject {
    func start() -> Bool
    func stop()
}

/// CGEvent tap 기반 overlay keyboard capture.
///
/// @author suho.do
/// @since 2026-07-04
final class OverlayKeyboardEventTap: OverlayKeyboardEventTapping {
    private let context: OverlayKeyboardEventTapContext
    private let isSecureEventInputEnabled: () -> Bool
    private let hasListenEventAccess: () -> Bool
    private let requestListenEventAccess: () -> Bool
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(
        isSecureEventInputEnabled: @escaping () -> Bool = {
            IsSecureEventInputEnabled()
        },
        hasListenEventAccess: @escaping () -> Bool = {
            CGPreflightListenEventAccess()
        },
        requestListenEventAccess: @escaping () -> Bool = {
            CGRequestListenEventAccess()
        },
        onKeyboardCommand: @escaping @MainActor @Sendable (FocusKeyboardCommand) -> Void
    ) {
        self.context = OverlayKeyboardEventTapContext(onKeyboardCommand: onKeyboardCommand)
        self.isSecureEventInputEnabled = isSecureEventInputEnabled
        self.hasListenEventAccess = hasListenEventAccess
        self.requestListenEventAccess = requestListenEventAccess
    }

    func start() -> Bool {
        stop()

        guard !isSecureEventInputEnabled() else {
            AppLogger.overlay.info("overlay keyboard event tap blocked by secure event input")
            return false
        }

        guard hasListenEventAccess() || requestListenEventAccess() else {
            AppLogger.overlay.info("overlay keyboard event tap blocked by input monitoring permission")
            return false
        }

        let userInfo = Unmanaged.passUnretained(context).toOpaque()
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: overlayKeyboardEventTapCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }

        context.eventTap = tap
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        context.eventTap = nil
        eventTap = nil
        runLoopSource = nil
    }

}

final class OverlayKeyboardEventTapContext: @unchecked Sendable {
    var eventTap: CFMachPort?
    private var keyboardRouter = OverlayKeyboardCommandRouter()
    private let onKeyboardCommand: @MainActor @Sendable (FocusKeyboardCommand) -> Void

    init(onKeyboardCommand: @escaping @MainActor @Sendable (FocusKeyboardCommand) -> Void) {
        self.onKeyboardCommand = onKeyboardCommand
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        guard let command = keyboardCommand(from: event) else {
            return Unmanaged.passUnretained(event)
        }

        Task { @MainActor in
            onKeyboardCommand(command)
        }

        return nil
    }

    private func keyboardCommand(from event: CGEvent) -> FocusKeyboardCommand? {
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return nil
        }

        return keyboardRouter.command(
            for: FocusKeyboardInput(
                keyCode: nsEvent.keyCode,
                charactersIgnoringModifiers: nsEvent.charactersIgnoringModifiers,
                isShiftPressed: nsEvent.modifierFlags.contains(.shift)
            )
        )
    }
}

private struct OverlayKeyboardCommandRouter {
    private let mapper = FocusKeyboardCommandMapper()
    private var queryInput = QueryInputState()
    private var pendingLabelPrimer: Character?

    mutating func command(for input: FocusKeyboardInput) -> FocusKeyboardCommand? {
        guard let command = mapper.command(for: input, queryInput: queryInput) else {
            return nil
        }

        return route(command)
    }

    private mutating func route(_ command: FocusKeyboardCommand) -> FocusKeyboardCommand {
        switch command {
        case .typeLabel(let character):
            if let pendingLabelPrimer {
                let query = "\(pendingLabelPrimer)\(character)".precomposedStringWithCanonicalMapping
                queryInput.buffer = query
                self.pendingLabelPrimer = nil
                return .appendQuery(query)
            }

            pendingLabelPrimer = Character(String(character).lowercased())
            return command
        case .appendQuery(let grapheme):
            if let pendingLabelPrimer {
                let query = "\(pendingLabelPrimer)\(grapheme)".precomposedStringWithCanonicalMapping
                queryInput.buffer = query
                self.pendingLabelPrimer = nil
                return .appendQuery(query)
            }

            queryInput.buffer.append(grapheme)
            return command
        case .pinScope(let scope):
            queryInput.pinnedScope = scope
            queryInput.lastScope = scope
            pendingLabelPrimer = nil
            return command
        case .deleteQueryCharacter:
            if !queryInput.buffer.isEmpty {
                queryInput.buffer.removeLast()
            }
            pendingLabelPrimer = nil
            return command
        case .clearQueryBuffer, .clearLabelBuffer, .closeOverlay:
            queryInput = QueryInputState()
            pendingLabelPrimer = nil
            return command
        case .selectScope(let scope):
            queryInput = scope == .labels
                ? QueryInputState(lastScope: .labels)
                : QueryInputState(
                    buffer: queryInput.buffer,
                    pinnedScope: scope,
                    lastScope: scope
                )
            pendingLabelPrimer = nil
            return command
        case .move, .cycleMatch, .dryRunConfirm:
            pendingLabelPrimer = nil
            return command
        }
    }
}

private let overlayKeyboardEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let context = Unmanaged<OverlayKeyboardEventTapContext>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return context.handle(type: type, event: event)
}
