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

    /// diagnostics 수동 액션 결과 표시 상태.
    @State private var diagnosticsFeedback = DiagnosticsActionFeedback()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            statusSection

            Divider()

            permissionSection

            Divider()

            sessionSection

            Divider()

            privacySection

            Divider()

            diagnosticsSection

            footer

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 420, height: 560)
        .onAppear {
            refreshPermission()
            onboarding.presentIfNeeded()
            isInteractionLoggingEnabled = logStore.isOptInEnabled
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            refreshPermission()
        }
        .sheet(isPresented: $onboarding.isPresenting) {
            OnboardingView(onboarding: onboarding)
        }
        .sheet(isPresented: $showLimitations) {
            KnownLimitationsView()
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
            labeledRow("MVP mode", AppState.mvpMode)
            labeledRow("Gaze", AppState.gazeStatus)
        }
    }

    /// Accessibility 권한 상태와 안내/이동 버튼을 표시하는 섹션.
    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions")
                .font(.headline)

            HStack {
                Text("Accessibility")
                    .foregroundStyle(.secondary)
                Spacer()
                accessibilityBadge
            }
            .font(.callout)

            // 권한이 없을 때만 접근 범위/불가 사유를 먼저 설명한다 (PR-006).
            if let reason = permissionManager.overlayUnavailableReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if permissionManager.accessibilityStatus == .notGranted {
                    Button("Request Permission") {
                        requestAccessibilityPermission()
                    }
                }
                Button("Open System Settings") {
                    permissionManager.openAccessibilitySettings()
                }
                Button("Recheck") {
                    refreshPermission()
                }
            }
            .controlSize(.small)

            // Camera/Input Monitoring은 baseline 흐름에서 요청하지 않음을 명시한다.
            labeledRow("Camera", "Not requested (Post-MVP)")
            labeledRow("Input Monitoring", "Not requested (deferred)")
        }
    }

    /// 권한 상태를 색상 배지로 표현한다.
    private var accessibilityBadge: some View {
        let granted = permissionManager.accessibilityStatus == .granted
        return Text(granted ? "Granted" : "Not granted")
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

    /// kill switch 상태와 토글 버튼을 표시하는 섹션.
    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Session")
                    .font(.headline)
                Spacer()
                sessionBadge
            }

            HStack(spacing: 8) {
                Button(session.isEnabled ? "Disable" : "Enable") {
                    session.toggle()
                }
                Text("Kill switch stops overlay activation immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .controlSize(.small)
        }
    }

    /// 세션 활성 여부 배지.
    private var sessionBadge: some View {
        let active = session.isEnabled
        return Text(active ? "Active" : "Disabled")
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

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Privacy")
                .font(.headline)
            Text(AppState.privacyNotice)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// interaction 로그 opt-in과 로그/진단 export 관리 섹션.
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostics")
                .font(.headline)

            Toggle("Store interaction logs", isOn: $isInteractionLoggingEnabled)
                .onChange(of: isInteractionLoggingEnabled) { _, newValue in
                    logStore.isOptInEnabled = newValue
                }
                .toggleStyle(.switch)
                .controlSize(.small)

            Text(AppContent.interactionLoggingNotice)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("Delete Logs") {
                    logStore.deleteAll()
                    diagnosticsFeedback.didDeleteLogs()
                }

                if debugFeatureVisibility.isDebugExportVisible {
                    Button("Create Debug Export") {
                        do {
                            _ = try debugExport.createExport()
                            diagnosticsFeedback.didCreateDebugExport()
                        } catch {
                            diagnosticsFeedback.didFailDebugExport()
                        }
                    }
                    Button("Delete Export") {
                        debugExport.deleteAll()
                        diagnosticsFeedback.didDeleteDebugExport()
                    }
                }
            }
            .controlSize(.small)

            if let message = diagnosticsFeedback.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if debugFeatureVisibility.isDebugExportVisible {
                Text(AppContent.debugExportNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Known Limitations 열람 진입점.
    private var footer: some View {
        Button("Known Limitations…") {
            showLimitations = true
        }
        .controlSize(.small)
    }

    // MARK: - Helpers

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
