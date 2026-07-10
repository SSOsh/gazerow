import Foundation

/// 첫 실행 안내, Known Limitations, 앱 지원 범위 등 사용자 노출 정적 콘텐츠.
///
/// TICKET-009 범위. UI 문구를 한곳에서 관리해 Onboarding/Settings/README가
/// 같은 내용을 참조하게 한다.
///
/// @author suho.do
/// @since 2026-07-02
enum AppContent {

    /// 앱 지원 등급.
    enum SupportTier {
        /// MVP 기준 앱으로 task 검증 대상.
        case supported
        /// 동작하지만 후보/클릭에 제약이 있는 앱.
        case limited
        /// 평가했지만 현재 후보 수집 또는 대표 task 수행이 불가능한 앱.
        case unsupported
        /// 아직 검증하지 않은 앱.
        case unverified
    }

    /// 앱 지원성 표시 항목.
    struct AppSupport: Identifiable {
        let id = UUID()
        let name: String
        let tier: SupportTier
    }

    /// 사용자 노출 콘텐츠의 언어별 묶음.
    ///
    /// @author suho.do
    /// @since 2026-07-03
    struct Localized {
        let language: AppLanguage
        let languageLabel: String
        let permissionsTitle: String
        let accessibilityLabel: String
        let requestPermissionButton: String
        let openSystemSettingsButton: String
        let recheckButton: String
        let cameraGazeFocusLabel: String
        let enableExperimentalGazeFocusLabel: String
        let requestCameraButton: String
        let openCameraSettingsButton: String
        let recheckCameraButton: String
        let inputMonitoringLabel: String
        let inputMonitoringDeferred: String
        let gazeCalibrationLabel: String
        let calibrateButton: String
        let calibrationHelp: String
        let sessionTitle: String
        let disableButton: String
        let enableButton: String
        let sessionKillSwitchNotice: String
        let shortcutsTitle: String
        let showOverlayLabel: String
        let overlayAppearanceTitle: String
        let labelOpacityLabel: String
        let labelOpacityNotice: String
        let overlayUsageTitle: String
        let privacyTitle: String
        let diagnosticsTitle: String
        let storeInteractionLogsLabel: String
        let deleteLogsButton: String
        let createDebugExportButton: String
        let deleteExportButton: String
        let knownLimitationsButton: String
        let knownLimitationsTitle: String
        let clickSafetyTitle: String
        let appSupportTitle: String
        let doneButton: String
        let welcomeTitle: String
        let appSubtitle: String
        let setupTitle: String
        let getStartedButton: String
        let grantedBadge: String
        let notGrantedBadge: String
        let readyBadge: String
        let offBadge: String
        let needsPermissionBadge: String
        let deniedBadge: String
        let restrictedBadge: String
        let activeBadge: String
        let disabledBadge: String
        let supportedBadge: String
        let limitedBadge: String
        let unsupportedBadge: String
        let unverifiedBadge: String
        let setupSteps: [String]
        let knownLimitations: [String]
        let overlayUsageSteps: [String]
        let nonMedicalDisclaimer: String
        let fallbackDisabledNotice: String
        let windowControlShortcutsNotice: String
        let interactionLoggingNotice: String
        let debugExportNotice: String
        let supportDonationMenuTitle: String
        let supportDonationTitle: String
        let supportDonationMessage: String
        let queryScopeWindows: String
        let queryScopeElements: String
        let queryScopeLabels: String
        let queryNoMatch: String
        let enterActionClick: String
        let enterActionSwitchWindow: String

        func windowControlLabel(for action: WindowControlAction) -> String {
            switch action {
            case .close:
                language == .korean ? "창 닫기" : action.displayName
            case .minimize:
                language == .korean ? "창 최소화" : action.displayName
            case .zoom:
                language == .korean ? "창 확대/축소" : action.displayName
            }
        }

        func queryScopeTitle(_ scope: QueryScope) -> String {
            switch scope {
            case .windows:
                queryScopeWindows
            case .elements:
                queryScopeElements
            case .labels:
                queryScopeLabels
            }
        }

