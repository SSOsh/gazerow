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
        let setupReadinessTitle: String
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

        /// 각 scope가 담당하는 역할을 한 줄로 설명한다.
        ///
        /// labels·elements는 화면 위 대상을 다루고(공간), windows는 이름으로 창을
        /// 검색·전환한다(의미). 사용자가 지금 어떤 scope로 무엇을 하는지 명확히 한다.
        func queryScopeRole(_ scope: QueryScope) -> String {
            switch scope {
            case .labels:
                return language == .korean ? "라벨을 겨냥해 클릭" : "Aim a label to click"
            case .elements:
                return language == .korean ? "요소를 이름으로 검색" : "Search elements by name"
            case .windows:
                return language == .korean ? "창을 이름으로 검색·전환" : "Search windows to switch"
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

        /// elements scope에서 gaze로 element를 겨냥 중일 때의 요약 문구.
        /// 검색 매칭 요약과 달리 개수·인덱스 없이 겨냥 대상 이름만 보인다.
        func gazeTargetSummary(displayName: String) -> String {
            language == .korean ? "겨냥 · \(displayName)" : "Aiming · \(displayName)"
        }

        func queryKeyHint(for scope: QueryScope, enterActionHint: String) -> String {
            switch scope {
            case .labels:
                return language == .korean
                    ? "/ 요소 · ; 창 · Enter \(enterActionHint) · Esc 닫기"
                    : "/ elements · ; windows · Enter \(enterActionHint) · Esc close"
            case .elements:
                return language == .korean
                    ? "Tab 다음 · / 요소 · ; 창 · Enter \(enterActionHint) · Esc 닫기"
                    : "Tab next · / elements · ; windows · Enter \(enterActionHint) · Esc close"
            case .windows:
                return language == .korean
                    ? "Tab 다음 · ; 창 · Enter \(enterActionHint) · Esc 닫기"
                    : "Tab next · ; windows · Enter \(enterActionHint) · Esc close"
            }
        }

        // MARK: - Overlay transient status (SSOT)

        /// overlay 준비 상태 문구. `readyBadge`를 재사용한다.
        var overlayReadyText: String {
            readyBadge
        }

        /// 입력 버퍼를 비웠을 때의 문구.
        var overlayInputClearedText: String {
            language == .korean ? "입력을 지웠습니다" : "Input cleared"
        }

        /// 라벨 focus 성공 문구.
        var overlayFocusedText: String {
            language == .korean ? "포커스됨" : "Focused"
        }

        /// 라벨 scope로 전환했을 때의 문구. `queryScopeLabels`를 재사용한다.
        var overlayLabelsSelectedText: String {
            queryScopeLabels
        }

        /// 클릭 성공 문구.
        var overlayClickedText: String {
            language == .korean ? "클릭함" : "Clicked"
        }

        /// 창을 찾지 못했을 때의 문구.
        var overlayWindowNotFoundText: String {
            language == .korean ? "창을 찾을 수 없음" : "Window not found"
        }

        /// 창 활성화 실패 문구.
        var overlayWindowActivationFailedText: String {
            language == .korean ? "창 활성화 실패" : "Window activation failed"
        }

        /// 다시 스캔 실패 문구.
        var overlayRescanFailedText: String {
            language == .korean ? "다시 스캔 실패" : "Rescan failed"
        }

        /// 클릭 성공(결과) 문구.
        var clickSucceededText: String {
            language == .korean ? "클릭 성공" : "Click succeeded"
        }

        func overlayTypingText(_ buffer: String) -> String {
            language == .korean ? "입력 중 \(buffer)" : "Typing \(buffer)"
        }

        func overlayNoLabelText(_ label: String) -> String {
            language == .korean ? "라벨 \(label) 없음" : "No label \(label)"
        }

        func overlayPinnedText(_ scope: QueryScope) -> String {
            language == .korean
                ? "\(queryScopeTitle(scope)) 고정"
                : "Pinned \(scope.rawValue)"
        }

        func overlayWindowActivatedText(appName: String) -> String {
            language == .korean ? "\(appName) 활성화됨" : "\(appName) activated"
        }

        // MARK: - Click risk / failure text

        /// click 위험 등급별 동작 설명.
        func riskActionText(_ risk: ClickRiskClass) -> String {
            switch risk {
            case .safeNavigation:
                language == .korean ? "안전한 동작" : "safe action"
            case .stateChange:
                language == .korean ? "상태 변경" : "state change"
            case .destructive:
                language == .korean ? "파괴적 동작" : "destructive action"
            case .externalEffect:
                language == .korean ? "외부 영향 동작" : "external action"
            case .unknownRisk:
                language == .korean ? "알 수 없는 동작" : "unknown action"
            }
        }

        /// 위험 click의 second confirm 안내 문구.
        func overlaySecondConfirmText(_ risk: ClickRiskClass) -> String {
            language == .korean
                ? "\(riskActionText(risk))을(를) 실행하려면 Return을 다시 누르세요"
                : "Press Return again for \(riskActionText(risk))"
        }

        /// click 결과(성공/실패)를 문구로 변환한다.
        func clickResultText(
            _ result: Result<ClickExecutionSuccess, OverlaySessionClickFailure>
        ) -> String {
            switch result {
            case .success:
                clickSucceededText
            case .failure(let failure):
                clickFailureText(failure)
            }
        }

        /// overlay session click 실패 문구.
        func clickFailureText(_ failure: OverlaySessionClickFailure) -> String {
            switch failure {
            case .scanFailed:
                language == .korean ? "클릭 실패: 대상이 변경됨" : "Click failed: target changed"
            case .missingFocusedTarget:
                language == .korean
                    ? "클릭 실패: 포커스된 대상이 없습니다. 라벨을 입력하거나 먼저 Tab을 누르세요."
                    : "Click failed: no focused target. Type a label or press Tab first."
            case .selectedTargetUnavailable:
                language == .korean
                    ? "선택한 요소가 더 이상 없습니다. 라벨을 갱신했습니다."
                    : "The selected element is no longer available. Labels were refreshed."
            case .selectedTargetChanged:
                language == .korean
                    ? "화면이 변경되어 라벨을 갱신했습니다. 다시 선택하세요."
                    : "The screen changed, so labels were refreshed. Select again."
            case .selectedTargetAmbiguous:
                language == .korean
                    ? "대상을 확실히 구분할 수 없어 클릭하지 않았습니다."
                    : "The target could not be identified safely, so no click was performed."
            case .executionFailed(let executionFailure):
                clickExecutionFailureText(executionFailure)
            }
        }

        /// click 실행 실패 문구.
        func clickExecutionFailureText(_ failure: ClickExecutionFailure) -> String {
            switch failure {
            case .missingPressAction:
                language == .korean
                    ? "클릭 실패: 지원되는 동작이 없습니다. 다른 라벨을 선택하세요."
                    : "Click failed: no supported action. Try another label."
            case .secondConfirmRequired(let riskClass):
                overlaySecondConfirmText(riskClass)
            case .axPressFailed:
                language == .korean ? "클릭 실패: 접근성 action 실패" : "Click failed: accessibility action failed"
            case .coordinateFallbackDisabled:
                language == .korean ? "클릭 실패: 좌표 fallback 꺼짐" : "Click failed: coordinate fallback is off"
            case .coordinateFallbackFailed:
                language == .korean ? "클릭 실패: 좌표 fallback 실패" : "Click failed: coordinate fallback failed"
            }
        }

        func commandBarModeTitle(for scope: QueryScope) -> String {
            switch scope {
            case .labels:
                language == .korean ? "라벨" : "Labels"
            case .elements:
                language == .korean ? "요소 검색" : "Element Search"
            case .windows:
                language == .korean ? "창 전환" : "Window Switcher"
            }
        }

        func commandBarIdleSummary(for scope: QueryScope) -> String {
            switch scope {
            case .labels:
                language == .korean ? "라벨 키를 입력하세요" : "Type a label key"
            case .elements:
                language == .korean ? "검색어를 입력하세요" : "Type to search elements"
            case .windows:
                language == .korean ? "앱 또는 창 이름을 입력하세요" : "Type an app or window name"
            }
        }

        func commandBarNoMatchSummary(for scope: QueryScope) -> String {
            switch scope {
            case .labels:
                language == .korean ? "일치하는 라벨 없음" : "No matching label"
            case .elements:
                language == .korean ? "검색 결과 없음" : "No element matches"
            case .windows:
                language == .korean ? "일치하는 창 없음" : "No window matches"
            }
        }

        func commandBarTypingSummary(_ buffer: String) -> String {
            language == .korean ? "\(buffer) 입력 중" : "Typing \(buffer)"
        }

        func commandBarModeHelper(for scope: QueryScope) -> String {
            switch scope {
            case .labels:
                commandBarLabelHelper
            case .elements:
                language == .korean ? "/ 요소 검색 모드" : "/ Element Search mode"
            case .windows:
                language == .korean ? "; 창 전환 모드" : "; Window Switcher mode"
            }
        }

        var commandBarLabelHelper: String {
            language == .korean
                ? "라벨 입력 후 Return으로 클릭"
                : "Type a label, then press Return to click"
        }

        var commandBarRiskTitle: String {
            language == .korean ? "위험 동작입니다" : "Risky action"
        }

        func commandBarAction(_ action: OverlayCommandBarAction) -> String {
            switch action {
            case .select:
                language == .korean ? "선택" : "Select"
            case .searchElements:
                language == .korean ? "요소 검색" : "Search elements"
            case .switchWindows:
                language == .korean ? "창 전환" : "Switch windows"
            case .close:
                language == .korean ? "닫기" : "Close"
            case .click:
                language == .korean ? "클릭" : "Click"
            case .next:
                language == .korean ? "다음" : "Next"
            case .previous:
                language == .korean ? "이전" : "Previous"
            case .clear:
                language == .korean ? "지우기" : "Clear"
            case .typeToSearch:
                language == .korean ? "검색" : "Search"
            case .confirmAgain:
                language == .korean ? "다시 확인" : "Confirm again"
            case .cancel:
                language == .korean ? "취소" : "Cancel"
            case .retry:
                language == .korean ? "다시 시도" : "Retry"
            }
        }

        var replayTutorialButton: String {
            language == .korean ? "튜토리얼 다시 보기" : "Replay tutorial"
        }

        var tutorialStartButton: String {
            language == .korean ? "시작하기" : "Start"
        }

        var tutorialBackButton: String {
            language == .korean ? "뒤로" : "Back"
        }

        var tutorialSkipButton: String {
            language == .korean ? "건너뛰기" : "Skip"
        }

        var tutorialFinishButton: String {
            language == .korean ? "완료" : "Finish"
        }

        var tutorialExitTitle: String {
            language == .korean ? "튜토리얼을 닫을까요?" : "Exit tutorial?"
        }

        var tutorialExitMessage: String {
            language == .korean
                ? "튜토리얼을 닫아도 언제든 설정에서 다시 볼 수 있습니다."
                : "You can replay this tutorial from Settings at any time."
        }

        var tutorialExitButton: String {
            language == .korean ? "닫기" : "Exit"
        }

        func tutorialTitle(for step: TutorialStep) -> String {
            switch step {
            case .introduction:
                return language == .korean ? "gazerow 시작하기" : "Getting started with gazerow"
            case .labelPractice:
                return language == .korean ? "라벨로 대상 선택" : "Select a target by label"
            case .modePractice:
                return language == .korean ? "검색과 창 전환" : "Search and switch windows"
            case .finish:
                return language == .korean ? "준비됐습니다" : "You are ready"
            }
        }

        func tutorialDescription(for step: TutorialStep) -> String {
            switch step {
            case .introduction:
                return language == .korean
                    ? "이 연습은 gazerow 안에서만 동작하며 다른 앱을 클릭하거나 전환하지 않습니다."
                    : "This practice stays inside gazerow. It never clicks or switches another app."
            case .labelPractice:
                return language == .korean
                    ? "F 라벨을 입력하고 Return으로 모의 선택을 확인하세요."
                    : "Type the F label, then press Return to confirm the simulated selection."
            case .modePractice:
                return language == .korean
                    ? "/로 요소 검색, ;로 창 전환을 각각 한 번 실행하세요."
                    : "Press / for element search and ; for window switching once each."
            case .finish:
                return language == .korean
                    ? "실제 overlay에서도 같은 키를 사용할 수 있습니다."
                    : "Use the same keys in the live overlay."
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

        func setupReadinessHeadline(for state: SettingsReadinessSummary.State) -> String {
            switch state {
            case .permissionRequired:
                return language == .korean ? "손쉬운 사용 권한이 필요합니다" : "Accessibility permission required"
            case .sessionDisabled:
                return language == .korean ? "세션이 비활성화되어 있습니다" : "Session is disabled"
            case .ready:
                return language == .korean ? "Overlay를 사용할 준비가 됐습니다" : "Overlay is ready"
            }
        }

        func setupReadinessDetail(for state: SettingsReadinessSummary.State) -> String {
            switch state {
            case .permissionRequired:
                return language == .korean
                    ? "시스템 설정에서 gazerow를 허용한 뒤 다시 확인을 누르세요."
                    : "Allow gazerow in System Settings, then press Recheck."
            case .sessionDisabled:
                return language == .korean
                    ? "세션을 활성화하면 단축키로 overlay를 다시 열 수 있습니다."
                    : "Enable the session to open the overlay with the shortcut again."
            case .ready:
                return language == .korean
                    ? "\(OverlayActivationShortcut.activationDisplayName)로 overlay를 열고 라벨을 입력해 focus를 이동하세요."
                    : "Press \(OverlayActivationShortcut.activationDisplayName), then type a label to move focus."
            }
        }

        func setupReadinessBadge(for state: SettingsReadinessSummary.State) -> String {
            switch state {
            case .permissionRequired:
                return needsPermissionBadge
            case .sessionDisabled:
                return disabledBadge
            case .ready:
                return readyBadge
            }
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
    gazerow is a productivity utility for keyboard-centric users. It is not an \
    accessibility or assistive-technology product, and is not intended for \
    medical or safety-critical use.
    """

    /// 검증된 overlay click과 일반 좌표 fallback 정책을 알리는 문구.
    static let fallbackDisabledNotice = """
    Confirmed overlay clicks use the current verified target's center coordinate. \
    Coordinate fallback outside that verified path is disabled by default.
    """

    /// 첫 실행 안내에서 소개하는 setup 단계.
    static let setupSteps: [String] = [
        "Grant Accessibility permission in System Settings.",
        "Return to gazerow and press Recheck to confirm the status.",
        "Open the overlay with the shortcut, focus an element, and confirm with a key."
    ]

    // MARK: - Known Limitations

    /// 사용자에게 노출하는 알려진 제한사항.
    static let knownLimitations: [String] = [
        "Only the frontmost app's focused window is scanned.",
        "Some apps expose an incomplete accessibility tree, so candidates may be missing.",
        "Confirmed overlay clicks use the current verified target's center coordinate. If the selected target cannot be uniquely matched after a rescan, no click is sent and labels refresh.",
        "Other click paths rely on accessibility actions such as AXPress, AXConfirm, AXOpen, and AXShowDefaultUI; elements without a supported action may not be actionable.",
        "Coordinate-click fallback outside the verified overlay path is off by default.",
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
        "Type the label letters to focus an element. Keyboard layout is handled automatically.",
        "Press Return to confirm and click the focused element.",
        "Press / to search elements or ; to switch windows.",
        "Use Tab or Shift+Tab, and the arrow keys, to move focus between candidates.",
        "Press Delete to clear the letters you have typed so far.",
        "Press Esc to close the overlay without clicking."
    ]

    // MARK: - Support

    /// 메뉴바 후원 항목 제목.
    static let supportDonationMenuTitle = "Support gazerow"

    /// 후원 안내 alert 제목.
    static let supportDonationTitle = "Support gazerow"

    /// 후원 안내 alert 본문.
    static let supportDonationMessage = """
    gazerow가 작업 흐름에 도움이 됐다면 커피값 후원으로 개발을 응원해 주세요.

    계좌번호는 추후 추가 예정입니다.
    """

    // MARK: - Shortcuts

    /// window control 고정키 안내 문구.
    static let windowControlShortcutsNotice = """
    Window shortcuts act on the frontmost window's standard title-bar buttons \
    (close, minimize, zoom) using accessibility actions. They work only while \
    gazerow has Accessibility permission.
    """

    // MARK: - Diagnostics

    /// interaction 로그 저장 opt-in 토글 안내 문구.
    static let interactionLoggingNotice = """
    When enabled, gazerow stores minimal interaction events (focus/click) locally. \
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
        setupReadinessTitle: "Setup Status",
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
        setupReadinessTitle: "설정 상태",
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
            "gazerow로 돌아와 다시 확인을 눌러 상태를 확인합니다.",
            "단축키로 overlay를 열고, 요소에 focus를 맞춘 뒤 키로 확인합니다."
        ],
        knownLimitations: [
            "맨 앞 앱의 focused window만 스캔합니다.",
            "일부 앱은 접근성 트리를 불완전하게 노출해 후보가 빠질 수 있습니다.",
            "확정된 overlay 클릭은 다시 검증한 현재 대상의 중앙 좌표를 클릭합니다. 재스캔 후 선택 대상을 하나로 확인할 수 없으면 클릭하지 않고 라벨을 갱신합니다.",
            "그 밖의 클릭 경로는 AXPress, AXConfirm, AXOpen, AXShowDefaultUI 같은 접근성 action에 의존합니다. 지원 action이 없는 요소는 실행되지 않을 수 있습니다.",
            "검증된 overlay 경로 밖의 좌표 기반 클릭 fallback은 기본적으로 꺼져 있습니다.",
            "모든 클릭은 키보드 확인이 필요합니다. 자동 클릭은 없습니다.",
            "Gaze/camera 기능은 실험 기능이며 기본적으로 꺼져 있습니다.",
            "Discord는 확장된 AX child scanning으로 앱 UI 후보를 노출하지만, 대표 클릭 task 검증은 아직 필요합니다."
        ],
        overlayUsageSteps: [
            "Show overlay 단축키로 overlay를 엽니다. 실행 가능한 요소마다 문자 라벨이 붙습니다.",
            "라벨 문자를 입력해 요소에 focus를 맞춥니다. 키보드 레이아웃은 자동으로 처리됩니다.",
            "Return을 눌러 focused element를 확인하고 클릭합니다.",
            "/를 누르면 요소를 검색하고 ;를 누르면 창을 전환합니다.",
            "Tab, Shift+Tab, 방향키로 후보 사이를 이동합니다.",
            "Delete를 누르면 지금까지 입력한 라벨 문자를 지웁니다.",
            "Esc를 누르면 클릭하지 않고 overlay를 닫습니다."
        ],
        nonMedicalDisclaimer: """
        gazerow는 키보드 중심 사용자를 위한 생산성 유틸리티입니다. 접근성/보조공학 제품이나 의료·안전 필수 용도로 설계된 제품이 아닙니다.
        """,
        fallbackDisabledNotice: """
        확정된 overlay 클릭은 현재 검증된 대상 중앙 좌표를 클릭합니다. 그 밖의 좌표 기반 클릭 fallback(CGEventPost)은 오클릭 위험을 줄이기 위해 기본적으로 꺼져 있습니다.
        """,
        windowControlShortcutsNotice: """
        창 단축키는 맨 앞 창의 표준 title-bar 버튼(닫기, 최소화, 확대/축소)에 접근성 action을 보냅니다. gazerow에 Accessibility 권한이 있을 때만 동작합니다.
        """,
        interactionLoggingNotice: """
        켜면 gazerow가 최소한의 interaction event(focus/click)를 로컬에 저장합니다. 창 제목은 세션별 hash로만 저장하며 원문 제목과 텍스트 값은 저장하지 않습니다.
        """,
        debugExportNotice: """
        Debug Export는 문제 해결을 위한 현재 진단 snapshot을 일반 텍스트로 저장합니다. 원본 창 제목이나 텍스트 값은 포함하지 않습니다.
        """,
        supportDonationMenuTitle: "gazerow 후원",
        supportDonationTitle: "gazerow 후원",
        supportDonationMessage: supportDonationMessage,
        queryScopeWindows: "창",
        queryScopeElements: "요소",
        queryScopeLabels: "라벨",
        queryNoMatch: "매칭 없음",
        enterActionClick: "클릭",
        enterActionSwitchWindow: "창 전환"
    )
}
