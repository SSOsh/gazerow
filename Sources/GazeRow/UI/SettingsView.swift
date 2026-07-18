import SwiftUI

/// Settings window 본문.
///
/// 앱 이름/버전/MVP 상태, Accessibility 권한 상태, 개인정보 안내를 표시한다.
/// 권한 상태는 창이 나타나거나 앱이 활성화될 때 자동으로 갱신하며,
/// Recheck 버튼으로 수동 갱신도 가능하다.
///
/// @author suho.do
/// @since 2026-07-02
struct SettingsView: View {

    /// Accessibility 권한 상태를 조회/요청하는 매니저.
    @State private var permissionManager = PermissionManager()

    /// Camera 권한 상태를 조회/요청하는 매니저.
    @State private var cameraPermissionManager = CameraPermissionManager()

    /// 브라우저 탭 개수 조회용 Automation 권한 상태를 조회/재확인하는 매니저.
    @State private var browserAutomationPermissionManager = BrowserAutomationPermissionManager()

    /// Camera gaze focus opt-in 저장소.
    @State private var cameraGazeSettings = CameraGazeSettings()

    /// kill switch 세션 상태(메뉴바와 공유).
    @State private var session = SessionController.shared

    /// 첫 실행 안내 시트 상태.
    @State private var onboarding = OnboardingState()

    /// Known Limitations 시트 표시 여부.
    @State private var showLimitations = false

    /// interaction 로그 저장소.
    @State private var logStore = InteractionLogStore()

    /// AX debug export 매니저.
    @State private var debugExport = DebugExportManager()

    /// debug 전용 기능 노출 정책.
    private let debugFeatureVisibility = DebugFeatureVisibility()

    /// interaction 저장 opt-in 토글 바인딩 상태.
    @State private var isInteractionLoggingEnabled = false

    /// camera gaze focus opt-in 토글 바인딩 상태.
    @State private var isCameraGazeEnabled = false

    /// gaze calibration sample 저장소.
    private let gazeCalibrationStore = GazeCalibrationStore()

    /// 저장된 calibration sample 수(표시/버튼 상태 판정용).
    @State private var gazeSampleCount = 0

    /// diagnostics 수동 액션 결과 표시 상태.
    @State private var diagnosticsFeedback = DiagnosticsActionFeedback()

    /// 앱 내부 표시 언어 저장소.
    @State private var languageSettings = AppLanguageSettings()

    /// 현재 Settings 표시 언어.
    @State private var selectedLanguage = AppLanguageSettings().selectedLanguage

    /// overlay 라벨 투명도 저장소.
    private let appearanceSettings = OverlayAppearanceSettings()

    /// 라벨 배경 투명도 슬라이더 바인딩 상태.
    @State private var labelBackgroundOpacity = OverlayAppearanceSettings().labelBackgroundOpacity

    var body: some View {
        ScrollView {
            settingsContent
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 440, height: 720)
        .onAppear {
            refreshPermission()
            onboarding.presentIfNeeded()
            isInteractionLoggingEnabled = logStore.isOptInEnabled
            isCameraGazeEnabled = cameraGazeSettings.isOptInEnabled
            selectedLanguage = languageSettings.selectedLanguage
            labelBackgroundOpacity = appearanceSettings.labelBackgroundOpacity
            refreshGazeSampleCount()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            refreshPermission()
            refreshGazeSampleCount()
        }
        .sheet(isPresented: $onboarding.isPresenting) {
            OnboardingView(onboarding: onboarding, language: selectedLanguage)
        }
        .sheet(isPresented: $showLimitations) {
            KnownLimitationsView(language: selectedLanguage)
        }
    }

    private var content: AppContent.Localized {
        AppContent.localized(for: selectedLanguage)
    }