        func queryMatchSummary(count: Int, index: Int, displayName: String) -> String {
            let safeCount = max(0, count)
            let safeIndex = min(max(1, index), max(1, safeCount))
            guard !displayName.isEmpty else {
                return language == .korean
                    ? "매칭 \(safeCount) · \(safeIndex)/\(safeCount)"
                    : "Matches \(safeCount) · \(safeIndex)/\(safeCount)"
            }

            return language == .korean
                ? "매칭 \(safeCount) · \(safeIndex)/\(safeCount) · \(displayName)"
                : "Matches \(safeCount) · \(safeIndex)/\(safeCount) · \(displayName)"
        }

        func queryKeyHint(for scope: QueryScope, enterActionHint: String) -> String {
            switch scope {
            case .labels:
                return language == .korean
                    ? "Enter: \(enterActionHint) / Esc"
                    : "Enter: \(enterActionHint) / Esc"
            case .elements, .windows:
                return language == .korean
                    ? "Tab / Enter: \(enterActionHint) / Esc"
                    : "Tab / Enter: \(enterActionHint) / Esc"
            }
        }

        func calibrationStatusText(_ status: GazeCalibrationStatus) -> String {
            if !status.isOptInEnabled {
                return language == .korean ? "먼저 gaze focus를 켜세요" : "Enable gaze focus first"
            }
            if !status.isCameraAuthorized {
                return language == .korean ? "Camera 권한 필요" : "Camera permission required"
            }
            if status.isCalibrated {
                return language == .korean ? "캘리브레이션 완료 (\(status.sampleCount)점)" : "Calibrated (\(status.sampleCount) points)"
            }
            return language == .korean ? "캘리브레이션 안 됨" : "Not calibrated"
        }

        func diagnosticsMessage(_ message: String?) -> String? {
            guard language == .korean, let message else {
                return message
            }

            switch message {
            case "Interaction logs deleted.":
                return "Interaction 로그를 삭제했습니다."
            case "Debug export created.":
                return "Debug export를 생성했습니다."
            case "Debug export failed.":
                return "Debug export 생성에 실패했습니다."
            case "Debug export deleted.":
                return "Debug export를 삭제했습니다."
            default:
                return message
            }
        }
    }

    // MARK: - Disclaimers

    /// 접근성/의료 보조 제품이 아님을 밝히는 문구.
    static let nonMedicalDisclaimer = """
    GazeRow is a productivity utility for keyboard-centric users. It is not an \
    accessibility or assistive-technology product, and is not intended for \
    medical or safety-critical use.
    """

    /// 좌표 클릭 fallback이 기본 비활성임을 알리는 문구.
    static let fallbackDisabledNotice = """
    Coordinate-based click fallback (CGEventPost) is disabled by default to \
    reduce the risk of mis-clicks. Clicks use supported accessibility actions.
    """

    /// 첫 실행 안내에서 소개하는 setup 단계.
    static let setupSteps: [String] = [
        "Grant Accessibility permission in System Settings.",
        "Return to GazeRow and press Recheck to confirm the status.",
        "Open the overlay with the shortcut, focus an element, and confirm with a key."
    ]

    // MARK: - Known Limitations

    /// 사용자에게 노출하는 알려진 제한사항.
    static let knownLimitations: [String] = [
        "Only the frontmost app's focused window is scanned.",
        "Some apps expose an incomplete accessibility tree, so candidates may be missing.",
        "Clicks rely on accessibility actions such as AXPress, AXConfirm, AXOpen, and AXShowDefaultUI; elements without a supported action may not be actionable.",
        "Coordinate-click fallback is off by default and must be enabled in debug.",
        "All clicks require explicit keyboard confirmation; there is no auto-click.",
        "Gaze/camera features are Post-MVP and disabled in this build.",
        "Discord now exposes app UI candidates through expanded AX child scanning, but a representative click task still needs verification."
    ]

    // MARK: - Overlay Usage

    /// overlay를 띄운 뒤 실제로 조작하는 순서를 설명하는 단계.
    ///
    /// Onboarding/Settings가 같은 안내를 참조하도록 SSOT로 관리한다.
    static let overlayUsageSteps: [String] = [
        "Open the overlay with the Show overlay shortcut. Every actionable element gets a letter label.",
        "Type the label letters to focus an element. Korean keyboards work too — labels match the physical key position (e.g. ㄹ selects F).",
        "Press Return to confirm and click the focused element.",
        "Use Tab or Shift+Tab, and the arrow keys, to move focus between candidates.",
        "Press Delete to clear the letters you have typed so far.",
        "Press Esc to close the overlay without clicking."
    ]

