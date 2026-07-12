import AppKit
import Darwin
import SwiftUI

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

    /// Settings window를 직접 관리한다. LSUIElement 앱에서는 SwiftUI Settings scene
    /// selector가 환경에 따라 열리지 않을 수 있어 AppKit window를 SSOT로 둔다.
    private var settingsWindow: NSWindow?

    /// kill switch 메뉴 항목. 세션 상태에 따라 타이틀을 갱신한다.
    private var sessionMenuItem: NSMenuItem?

    /// overlay activation global keyDown monitor token.
    private var globalShortcutMonitor: Any?

    /// overlay activation local keyDown monitor token.
    private var localShortcutMonitor: Any?

    /// Carbon 기반 전역 hotkey 등록기.
    private var globalHotKeyControllers: [GlobalHotKeyController] = []

    /// onboarding 완료 여부 판정용 상태.
    private let onboarding = OnboardingState()

    /// 고정키로 표준 윈도우 컨트롤(닫기/최소화/줌)을 실행하는 dispatcher.
    private let windowControlDispatcher = WindowControlCommandDispatcher()

    /// Accessibility 권한 요청/설정 이동을 담당한다.
    private let permissionManager = PermissionManager()

    /// camera gaze opt-in 상태 저장소.
    private let cameraGazeSettings = CameraGazeSettings()

    /// camera 권한 상태 조회기.
    private let cameraPermissionManager = CameraPermissionManager()

    /// gaze calibration sample 저장소.
    private let gazeCalibrationStore = GazeCalibrationStore()

    /// 진행 중인 one-shot gaze 캡처 컨트롤러(캡처 동안만 유지).
    private var gazeOneShotController: GazeOneShotFocusController?

    /// 진행 중인 calibration window controller(표시 동안만 유지).
    private var gazeCalibrationWindowController: GazeCalibrationWindowController?

    /// calibration 요청 알림 관측 토큰.
    private var gazeCalibrationObserver: (any NSObjectProtocol)?

    /// 메뉴/Settings가 frontmost가 되었을 때 직전 외부 앱을 overlay 대상으로 삼는다.
    private lazy var frontmostApplicationProvider = RecentNonSelfApplicationProvider()

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
        observeGazeCalibrationRequests()
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
        if let gazeCalibrationObserver {
            NotificationCenter.default.removeObserver(gazeCalibrationObserver)
            self.gazeCalibrationObserver = nil
        }
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

        let support = NSMenuItem(
            title: localizedContent.supportDonationMenuTitle,
            action: #selector(showSupportDonation),
            keyEquivalent: ""
        )
        support.target = self
        menu.addItem(support)

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
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        AppLogger.lifecycle.info("settings opened")
    }

    /// 커피값 후원 안내를 표시한다.
    @objc private func showSupportDonation() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = localizedContent.supportDonationTitle
        alert.informativeText = localizedContent.supportDonationMessage
        alert.addButton(withTitle: "OK")
        alert.runModal()

        AppLogger.lifecycle.info("support donation opened")
    }

    private var localizedContent: AppContent.Localized {
        AppContent.localized(for: AppLanguageSettings().selectedLanguage)
    }

    /// 메뉴바 앱용 Settings window를 생성한다.
    private func makeSettingsWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)

        window.title = "GazeRow Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()

        return window
    }

    /// 세션 활성/비활성(kill switch)을 토글하고 메뉴 타이틀을 갱신한다.
    @objc private func toggleSession() {
        SessionController.shared.toggle()
        sessionMenuItem?.title = sessionMenuTitle()
    }

    /// 현재 frontmost window를 기준으로 overlay session을 시작한다.
    @objc private func showOverlay() {
        AppLogger.overlay.info("overlay shortcut fired (no camera)")
        switch overlaySessionController.start() {
        case .success(let snapshot):
            AppLogger.overlay.info(
                "overlay shown bundle=\(snapshot.context.application.bundleIdentifier, privacy: .public) labels=\(snapshot.layout.metrics.labelCount, privacy: .public)"
            )
            printOverlayLaunchResultIfNeeded(
                OverlayLaunchReporter.success(labelCount: snapshot.layout.metrics.labelCount)
            )
            printOverlayLabelMapIfNeeded(snapshot)
            performQueryIfRequested()
            clickOverlayLabelIfRequested()
        case .failure(let failure):
            AppLogger.overlay.info("overlay start failed reason=\(failure.logCode, privacy: .public)")
            printOverlayLaunchResultIfNeeded(
                OverlayLaunchReporter.failure(logCode: failure.logCode)
            )
            printOverlayFailureDetailsIfNeeded(failure)
            presentOverlayStartFailureGuidanceIfNeeded(for: failure)
            requestAccessibilityPermissionIfNeeded(for: failure)
        }
    }

    /// gaze focus(Control+Shift+Space) 동선을 실행한다.
    ///
    /// opt-in·카메라 권한·캘리브레이션이 모두 준비된 경우에만 overlay를 띄우고,
    /// one-shot으로 gaze point를 한 번 추정해 최근접 label로 focus를 옮긴다.
    /// 자동 클릭은 하지 않는다(사용자가 Enter로 확정).
    @objc private func showGazeOverlay() {
        AppLogger.gaze.info("gaze shortcut fired (Control+Shift+Space)")
        let decision = makeGazeActivationGate().evaluate()
        guard decision == .proceed else {
            handleGazeBlocked(decision)
            return
        }

        guard case .success = overlaySessionController.start() else {
            AppLogger.gaze.info("gaze overlay start failed")
            return
        }

        startGazeOneShotCapture()
    }

    /// 현재 상태 기준 gaze 실행 게이트를 만든다.
    private func makeGazeActivationGate() -> GazeActivationGate {
        GazeActivationGate(
            isOptInEnabled: { [cameraGazeSettings] in
                cameraGazeSettings.isOptInEnabled
            },
            isCameraAuthorized: { [cameraPermissionManager] in
                cameraPermissionManager.refresh()
                return cameraPermissionManager.cameraStatus.isAuthorized
            },
            isCalibrationReady: { [gazeCalibrationStore] in
                GazeCalibrationModel(samples: gazeCalibrationStore.load()).isReady
            }
        )
    }

    /// gaze 실행 차단 사유를 설명한 뒤, 사용자가 동의하면 해당 설정으로 이동한다.
    ///
    /// 시스템 설정 창이 이유 없이 튀어나오는 혼란을 막기 위해 먼저 안내 alert를
    /// 띄우고, 확인을 누른 경우에만 다음 단계(설정/카메라 권한)로 안내한다.
    private func handleGazeBlocked(_ decision: GazeActivationDecision) {
        guard case .blocked(let reason) = decision else {
            return
        }

        AppLogger.gaze.info("gaze blocked reason=\(String(describing: reason), privacy: .public)")

        let guidance = GazeActivationBlockGuidance(reason: reason)
        guard presentGazeBlockedAlert(guidance) else {
            return
        }

        routeToGazeSetup(for: reason)
    }

    /// 차단 안내 alert를 띄우고, 사용자가 이동 버튼을 눌렀는지 여부를 돌려준다.
    private func presentGazeBlockedAlert(_ guidance: GazeActivationBlockGuidance) -> Bool {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = guidance.title
        alert.informativeText = guidance.message
        alert.addButton(withTitle: guidance.actionButtonTitle)
        alert.addButton(withTitle: guidance.cancelButtonTitle)

        return alert.runModal() == .alertFirstButtonReturn
    }

    /// 차단 사유에 맞는 설정 화면으로 이동한다.
    private func routeToGazeSetup(for reason: GazeActivationBlockReason) {
        switch reason {
        case .cameraPermissionDenied:
            cameraPermissionManager.openCameraSettings()
        case .optInDisabled, .calibrationUnavailable:
            openSettings()
        }
    }

    /// one-shot gaze 캡처를 시작하고, 성공 시 최근접 label로 focus를 옮긴다.
    private func startGazeOneShotCapture() {
        let estimator = GazePointEstimator(
            calibrationModel: GazeCalibrationModel(samples: gazeCalibrationStore.load())
        )
        let controller = GazeOneShotFocusController(pointEstimator: estimator)
        gazeOneShotController = controller

        controller.start { [weak self] result in
            Task { @MainActor in
                self?.handleGazeCaptureResult(result)
            }
        }
    }

    /// Settings에서 오는 calibration 시작 요청을 관측한다.
    private func observeGazeCalibrationRequests() {
        gazeCalibrationObserver = NotificationCenter.default.addObserver(
            forName: .gazeCalibrationRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.startGazeCalibration()
            }
        }
    }

    /// full-screen calibration overlay를 띄워 캘리브레이션을 시작한다.
    private func startGazeCalibration() {
        guard gazeCalibrationWindowController == nil else {
            return
        }

        let controller = GazeCalibrationWindowController { [weak self] result in
            self?.gazeCalibrationWindowController = nil
            switch result {
            case .success(let samples):
                AppLogger.gaze.info("calibration saved count=\(samples.count, privacy: .public)")
            case .failure(let failure):
                AppLogger.gaze.info("calibration ended reason=\(String(describing: failure), privacy: .public)")
            }
        }
        gazeCalibrationWindowController = controller
        controller.present()
    }

    /// one-shot gaze 캡처 결과를 overlay focus로 반영한다.
    @MainActor
    private func handleGazeCaptureResult(_ result: Result<CGPoint, GazeOneShotFailure>) {
        gazeOneShotController = nil

        switch result {
        case .success(let point):
            _ = overlaySessionController.focusNearestLabel(to: point)
            AppLogger.gaze.info("gaze focus moved")
        case .failure(let failure):
            AppLogger.gaze.info("gaze capture failed reason=\(String(describing: failure), privacy: .public)")
        }
    }

    /// 앱 안팎에서 동작하는 overlay activation shortcut monitor를 설치한다.
    private func installOverlayActivationShortcut() {
        let registrationStatuses = registerGlobalHotKeys()
        printHotKeyRegistrationIfNeeded(registrationStatuses)
        presentHotKeyRegistrationGuidanceIfNeeded(registrationStatuses)

        globalShortcutMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let overlayCommand = Self.focusKeyboardCommand(from: event)
            let input = OverlayActivationShortcutInput(event: event)

            if let overlayCommand {
                Task { @MainActor in
                    _ = self?.handleOverlayKeyboardCommand(overlayCommand)
                }
            }

            switch overlayActivationMonitorRoute(for: input) {
            case .gaze:
                Task { @MainActor in
                    self?.showGazeOverlay()
                }
            case .consumeOverlayActivation:
                // overlay activation은 Carbon hotkey가 담당한다. 중복 실행 방지를 위해
                // monitor에서는 아무 것도 하지 않는다.
                break
            case .windowControl:
                Task { @MainActor in
                    self?.handleWindowControlShortcut(input)
                }
            }
        }

        localShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let overlayCommand = Self.focusKeyboardCommand(from: event),
               MainActor.assumeIsolated({ self?.handleOverlayKeyboardCommand(overlayCommand) == true }) {
                return nil
            }

            let input = OverlayActivationShortcutInput(event: event)

            switch overlayActivationMonitorRoute(for: input) {
            case .gaze:
                Task { @MainActor in
                    self?.showGazeOverlay()
                }
                return nil
            case .consumeOverlayActivation:
                // Carbon hotkey가 activation을 담당하므로 이벤트만 소비한다.
                return nil
            case .windowControl:
                Task { @MainActor in
                    self?.handleWindowControlShortcut(input)
                }
                return event
            }
        }
    }

    private static func focusKeyboardCommand(from event: NSEvent) -> FocusKeyboardCommand? {
        FocusKeyboardCommandMapper().command(
            for: FocusKeyboardInput(
                keyCode: event.keyCode,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                isShiftPressed: event.modifierFlags.contains(.shift)
            )
        )
    }

    @MainActor
    private func handleOverlayKeyboardCommand(_ command: FocusKeyboardCommand) -> Bool {
        guard overlaySessionController.activeSession != nil else {
            AppLogger.interaction.info(
                "overlay key ignored (no active session) command=\(String(describing: command), privacy: .public)"
            )
            return false
        }

        AppLogger.interaction.info(
            "overlay key handled command=\(String(describing: command), privacy: .public)"
        )
        _ = overlaySessionController.handleKeyboardCommand(command)
        return true
    }

    /// overlay/gaze activation용 Carbon hotkey들을 등록한다.
    private func registerGlobalHotKeys() -> [GlobalHotKeyRegistrationStatus] {
        let controllers = GlobalHotKeyDefinition.overlayActivationDefinitions.map { definition in
            GlobalHotKeyController(definition: definition) { [weak self] in
                self?.showOverlay()
            }
        }
        globalHotKeyControllers = controllers

        let statuses = globalHotKeyControllers.map { controller in
            GlobalHotKeyRegistrationStatus(
                definition: controller.definition,
                osStatus: controller.register()
            )
        }
        AppLogger.overlay.info("global hotkey registration statuses=\(GlobalHotKeyRegistrationGuidance(statuses: statuses).logSummary, privacy: .public)")
        return statuses
    }

    /// 고정키 입력을 표준 윈도우 컨트롤 동작으로 해석해 실행한다.
    ///
    /// overlay activation과 겹치지 않는 입력만 처리하며, 매칭이 없으면 무시한다.
    private func handleWindowControlShortcut(_ input: OverlayActivationShortcutInput) {
        guard let result = windowControlDispatcher.handle(input) else {
            return
        }

        AppLogger.overlay.info(
            "window control action result=\(result.logCode, privacy: .public)"
        )
    }

    /// overlay activation shortcut monitor를 제거한다.
    private func removeOverlayActivationShortcut() {
        globalHotKeyControllers.forEach { controller in
            controller.unregister()
        }
        globalHotKeyControllers = []

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

        guard presentAccessibilityPermissionAlert() else {
            return
        }

        permissionManager.requestAccessibilityPermission()
        permissionManager.openAccessibilitySettings()
    }

    /// 권한 설정으로 보내기 전에 무엇이 미완료인지 먼저 설명한다.
    private func presentAccessibilityPermissionAlert() -> Bool {
        NSApp.activate(ignoringOtherApps: true)

        let guidance = AccessibilityPermissionGuidance()
        let alert = NSAlert()
        alert.messageText = guidance.title
        alert.informativeText = guidance.message
        alert.addButton(withTitle: guidance.actionButtonTitle)
        alert.addButton(withTitle: guidance.cancelButtonTitle)

        return alert.runModal() == .alertFirstButtonReturn
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
            return TargetResolver(frontmostApplicationProvider: frontmostApplicationProvider)
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

    /// no-candidate 같은 평가 실패의 민감정보 없는 scan 집계만 stdout에 출력한다.
    private func printOverlayFailureDetailsIfNeeded(_ failure: OverlaySessionStartFailure) {
        guard launchOptions.showsOverlayOnLaunch else {
            return
        }

        OverlayLaunchReporter.failureDetails(failure).forEach { message in
            print(message)
            fflush(stdout)
        }
    }

    /// 런치 옵션 기반 평가에서 특정 overlay label을 keyboard 입력 없이 confirm한다.
    private func clickOverlayLabelIfRequested() {
        guard let label = launchOptions.clickOverlayLabel else {
            return
        }

        _ = overlaySessionController.clickLabel(label)
    }

    /// 런치 옵션 기반 평가에서 query overlay 입력과 선택 확인을 재현한다.
    private func performQueryIfRequested() {
        guard let queryText = launchOptions.queryText else {
            return
        }

        if let queryScopePin = launchOptions.queryScopePin {
            _ = overlaySessionController.handleKeyboardCommand(.pinScope(queryScopePin))
        }

        _ = overlaySessionController.handleKeyboardCommand(.appendQuery(queryText))
        printQueryResultIfNeeded()

        if launchOptions.performQueryConfirm {
            _ = overlaySessionController.handleKeyboardCommand(.dryRunConfirm)
        }
    }

    /// 런치 옵션 기반 query 평가 결과를 stdout에 출력한다.
    private func printQueryResultIfNeeded() {
        guard let session = overlaySessionController.activeSession else {
            print(OverlayLaunchReporter.queryResult(
                scope: launchOptions.queryScopePin ?? .elements,
                matchCount: 0,
                matchIndex: 0,
                focusedDisplayName: nil,
                success: false
            ))
            fflush(stdout)
            return
        }

        let scope = session.queryInput.pinnedScope ?? session.queryInput.lastScope
        let summary = querySummary(for: scope, session: session)
        print(OverlayLaunchReporter.queryResult(
            scope: scope,
            matchCount: summary.matchCount,
            matchIndex: summary.matchIndex,
            focusedDisplayName: summary.focusedDisplayName,
            success: summary.matchCount > 0
        ))
        fflush(stdout)
    }

    /// 현재 query scope별 match summary를 만든다.
    private func querySummary(
        for scope: QueryScope,
        session: OverlaySessionState
    ) -> (matchCount: Int, matchIndex: Int, focusedDisplayName: String?) {
        switch scope {
        case .elements:
            let match = session.elementMatches.indices.contains(session.elementMatchIndex)
                ? session.elementMatches[session.elementMatchIndex]
                : nil
            return (session.elementMatches.count, match == nil ? 0 : session.elementMatchIndex + 1, match?.displayName)
        case .windows:
            let match = session.windowMatches.indices.contains(session.windowMatchIndex)
                ? session.windowMatches[session.windowMatchIndex]
                : nil
            return (session.windowMatches.count, match == nil ? 0 : session.windowMatchIndex + 1, match?.displayLine)
        case .labels:
            let label = session.snapshot.layout.labels.first { $0.id == session.focusEngine.focusedItemID }
            return (label == nil ? 0 : 1, label == nil ? 0 : 1, label?.text)
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

    /// 로컬 진단 옵션에서 Carbon hotkey 등록 결과를 stdout에 출력한다.
    private func printHotKeyRegistrationIfNeeded(_ statuses: [GlobalHotKeyRegistrationStatus]) {
        guard launchOptions.printsHotKeyRegistration else {
            return
        }

        print("GAZEROW_HOTKEY_REGISTRATION \(GlobalHotKeyRegistrationGuidance(statuses: statuses).probeSummary)")
        fflush(stdout)

        if launchOptions.isHotKeyRegistrationProbeOnly {
            NSApp.terminate(nil)
        }
    }

    /// Carbon hotkey 등록 실패가 있을 때 충돌 가능성과 대체 단축키를 안내한다.
    private func presentHotKeyRegistrationGuidanceIfNeeded(_ statuses: [GlobalHotKeyRegistrationStatus]) {
        guard !launchOptions.isHotKeyRegistrationProbeOnly,
              let message = GlobalHotKeyRegistrationGuidance(statuses: statuses).failureMessage else {
            return
        }

        AppLogger.overlay.error("global hotkey registration guidance=\(message, privacy: .public)")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "GazeRow shortcut registration failed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// overlay 시작 실패가 조용히 묻히지 않도록 사용자가 해야 할 다음 행동을 설명한다.
    private func presentOverlayStartFailureGuidanceIfNeeded(for failure: OverlaySessionStartFailure) {
        guard !launchOptions.showsOverlayOnLaunch,
              !failure.requiresAccessibilityPermission else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        let guidance = OverlayStartFailureGuidance(failure: failure)
        let alert = NSAlert()
        alert.messageText = guidance.title
        alert.informativeText = guidance.message
        alert.addButton(withTitle: guidance.actionButtonTitle)
        alert.runModal()
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