    private var appText: AppState.LocalizedText {
        AppState.localized(for: selectedLanguage)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            languageSection

            Divider()

            readinessSummarySection

            Divider()

            statusSection

            Divider()

            permissionSection

            Divider()

            sessionSection

            Divider()

            shortcutsSection

            Divider()

            overlayAppearanceSection

            Divider()

            overlayUsageSection

            Divider()

            privacySection

            Divider()

            diagnosticsSection

            footer
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "cursorarrow.rays")
                .font(.system(size: 24))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppState.appName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(AppState.versionPlaceholder)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeledRow("MVP mode", appText.mvpMode)
            labeledRow("Gaze", appText.gazeStatus)
        }
    }

    /// 기본 overlay 사용 가능 여부와 다음 행동을 Settings 상단에 요약한다.
    private var readinessSummarySection: some View {
        let summary = settingsReadinessSummary

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(content.setupReadinessTitle)
                    .font(.headline)
                Spacer()
                readinessBadge(for: summary.state)
            }

            Text(content.setupReadinessHeadline(for: summary.state))
                .font(.callout)
                .fontWeight(.medium)

            Text(content.setupReadinessDetail(for: summary.state))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            readinessActions(for: summary.state)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    /// 현재 Settings 상태에서 계산한 기본 사용 가능 상태.
    private var settingsReadinessSummary: SettingsReadinessSummary {
        SettingsReadinessSummary(
            isAccessibilityGranted: permissionManager.accessibilityStatus == .granted,
            isSessionEnabled: session.isEnabled
        )
    }

    /// readiness 상태에 맞는 바로가기 액션.
    @ViewBuilder
    private func readinessActions(for state: SettingsReadinessSummary.State) -> some View {
        switch state {
        case .permissionRequired:
            actionButtons {
                Button(content.requestPermissionButton) {
                    requestAccessibilityPermission()
                }
                Button(content.openSystemSettingsButton) {
                    permissionManager.openAccessibilitySettings()
                }
                Button(content.recheckButton) {
                    refreshPermission()
                }
            }
        case .sessionDisabled:
            actionButtons {
                Button(content.enableButton) {
                    session.toggle()
                }
            }
        case .ready:
            actionButtons {
                Button(content.knownLimitationsButton) {
                    showLimitations = true
                }
                Button(content.recheckButton) {
                    refreshPermission()
                    refreshGazeSampleCount()
                }
            }
        }
    }

    /// 앱 내부 설명/설정 문구 언어를 선택하는 섹션.
    private var languageSection: some View {
        HStack {
            Text(content.languageLabel)
                .foregroundStyle(.secondary)
            Spacer()
            Picker(content.languageLabel, selection: $selectedLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .labelsHidden()
            .frame(width: 160)
            .onChange(of: selectedLanguage) { _, newValue in
                languageSettings.selectedLanguage = newValue
            }
        }
        .font(.callout)
    }

    /// Accessibility 권한 상태와 안내/이동 버튼을 표시하는 섹션.
    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.permissionsTitle)
                .font(.headline)

            HStack {
                Text(content.accessibilityLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                accessibilityBadge
            }
            .font(.callout)

            // 권한이 없을 때만 접근 범위/불가 사유를 먼저 설명한다 (PR-006).
            if !permissionManager.canActivateOverlay {
                Text(appText.accessibilityRationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actionButtons {
                if permissionManager.accessibilityStatus == .notGranted {
                    Button(content.requestPermissionButton) {
                        requestAccessibilityPermission()
                    }
                }
                Button(content.openSystemSettingsButton) {
                    permissionManager.openAccessibilitySettings()
                }
                Button(content.recheckButton) {
                    refreshPermission()
                }
            }

            Divider()

            cameraPermissionRows

            Divider()

            browserAutomationPermissionRows

            // Input Monitoring은 baseline 흐름에서 요청하지 않음을 명시한다.
            labeledRow(content.inputMonitoringLabel, content.inputMonitoringDeferred)
        }
    }

    /// Camera gaze focus opt-in과 권한 상태를 표시하는 행.
    private var cameraPermissionRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(content.cameraGazeFocusLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                cameraBadge
            }
            .font(.callout)

            Toggle(content.enableExperimentalGazeFocusLabel, isOn: $isCameraGazeEnabled)
                .onChange(of: isCameraGazeEnabled) { _, newValue in
                    updateCameraGazeOptIn(newValue)
                }
                .toggleStyle(.switch)
                .controlSize(.small)

            Text(appText.cameraRationale)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            actionButtons {
                if cameraPermissionManager.cameraStatus != .authorized {
                    Button(content.requestCameraButton) {
                        requestCameraPermission()
                    }
                }
                Button(content.openCameraSettingsButton) {
                    cameraPermissionManager.openCameraSettings()
                }
                Button(content.recheckCameraButton) {
                    cameraPermissionManager.refresh()
                }
            }

            calibrationRows
        }
    }

    /// 브라우저 탭 개수 조회용 Automation 권한 상태를 표시하는 행.
    ///
    /// 확인 자체가 대상 브라우저에 Apple Event를 보내 권한 팝업을 띄울 수 있어
    /// 화면 진입 시 자동으로 조회하지 않고, 사용자가 "다시 확인"을 눌렀을 때만 조회한다.
    private var browserAutomationPermissionRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(content.browserTabAutomationLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                if browserAutomationPermissionManager.hasCheckedOnce {
                    browserAutomationBadge
                }
            }
            .font(.callout)

            if !browserAutomationPermissionManager.deniedBrowserNames.isEmpty {
                Text(
                    content.browserAutomationDeniedDetail(
                        deniedBrowserNames: browserAutomationPermissionManager.deniedBrowserNames
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            actionButtons {
                Button(content.recheckButton) {
                    Task { await browserAutomationPermissionManager.refresh() }
                }
                Button(content.openSystemSettingsButton) {
                    browserAutomationPermissionManager.openAutomationSettings()
                }
            }
        }
    }

    /// browserAutomationPermissionRows의 상태 배지.
    private var browserAutomationBadge: some View {
        let isDenied = !browserAutomationPermissionManager.deniedBrowserNames.isEmpty
        return Text(
            content.browserAutomationStatusBadge(
                deniedBrowserNames: browserAutomationPermissionManager.deniedBrowserNames
            )
        )
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background((isDenied ? Color.orange : Color.green).opacity(0.18), in: Capsule())
        .foregroundStyle(isDenied ? Color.orange : Color.green)
    }

    /// gaze calibration 상태와 시작 버튼을 표시하는 행.
    private var calibrationRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(content.gazeCalibrationLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(content.calibrationStatusText(gazeCalibrationStatus))
                    .fontWeight(.medium)
            }
            .font(.callout)

            actionButtons {
                Button(content.calibrateButton) {
                    NotificationCenter.default.post(name: .gazeCalibrationRequested, object: nil)
                }
                .disabled(!gazeCalibrationStatus.canStartCalibration)

                Button(content.recheckButton) {
                    refreshGazeSampleCount()
                }
            }

            Text(content.calibrationHelp)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 현재 opt-in·권한·샘플 수 기준 calibration 상태.
    private var gazeCalibrationStatus: GazeCalibrationStatus {
        GazeCalibrationStatus(
            isOptInEnabled: cameraGazeSettings.isOptInEnabled,
            isCameraAuthorized: cameraPermissionManager.cameraStatus == .authorized,
            sampleCount: gazeSampleCount
        )
    }

    /// readiness 상태를 색상 배지로 표현한다.
    private func readinessBadge(for state: SettingsReadinessSummary.State) -> some View {
        let color: Color = switch state {
        case .permissionRequired:
            .orange
        case .sessionDisabled:
            .secondary
        case .ready:
            .green
        }

        return Text(content.setupReadinessBadge(for: state))
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    /// 권한 상태를 색상 배지로 표현한다.
    private var accessibilityBadge: some View {
        let granted = permissionManager.accessibilityStatus == .granted
        return Text(granted ? content.grantedBadge : content.notGrantedBadge)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                (granted ? Color.green : Color.orange).opacity(0.18),
                in: Capsule()
            )
            .foregroundStyle(granted ? Color.green : Color.orange)
    }

    /// Camera 권한/opt-in 상태 배지.
    private var cameraBadge: some View {
        let isReady = cameraGazeSettings.isOptInEnabled
            && cameraPermissionManager.cameraStatus == .authorized
        return Text(isReady ? content.readyBadge : cameraStatusText)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                (isReady ? Color.green : Color.orange).opacity(0.18),
                in: Capsule()
            )
            .foregroundStyle(isReady ? Color.green : Color.orange)
    }

    private var cameraStatusText: String {
        if !cameraGazeSettings.isOptInEnabled {
            return content.offBadge
        }

        switch cameraPermissionManager.cameraStatus {
        case .authorized:
            return content.readyBadge
        case .notDetermined:
            return content.needsPermissionBadge
        case .denied:
            return content.deniedBadge
        case .restricted:
            return content.restrictedBadge
        }
    }

    /// kill switch 상태와 토글 버튼을 표시하는 섹션.
    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(content.sessionTitle)
                    .font(.headline)
                Spacer()
                sessionBadge
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Button(session.isEnabled ? content.disableButton : content.enableButton) {
                        session.toggle()
                    }
                    Text(content.sessionKillSwitchNotice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Button(session.isEnabled ? content.disableButton : content.enableButton) {
                        session.toggle()
                    }
                    Text(content.sessionKillSwitchNotice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .controlSize(.small)
        }
    }

    /// 세션 활성 여부 배지.
    private var sessionBadge: some View {
        let active = session.isEnabled
        return Text(active ? content.activeBadge : content.disabledBadge)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                (active ? Color.green : Color.secondary).opacity(0.18),
                in: Capsule()
            )
            .foregroundStyle(active ? Color.green : Color.secondary)
    }

    /// overlay 활성화와 window control 고정키를 안내하는 섹션.
    ///
    /// 표시하는 단축키 목록은 `OverlayActivationShortcut` / `WindowControlShortcutSet`
    /// 코드 정의를 SSOT로 삼아 하드코딩을 피한다.
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.shortcutsTitle)
                .font(.headline)

            labeledRow(content.showOverlayLabel, OverlayActivationShortcut.activationDisplayName)

            ForEach(WindowControlShortcutSet.default.shortcuts, id: \.keyCode) { shortcut in
                labeledRow(content.windowControlLabel(for: shortcut.action), shortcut.displayName)
            }

            Text(content.windowControlShortcutsNotice)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// overlay 라벨 투명도를 조절하는 섹션.
    ///
    /// 라벨 배경 투명도를 낮추면 overlay가 뒤 콘텐츠를 덜 가린다. 값은
    /// `OverlayAppearance.labelBackgroundOpacityRange`를 SSOT로 삼아 clamp된다.
    private var overlayAppearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.overlayAppearanceTitle)
                .font(.headline)

            HStack {
                Text(content.labelOpacityLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", labelBackgroundOpacity * 100))
                    .font(.callout)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            .font(.callout)

            Slider(
                value: $labelBackgroundOpacity,
                in: OverlayAppearance.labelBackgroundOpacityRange
            )
            .controlSize(.small)
            .onChange(of: labelBackgroundOpacity) { _, newValue in
                appearanceSettings.labelBackgroundOpacity = newValue
            }

            Text(content.labelOpacityNotice)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// overlay 활성화 후 실제 조작 방법을 단계별로 안내하는 섹션.
    ///
    /// 문구는 `AppContent.overlayUsageSteps`를 SSOT로 삼는다.
    private var overlayUsageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.overlayUsageTitle)
                .font(.headline)

            ForEach(Array(content.overlayUsageSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text(step)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
            }

            Button(content.replayTutorialButton) {
                onboarding.replayTutorial()
            }
            .controlSize(.small)
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(content.privacyTitle)
                .font(.headline)
            Text(appText.privacyNotice)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// interaction 로그 opt-in과 로그/진단 export 관리 섹션.
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.diagnosticsTitle)
                .font(.headline)

            Toggle(content.storeInteractionLogsLabel, isOn: $isInteractionLoggingEnabled)
                .onChange(of: isInteractionLoggingEnabled) { _, newValue in
                    logStore.isOptInEnabled = newValue
                }
                .toggleStyle(.switch)
                .controlSize(.small)

            Text(content.interactionLoggingNotice)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            actionButtons {
                Button(content.deleteLogsButton) {
                    logStore.deleteAll()
                    diagnosticsFeedback.didDeleteLogs()
                }

                if debugFeatureVisibility.isDebugExportVisible {
                    Button(content.createDebugExportButton) {
                        do {
                            _ = try debugExport.createExport()
                            diagnosticsFeedback.didCreateDebugExport()
                        } catch {
                            diagnosticsFeedback.didFailDebugExport()
                        }
                    }
                    Button(content.deleteExportButton) {
                        debugExport.deleteAll()
                        diagnosticsFeedback.didDeleteDebugExport()
                    }
                }
            }

            if let message = content.diagnosticsMessage(diagnosticsFeedback.message) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if debugFeatureVisibility.isDebugExportVisible {
                Text(content.debugExportNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Known Limitations 열람 진입점.
    private var footer: some View {
        Button(content.knownLimitationsButton) {
            showLimitations = true
        }
        .controlSize(.small)
    }

    // MARK: - Helpers

    /// 긴 버튼 묶음은 가능한 경우 한 줄로, 좁은 폭에서는 세로로 배치한다.
    private func actionButtons<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                content()
            }

            VStack(alignment: .leading, spacing: 6) {
                content()
            }
        }
        .controlSize(.small)
    }

    /// 권한 상태를 갱신하고 결과를 Info 로그로 남긴다.
    ///
    /// - Note: 상태 코드(granted/notGranted)만 기록하며 민감정보는 남기지 않는다.
    private func refreshPermission() {
        permissionManager.refresh()
        let granted = permissionManager.accessibilityStatus == .granted
        AppLogger.permission.info("accessibility granted=\(granted, privacy: .public)")
    }

    /// Accessibility 권한 요청 프롬프트를 띄운 뒤 현재 상태를 기록한다.
    private func requestAccessibilityPermission() {
        permissionManager.requestAccessibilityPermission()
        let granted = permissionManager.accessibilityStatus == .granted
        AppLogger.permission.info("accessibility request completed granted=\(granted, privacy: .public)")
    }

    private func updateCameraGazeOptIn(_ isEnabled: Bool) {
        cameraGazeSettings.isOptInEnabled = isEnabled

        guard isEnabled else {
            AppLogger.permission.info("camera gaze opt-in disabled")
            return
        }

        requestCameraPermission()
    }

    /// 저장된 calibration sample 수를 다시 읽어 상태 표시를 갱신한다.
    private func refreshGazeSampleCount() {
        gazeSampleCount = gazeCalibrationStore.load().count
    }

    private func requestCameraPermission() {
        Task { @MainActor in
            await cameraPermissionManager.requestCameraPermission()
            let granted = cameraPermissionManager.cameraStatus == .authorized
            if !granted {
                isCameraGazeEnabled = false
                cameraGazeSettings.isOptInEnabled = false
            }
            AppLogger.permission.info("camera request completed granted=\(granted, privacy: .public)")
        }
    }

    /// 라벨과 값을 좌우로 배치한 행.
    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.callout)
    }
}

#Preview {
    SettingsView()
}