    // MARK: - Support

    /// 메뉴바 후원 항목 제목.
    static let supportDonationMenuTitle = "Support GazeRow"

    /// 후원 안내 alert 제목.
    static let supportDonationTitle = "Support GazeRow"

    /// 후원 안내 alert 본문.
    static let supportDonationMessage = """
    GazeRow가 작업 흐름에 도움이 됐다면 커피값 후원으로 개발을 응원해 주세요.

    계좌번호는 추후 추가 예정입니다.
    """

    // MARK: - Shortcuts

    /// window control 고정키 안내 문구.
    static let windowControlShortcutsNotice = """
    Window shortcuts act on the frontmost window's standard title-bar buttons \
    (close, minimize, zoom) using accessibility actions. They work only while \
    GazeRow has Accessibility permission.
    """

    // MARK: - Diagnostics

    /// interaction 로그 저장 opt-in 토글 안내 문구.
    static let interactionLoggingNotice = """
    When enabled, GazeRow stores minimal interaction events (focus/click) locally. \
    Window titles are stored only as a per-session hash; raw titles and text values \
    are never written.
    """

    /// debug export 안내 문구.
    static let debugExportNotice = """
    Debug Export saves a plain-text snapshot of current diagnostics for \
    troubleshooting. It does not include raw window titles or text values.
    """

    // MARK: - App Support

    /// 지원/제한/미확인 앱 구분 목록.
    static let appSupport: [AppSupport] = [
        AppSupport(name: "Finder", tier: .supported),
        AppSupport(name: "Safari", tier: .supported),
        AppSupport(name: "Chrome", tier: .supported),
        AppSupport(name: "VS Code", tier: .supported),
        AppSupport(name: "System Settings", tier: .supported),
        AppSupport(name: "Slack", tier: .supported),
        AppSupport(name: "Notion", tier: .supported),
        AppSupport(name: "Discord", tier: .limited),
        AppSupport(name: "Obsidian", tier: .unverified)
    ]

    static func localized(for language: AppLanguage) -> Localized {
        switch language {
        case .english:
            english
        case .korean:
            korean
        }
    }

