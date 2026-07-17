import AppKit
import Carbon.HIToolbox
import SwiftUI

/// transparent overlay panel lifecycle을 관리한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class OverlayWindowController {
    private static let labelPanelLevel = NSWindow.Level(
        rawValue: NSWindow.Level.statusBar.rawValue + 1
    )

    private var targetPanel: OverlayPanel?
    private var commandBarPanel: OverlayPanel?
    private var targetHostingView: NSHostingView<OverlayView>?
    private var commandBarHostingView: NSHostingView<OverlayCommandBarPanelView>?
    private var currentLayout: OverlayLayout?
    private var currentCommandBarVisibleFrame: CGRect?
    private var currentCommandBarAvoidingFrames: [CGRect] = []
    private var currentStatus = OverlayInteractionStatus()
    private let layoutEngine: OverlayLayoutEngine
    private let commandBarLayoutEngine: OverlayCommandBarLayoutEngine
    private let displayInfoProvider: @MainActor (CGRect) -> OverlayDisplayInfo
    private let screenFrameProvider: @MainActor () -> [CGRect]
    private let screenDescriptorProvider: @MainActor () -> [OverlayScreenDescriptor]
    private let applicationActivator: @MainActor () -> Void
    private let keyboardEventTapFactory: @MainActor (
        @escaping @MainActor @Sendable (FocusKeyboardCommand) -> Void
    ) -> any OverlayKeyboardEventTapping
    /// 렌더 시점마다 최신 appearance 설정을 읽어 오도록 provider로 주입한다.
    private let appearanceProvider: @MainActor () -> OverlayAppearance
    private var keyboardEventTap: (any OverlayKeyboardEventTapping)?

    init(
        layoutEngine: OverlayLayoutEngine = OverlayLayoutEngine(),
        commandBarLayoutEngine: OverlayCommandBarLayoutEngine = OverlayCommandBarLayoutEngine(),
        displayInfoProvider: @escaping @MainActor (CGRect) -> OverlayDisplayInfo = OverlayWindowController.defaultDisplayInfo,
        screenFrameProvider: @escaping @MainActor () -> [CGRect] = {
            NSScreen.screens.map(\.frame)
        },
        screenDescriptorProvider: @escaping @MainActor () -> [OverlayScreenDescriptor] = OverlayWindowController.defaultScreenDescriptors,
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
        self.commandBarLayoutEngine = commandBarLayoutEngine
        self.displayInfoProvider = displayInfoProvider
        self.screenFrameProvider = screenFrameProvider
        self.screenDescriptorProvider = screenDescriptorProvider
        self.applicationActivator = applicationActivator
        self.keyboardEventTapFactory = keyboardEventTapFactory
        self.appearanceProvider = appearanceProvider
    }

    var isVisible: Bool {
        targetPanel?.isVisible == true && commandBarPanel?.isVisible == true
    }

    var isTargetPanelVisible: Bool {
        targetPanel?.isVisible == true
    }

    var isCommandBarPanelVisible: Bool {
        commandBarPanel?.isVisible == true
    }

    var commandBarPanelFrame: CGRect? {
        commandBarPanel?.frame
    }

    /// 선택 label은 안내용 command bar보다 앞에 표시되어야 한다.
    var labelsRenderAboveCommandBar: Bool {
        guard let targetPanel, let commandBarPanel else {
            return false
        }

        return targetPanel.level.rawValue > commandBarPanel.level.rawValue
    }

    var targetHostingViewIdentifier: ObjectIdentifier? {
        targetHostingView.map(ObjectIdentifier.init)
    }

    var commandBarHostingViewIdentifier: ObjectIdentifier? {
        commandBarHostingView.map(ObjectIdentifier.init)
    }

    /// 표시 중인 overlay panel이 앱 비활성 상태에서도 유지되는지 여부.
    ///
    /// LSUIElement 앱은 overlay 표시 시 자기 앱을 활성화하지 않으므로, panel이
    /// `hidesOnDeactivate`로 자동 숨김되면 화면에 나타나지 않는다.
    var persistsWhileAppInactive: Bool {
        targetPanel?.hidesOnDeactivate == false && commandBarPanel?.hidesOnDeactivate == false
    }

    func show(
        targetFrame: CGRect,
        candidates: [ClickableCandidate],
        labels: [String] = [],
        onEscape: @escaping () -> Void = {},
        onKeyboardCommand: @MainActor @escaping (FocusKeyboardCommand) -> Void = { _ in }
    ) -> OverlayLayout {
        let layout = makeLayout(
            targetFrame: targetFrame,
            candidates: candidates,
            labels: labels
        )

        show(
            layout: layout,
            onEscape: onEscape,
            onKeyboardCommand: onKeyboardCommand
        )
        return layout
    }

    func makeLayout(
        targetFrame: CGRect,
        candidates: [ClickableCandidate],
        labels: [String] = []
    ) -> OverlayLayout {
        layoutEngine.makeLayout(
            targetFrame: targetFrame,
            candidates: candidates,
            labels: labels,
            displayInfo: displayInfoProvider(targetFrame)
        )
    }

    func show(
        layout: OverlayLayout,
        onEscape: @escaping () -> Void = {},
        onKeyboardCommand: @MainActor @escaping (FocusKeyboardCommand) -> Void = { _ in }
    ) {
        _ = show(
            layout: layout,
            initialStatus: OverlayInteractionStatus(),
            onEscape: onEscape,
            onKeyboardCommand: { capturedCommand in
                onKeyboardCommand(capturedCommand.command)
            },
            onPresentationEvent: { _ in }
        )
    }

    @discardableResult
    func show(
        layout: OverlayLayout,
        initialStatus: OverlayInteractionStatus,
        onEscape: @escaping () -> Void = {},
        onKeyboardCommand: @MainActor @escaping (OverlayCapturedKeyboardCommand) -> Void = { _ in },
        onPresentationEvent: @MainActor @escaping (OverlayPresentationEvent) -> Void
    ) -> OverlayKeyboardCaptureMode {
        close()
        let mapper = OverlayScreenFrameMapper(screenFrames: screenFrameProvider())
        let targetPanelFrame = mapper.appKitFrame(fromAXFrame: layout.targetFrame)
        let targetScreen = commandBarLayoutEngine.screen(
            containing: targetPanelFrame,
            in: screenDescriptorProvider()
        )
        let avoidingFrames = commandBarAvoidingFrames(for: layout, mapper: mapper)
        let commandLayout = commandBarLayout(
            for: initialStatus,
            visibleFrame: targetScreen.visibleFrame,
            avoidingFrames: avoidingFrames
        )
        let targetPanel = makePanel(frame: targetPanelFrame, level: Self.labelPanelLevel)
        let commandBarPanel = makePanel(frame: commandLayout.panelFrame)

        targetPanel.onEscape = { [weak self] in
            self?.close()
            onEscape()
        }
        targetPanel.onKeyboardCommand = { command in
            onKeyboardCommand(
                OverlayCapturedKeyboardCommand(command: command, captureMode: .panelFallback)
            )
        }

        self.targetPanel = targetPanel
        self.commandBarPanel = commandBarPanel
        currentCommandBarVisibleFrame = targetScreen.visibleFrame
        currentCommandBarAvoidingFrames = avoidingFrames
        currentLayout = layout
        currentStatus = initialStatus
        render(layout: layout, status: currentStatus)
        let captureMode = prepareKeyboardCapture(
            onKeyboardCommand: onKeyboardCommand,
            panel: targetPanel
        )
        onPresentationEvent(.captureReady(captureMode))
        commandBarPanel.orderFrontRegardless()
        targetPanel.orderFrontRegardless()
        onPresentationEvent(.panelsOrdered)
        targetPanel.displayIfNeeded()
        commandBarPanel.displayIfNeeded()
        Task { @MainActor [weak self, weak targetPanel, weak commandBarPanel] in
            guard let self,
                  self.targetPanel === targetPanel,
                  self.commandBarPanel === commandBarPanel else {
                return
            }
            onPresentationEvent(.firstDisplayPass)
        }
        return captureMode
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
                isGazeTargeting: currentStatus.isGazeTargeting,
                highlightFrame: currentStatus.highlightFrame,
                enterActionHint: currentStatus.enterActionHint,
                windowMatchPreviews: currentStatus.windowMatchPreviews,
                message: currentStatus.message,
                tone: currentStatus.tone,
                phase: currentStatus.phase,
                requiresSecondConfirm: currentStatus.requiresSecondConfirm,
                hasExplicitFocus: currentStatus.hasExplicitFocus
            )
        )
    }

    func updateStatus(_ status: OverlayInteractionStatus) {
        guard let currentLayout else {
            return
        }

        currentStatus = status
        syncKeyboardState(QueryInputState(
            buffer: status.queryBuffer,
            pinnedScope: status.pinnedScope,
            lastScope: status.activeScope
        ))
        render(layout: currentLayout, status: status)
    }

    func close() {
        keyboardEventTap?.stop()
        keyboardEventTap = nil
        targetPanel?.orderOut(nil)
        commandBarPanel?.orderOut(nil)
        targetPanel = nil
        commandBarPanel = nil
        targetHostingView = nil
        commandBarHostingView = nil
        currentLayout = nil
        currentCommandBarVisibleFrame = nil
        currentCommandBarAvoidingFrames = []
        currentStatus = OverlayInteractionStatus()
    }

    private func prepareKeyboardCapture(
        onKeyboardCommand: @escaping @MainActor (OverlayCapturedKeyboardCommand) -> Void,
        panel: OverlayPanel
    ) -> OverlayKeyboardCaptureMode {
        let eventTap = keyboardEventTapFactory { command in
            onKeyboardCommand(
                OverlayCapturedKeyboardCommand(command: command, captureMode: .eventTap)
            )
        }
        keyboardEventTap = eventTap

        guard eventTap.start() else {
            AppLogger.overlay.info("overlay keyboard event tap unavailable; activating app fallback")
            activateKeyboardFocusFallback(panel: panel)
            return .panelFallback
        }

        AppLogger.overlay.info("overlay keyboard event tap enabled")
        return .eventTap
    }

    private func activateKeyboardFocusFallback(panel: OverlayPanel) {
        applicationActivator()
        panel.makeKey()
        if !panel.isKeyWindow {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    private func render(layout: OverlayLayout, status: OverlayInteractionStatus) {
        let overlayView = OverlayView(
            layout: layout,
            focusedLabelID: focusedLabelID(for: status.focusedLabel),
            status: status,
            appearance: appearanceProvider()
        )
        if let targetHostingView {
            targetHostingView.rootView = overlayView
        } else {
            let hostingView = NSHostingView(rootView: overlayView)
            targetHostingView = hostingView
            targetPanel?.contentView = hostingView
        }

        guard let commandBarPanel, let currentCommandBarVisibleFrame else {
            return
        }

        let commandLayout = commandBarLayout(
            for: status,
            visibleFrame: currentCommandBarVisibleFrame,
            avoidingFrames: currentCommandBarAvoidingFrames
        )
        commandBarPanel.setFrame(commandLayout.panelFrame, display: false)
        let commandBarView = OverlayCommandBarPanelView(
            layout: commandLayout,
            status: status,
            language: AppLanguageSettings().selectedLanguage
        )
        if let commandBarHostingView {
            commandBarHostingView.rootView = commandBarView
        } else {
            let hostingView = NSHostingView(rootView: commandBarView)
            commandBarHostingView = hostingView
            commandBarPanel.contentView = hostingView
        }
    }

    private func syncKeyboardState(_ state: QueryInputState) {
        targetPanel?.syncKeyboardState(state)
        keyboardEventTap?.syncKeyboardState(state)
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
        let screens = defaultScreenDescriptors()
        let mapper = OverlayScreenFrameMapper(screenFrames: screens.map(\.frame))
        let screen = OverlayCommandBarLayoutEngine().screen(
            containing: mapper.appKitFrame(fromAXFrame: targetFrame),
            in: screens
        )

        return OverlayDisplayInfo(
            scaleFactor: screen.scaleFactor,
            visibleFrame: mapper.axFrame(fromAppKitFrame: screen.visibleFrame)
        )
    }

    private func makePanel(
        frame: CGRect,
        level: NSWindow.Level = .statusBar
    ) -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = level
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func commandBarLayout(
        for status: OverlayInteractionStatus,
        visibleFrame: CGRect,
        avoidingFrames: [CGRect]
    ) -> OverlayCommandBarLayout {
        commandBarLayoutEngine.makeLayout(
            visibleFrame: visibleFrame,
            showsWindowPreviews: !status.windowMatchPreviews.isEmpty,
            showsMessage: status.phase == .awaitingRiskConfirmation || status.phase == .failure,
            avoidingFrames: avoidingFrames
        )
    }

    private func commandBarAvoidingFrames(
        for layout: OverlayLayout,
        mapper: OverlayScreenFrameMapper
    ) -> [CGRect] {
        layout.labels.map { label in
            let screenFrame = label.labelFrame.offsetBy(
                dx: layout.targetFrame.minX,
                dy: layout.targetFrame.minY
            )
            return mapper.appKitFrame(fromAXFrame: screenFrame)
        }
    }

    private static func defaultScreenDescriptors() -> [OverlayScreenDescriptor] {
        NSScreen.screens.map {
            OverlayScreenDescriptor(
                frame: $0.frame,
                visibleFrame: $0.visibleFrame,
                scaleFactor: $0.backingScaleFactor
            )
        }
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

    func syncKeyboardState(_ state: QueryInputState) {
        keyboardRouter.syncKeyboardState(state)
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
    func syncKeyboardState(_ state: QueryInputState)
}

extension OverlayKeyboardEventTapping {
    func syncKeyboardState(_ state: QueryInputState) {}
}

/// CGEvent tap 기반 overlay keyboard capture.
///
/// @author suho.do
/// @since 2026-07-04
final class OverlayKeyboardEventTap: OverlayKeyboardEventTapping {
    private let context: OverlayKeyboardEventTapContext
    private let isSecureEventInputEnabled: () -> Bool
    private let hasListenEventAccess: () -> Bool
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(
        isSecureEventInputEnabled: @escaping () -> Bool = {
            IsSecureEventInputEnabled()
        },
        hasListenEventAccess: @escaping () -> Bool = {
            CGPreflightListenEventAccess()
        },
        onKeyboardCommand: @escaping @MainActor @Sendable (FocusKeyboardCommand) -> Void
    ) {
        self.context = OverlayKeyboardEventTapContext(onKeyboardCommand: onKeyboardCommand)
        self.isSecureEventInputEnabled = isSecureEventInputEnabled
        self.hasListenEventAccess = hasListenEventAccess
    }

    func start() -> Bool {
        stop()

        guard !isSecureEventInputEnabled() else {
            AppLogger.overlay.info("overlay keyboard event tap blocked by secure event input")
            return false
        }

        guard hasListenEventAccess() else {
            AppLogger.overlay.info("overlay keyboard event tap blocked by input monitoring permission")
            return false
        }

        context.startAcceptingCommands()

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

        context.stopAcceptingCommands()
        context.eventTap = nil
        eventTap = nil
        runLoopSource = nil
    }

    func syncKeyboardState(_ state: QueryInputState) {
        context.syncKeyboardState(state)
    }

}

final class OverlayKeyboardEventTapContext: @unchecked Sendable {
    var eventTap: CFMachPort?
    private var keyboardRouter = OverlayKeyboardCommandRouter()
    private let onKeyboardCommand: @MainActor @Sendable (FocusKeyboardCommand) -> Void
    private let commandStateLock = NSLock()
    private var isAcceptingCommands = true

    init(onKeyboardCommand: @escaping @MainActor @Sendable (FocusKeyboardCommand) -> Void) {
        self.onKeyboardCommand = onKeyboardCommand
    }

    func syncKeyboardState(_ state: QueryInputState) {
        keyboardRouter.syncKeyboardState(state)
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

        DispatchQueue.main.async { [weak self] in
            guard let self, self.acceptsCommands else {
                return
            }

            MainActor.assumeIsolated {
                self.onKeyboardCommand(command)
            }
        }

        return nil
    }

    func stopAcceptingCommands() {
        commandStateLock.lock()
        isAcceptingCommands = false
        commandStateLock.unlock()
    }

    func startAcceptingCommands() {
        commandStateLock.lock()
        isAcceptingCommands = true
        commandStateLock.unlock()
    }

    private var acceptsCommands: Bool {
        commandStateLock.lock()
        defer { commandStateLock.unlock() }
        return isAcceptingCommands
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

struct OverlayKeyboardCommandRouter {
    private let mapper = FocusKeyboardCommandMapper()
    private var queryInput = QueryInputState()

    mutating func command(for input: FocusKeyboardInput) -> FocusKeyboardCommand? {
        guard let command = mapper.command(for: input, queryInput: queryInput) else {
            return nil
        }

        return route(command)
    }

    mutating func syncKeyboardState(_ state: QueryInputState) {
        queryInput = state
    }

    private mutating func route(_ command: FocusKeyboardCommand) -> FocusKeyboardCommand {
        switch command {
        case .typeLabel(let character):
            return .typeLabel(String(character).uppercased().first ?? character)
        case .appendQuery(let grapheme):
            queryInput.buffer.append(grapheme)
            return command
        case .pinScope(let scope):
            queryInput.pinnedScope = scope
            queryInput.lastScope = scope
            return command
        case .deleteQueryCharacter:
            if !queryInput.buffer.isEmpty {
                queryInput.buffer.removeLast()
            }
            return command
        case .clearQueryBuffer, .clearLabelBuffer, .closeOverlay:
            queryInput = QueryInputState()
            return command
        case .selectScope(let scope):
            queryInput = scope == .labels
                ? QueryInputState(lastScope: .labels)
                : QueryInputState(
                    buffer: queryInput.buffer,
                    pinnedScope: scope,
                    lastScope: scope
                )
            return command
        case .move, .cycleMatch, .dryRunConfirm:
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