    private static let english = Localized(
        language: .english,
        languageLabel: "Language",
        permissionsTitle: "Permissions",
        accessibilityLabel: "Accessibility",
        requestPermissionButton: "Request Permission",
        openSystemSettingsButton: "Open System Settings",
        recheckButton: "Recheck",
        cameraGazeFocusLabel: "Camera gaze focus",
        enableExperimentalGazeFocusLabel: "Enable experimental gaze focus",
        requestCameraButton: "Request Camera",
        openCameraSettingsButton: "Open Camera Settings",
        recheckCameraButton: "Recheck Camera",
        inputMonitoringLabel: "Input Monitoring",
        inputMonitoringDeferred: "Not requested (deferred)",
        gazeCalibrationLabel: "Gaze calibration",
        calibrateButton: "Calibrate…",
        calibrationHelp: "Look at the highlighted dots to map your gaze to the screen. Activate with Control+Shift+Space.",
        sessionTitle: "Session",
        disableButton: "Disable",
        enableButton: "Enable",
        sessionKillSwitchNotice: "Kill switch stops overlay activation immediately.",
        shortcutsTitle: "Shortcuts",
        showOverlayLabel: "Show overlay",
        overlayAppearanceTitle: "Overlay Appearance",
        labelOpacityLabel: "Label opacity",
        labelOpacityNotice: "Lower the label opacity to see more of the content behind the overlay.",
        overlayUsageTitle: "Using the overlay",
        privacyTitle: "Privacy",
        diagnosticsTitle: "Diagnostics",
        storeInteractionLogsLabel: "Store interaction logs",
        deleteLogsButton: "Delete Logs",
        createDebugExportButton: "Create Debug Export",
        deleteExportButton: "Delete Export",
        knownLimitationsButton: "Known Limitations…",
        knownLimitationsTitle: "Known Limitations",
        clickSafetyTitle: "Click Safety",
        appSupportTitle: "App Support",
        doneButton: "Done",
        welcomeTitle: "Welcome to \(AppState.appName)",
        appSubtitle: "Local keyboard-click utility",
        setupTitle: "Setup",
        getStartedButton: "Get Started",
        grantedBadge: "Granted",
        notGrantedBadge: "Not granted",
        readyBadge: "Ready",
        offBadge: "Off",
        needsPermissionBadge: "Needs permission",
        deniedBadge: "Denied",
        restrictedBadge: "Restricted",
        activeBadge: "Active",
        disabledBadge: "Disabled",
        supportedBadge: "Supported",
        limitedBadge: "Limited",
        unsupportedBadge: "Unsupported",
        unverifiedBadge: "Unverified",
        setupSteps: setupSteps,
        knownLimitations: knownLimitations,
        overlayUsageSteps: overlayUsageSteps,
        nonMedicalDisclaimer: nonMedicalDisclaimer,
        fallbackDisabledNotice: fallbackDisabledNotice,
        windowControlShortcutsNotice: windowControlShortcutsNotice,
        interactionLoggingNotice: interactionLoggingNotice,
        debugExportNotice: debugExportNotice,
        supportDonationMenuTitle: supportDonationMenuTitle,
        supportDonationTitle: supportDonationTitle,
        supportDonationMessage: supportDonationMessage,
        queryScopeWindows: "Windows",
        queryScopeElements: "Elements",
        queryScopeLabels: "Labels",
        queryNoMatch: "No matches",
        enterActionClick: "click",
        enterActionSwitchWindow: "switch window"
    )

    private static let korean = Localized(
        language: .korean,
        languageLabel: "언어",
        permissionsTitle: "권한",
        accessibilityLabel: "손쉬운 사용",
        requestPermissionButton: "권한 요청",
        openSystemSettingsButton: "시스템 설정 열기",
        recheckButton: "다시 확인",
        cameraGazeFocusLabel: "카메라 gaze focus",
        enableExperimentalGazeFocusLabel: "실험적 gaze focus 사용",
        requestCameraButton: "카메라 권한 요청",
        openCameraSettingsButton: "카메라 설정 열기",
        recheckCameraButton: "카메라 다시 확인",
        inputMonitoringLabel: "입력 모니터링",
        inputMonitoringDeferred: "요청하지 않음 (보류)",
        gazeCalibrationLabel: "Gaze 캘리브레이션",
        calibrateButton: "캘리브레이션…",
        calibrationHelp: "강조된 점을 바라보며 시선과 화면 좌표를 매핑합니다. Control+Shift+Space로 활성화합니다.",
        sessionTitle: "세션",
        disableButton: "비활성화",
        enableButton: "활성화",
        sessionKillSwitchNotice: "Kill switch는 overlay 활성화를 즉시 중지합니다.",
        shortcutsTitle: "단축키",
        showOverlayLabel: "Overlay 표시",
        overlayAppearanceTitle: "Overlay 모양",
        labelOpacityLabel: "라벨 투명도",
        labelOpacityNotice: "라벨 투명도를 낮추면 overlay 뒤 콘텐츠가 더 잘 보입니다.",
        overlayUsageTitle: "Overlay 사용 방법",
        privacyTitle: "개인정보",
        diagnosticsTitle: "진단",
        storeInteractionLogsLabel: "Interaction 로그 저장",
        deleteLogsButton: "로그 삭제",
        createDebugExportButton: "Debug Export 생성",
        deleteExportButton: "Export 삭제",
        knownLimitationsButton: "알려진 제한사항…",
        knownLimitationsTitle: "알려진 제한사항",
        clickSafetyTitle: "클릭 안전 정책",
        appSupportTitle: "앱 지원 범위",
        doneButton: "완료",
        welcomeTitle: "\(AppState.appName)에 오신 것을 환영합니다",
        appSubtitle: "로컬 키보드 클릭 유틸리티",
        setupTitle: "설정",
        getStartedButton: "시작하기",
        grantedBadge: "허용됨",
        notGrantedBadge: "허용 안 됨",
        readyBadge: "준비됨",
        offBadge: "꺼짐",
        needsPermissionBadge: "권한 필요",
        deniedBadge: "거부됨",
        restrictedBadge: "제한됨",
        activeBadge: "활성",
        disabledBadge: "비활성",
        supportedBadge: "지원됨",
        limitedBadge: "제한적 지원",
        unsupportedBadge: "지원 안 됨",
        unverifiedBadge: "미확인",
        setupSteps: [
            "시스템 설정에서 손쉬운 사용 권한을 허용합니다.",
            "GazeRow로 돌아와 다시 확인을 눌러 상태를 확인합니다.",
            "단축키로 overlay를 열고, 요소에 focus를 맞춘 뒤 키로 확인합니다."
        ],
        knownLimitations: [
            "맨 앞 앱의 focused window만 스캔합니다.",
            "일부 앱은 접근성 트리를 불완전하게 노출해 후보가 빠질 수 있습니다.",
            "클릭은 AXPress, AXConfirm, AXOpen, AXShowDefaultUI 같은 접근성 action에 의존합니다. 지원 action이 없는 요소는 실행되지 않을 수 있습니다.",
            "좌표 기반 클릭 fallback은 기본적으로 꺼져 있으며, 명시 확인된 overlay 클릭 경로에서만 제한적으로 사용합니다.",
            "모든 클릭은 키보드 확인이 필요합니다. 자동 클릭은 없습니다.",
            "Gaze/camera 기능은 실험 기능이며 기본적으로 꺼져 있습니다.",
            "Discord는 확장된 AX child scanning으로 앱 UI 후보를 노출하지만, 대표 클릭 task 검증은 아직 필요합니다."
        ],
        overlayUsageSteps: [
            "Show overlay 단축키로 overlay를 엽니다. 실행 가능한 요소마다 문자 라벨이 붙습니다.",
            "라벨 문자를 입력해 요소에 focus를 맞춥니다. 한글 키보드도 동작하며 물리 키 위치로 매칭됩니다. 예: ㄹ은 F를 선택합니다.",
            "Return을 눌러 focused element를 확인하고 클릭합니다.",
            "Tab, Shift+Tab, 방향키로 후보 사이를 이동합니다.",
            "Delete를 누르면 지금까지 입력한 라벨 문자를 지웁니다.",
            "Esc를 누르면 클릭하지 않고 overlay를 닫습니다."
        ],
        nonMedicalDisclaimer: """
        GazeRow는 키보드 중심 사용자를 위한 생산성 유틸리티입니다. 접근성/보조공학 제품이나 의료·안전 필수 용도로 설계된 제품이 아닙니다.
        """,
        fallbackDisabledNotice: """
        오클릭 위험을 줄이기 위해 좌표 기반 클릭 fallback(CGEventPost)은 기본적으로 꺼져 있습니다. 일반 클릭은 지원되는 접근성 action을 사용합니다.
        """,
        windowControlShortcutsNotice: """
        창 단축키는 맨 앞 창의 표준 title-bar 버튼(닫기, 최소화, 확대/축소)에 접근성 action을 보냅니다. GazeRow에 Accessibility 권한이 있을 때만 동작합니다.
        """,
        interactionLoggingNotice: """
        켜면 GazeRow가 최소한의 interaction event(focus/click)를 로컬에 저장합니다. 창 제목은 세션별 hash로만 저장하며 원문 제목과 텍스트 값은 저장하지 않습니다.
        """,
        debugExportNotice: """
        Debug Export는 문제 해결을 위한 현재 진단 snapshot을 일반 텍스트로 저장합니다. 원본 창 제목이나 텍스트 값은 포함하지 않습니다.
        """,
        supportDonationMenuTitle: "GazeRow 후원",
        supportDonationTitle: "GazeRow 후원",
        supportDonationMessage: supportDonationMessage,
        queryScopeWindows: "창",
        queryScopeElements: "요소",
        queryScopeLabels: "라벨",
        queryNoMatch: "매칭 없음",
        enterActionClick: "클릭",
        enterActionSwitchWindow: "창 전환"
    )
}
