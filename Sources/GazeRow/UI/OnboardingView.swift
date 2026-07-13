import AppKit
import SwiftUI

/// 첫 실행과 다시 보기에서 사용하는 안전한 인앱 tutorial 시트.
///
/// tutorial은 키보드 명령을 모의 진행 상태에만 반영하며 외부 앱의 클릭이나
/// 창 활성화를 호출하지 않는다.
///
/// @author suho.do
/// @since 2026-07-13
struct OnboardingView: View {

    /// 시트 표시와 tutorial 진행 상태를 소유한다.
    let onboarding: OnboardingState

    /// 표시 언어.
    let language: AppLanguage

    /// tutorial 표시 중에만 유지하는 local keyboard event monitor.
    @State private var keyboardEventMonitor: Any?

    init(
        onboarding: OnboardingState,
        language: AppLanguage = AppLanguageSettings().selectedLanguage
    ) {
        self.onboarding = onboarding
        self.language = language
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            VStack(alignment: .leading, spacing: 10) {
                Text(content.tutorialTitle(for: onboarding.tutorialProgress.step))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(content.tutorialDescription(for: onboarding.tutorialProgress.step))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            tutorialContent

            Spacer(minLength: 0)

            tutorialControls
        }
        .padding(24)
        .frame(width: 500, height: 450)
        .focusable()
        .onAppear(perform: installKeyboardEventMonitor)
        .onDisappear(perform: removeKeyboardEventMonitor)
        .alert(content.tutorialExitTitle, isPresented: exitConfirmationBinding) {
            Button(content.tutorialExitButton, role: .destructive) {
                onboarding.dismissTutorial()
            }
            Button(content.tutorialBackButton, role: .cancel) {
                onboarding.cancelExit()
            }
        } message: {
            Text(content.tutorialExitMessage)
        }
    }

    private var content: AppContent.Localized {
        AppContent.localized(for: language)
    }

    private var appText: AppState.LocalizedText {
        AppState.localized(for: language)
    }

    private var exitConfirmationBinding: Binding<Bool> {
        Binding(
            get: { onboarding.isExitConfirmationPresented },
            set: { isPresented in
                if !isPresented {
                    onboarding.cancelExit()
                }
            }
        )
    }

    @ViewBuilder
    private var tutorialContent: some View {
        switch onboarding.tutorialProgress.step {
        case .introduction:
            introductionContent
        case .labelPractice:
            labelPracticeContent
        case .modePractice:
            modePracticeContent
        case .finish:
            finishContent
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "cursorarrow.rays")
                .font(.system(size: 28))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppState.appName)
                    .font(.headline)
                Text(appText.accessibilityRationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var introductionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(content.setupTitle)
                .font(.headline)
            ForEach(Array(content.setupSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                    Text(step)
                }
                .font(.callout)
            }
            Text(content.nonMedicalDisclaimer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var labelPracticeContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                tutorialTarget(label: "A", title: "Search", isFocused: false)
                tutorialTarget(
                    label: "F",
                    title: "Open item",
                    isFocused: onboarding.tutorialProgress.focusedDemoLabel == "F"
                )
                tutorialTarget(label: "J", title: "Close", isFocused: false)
            }

            HStack(spacing: 8) {
                tutorialKey("F", isActive: onboarding.tutorialProgress.focusedDemoLabel == "F")
                tutorialKey("Return", isActive: onboarding.tutorialProgress.didConfirmDemoLabel)
                Text(onboarding.tutorialProgress.didConfirmDemoLabel
                    ? content.commandBarAction(.confirmAgain)
                    : content.commandBarAction(.select))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(content.tutorialDescription(for: .labelPractice))
        }
    }

    private var modePracticeContent: some View {
        HStack(spacing: 12) {
            tutorialMode(
                key: "/",
                title: content.commandBarAction(.searchElements),
                isComplete: onboarding.tutorialProgress.didTryElementSearch
            )
            tutorialMode(
                key: ";",
                title: content.commandBarAction(.switchWindows),
                isComplete: onboarding.tutorialProgress.didTryWindowSwitch
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.tutorialDescription(for: .modePractice))
    }

    private var finishContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text(content.tutorialDescription(for: .finish))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var tutorialControls: some View {
        HStack {
            if onboarding.tutorialProgress.step != .introduction {
                Button(content.tutorialBackButton) {
                    onboarding.goBack()
                }
                .accessibilityLabel(content.tutorialBackButton)
            }

            Button(content.tutorialSkipButton) {
                onboarding.completeTutorial()
            }
            .accessibilityLabel(content.tutorialSkipButton)

            Spacer()

            switch onboarding.tutorialProgress.step {
            case .introduction:
                Button(content.tutorialStartButton) {
                    onboarding.startTutorial()
                }
                .keyboardShortcut(.defaultAction)
            case .finish:
                Button(content.tutorialFinishButton) {
                    onboarding.completeTutorial()
                }
                .keyboardShortcut(.defaultAction)
            case .labelPractice, .modePractice:
                EmptyView()
            }
        }
    }

    private func tutorialTarget(label: String, title: String, isFocused: Bool) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.headline.monospaced())
                .frame(width: 30, height: 26)
                .background(isFocused ? Color.blue : Color.secondary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(title)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(isFocused ? Color.blue : Color.secondary.opacity(0.3), lineWidth: isFocused ? 2 : 1)
        }
        .accessibilityLabel("\(label), \(title)")
    }

    private func tutorialMode(key: String, title: String, isComplete: Bool) -> some View {
        VStack(spacing: 10) {
            tutorialKey(key, isActive: isComplete)
            Text(title)
                .font(.callout)
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? .green : .secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(isComplete ? Color.green : Color.secondary.opacity(0.3), lineWidth: isComplete ? 2 : 1)
        }
    }

    private func tutorialKey(_ key: String, isActive: Bool) -> some View {
        Text(key)
            .font(.callout.monospaced().weight(.semibold))
            .padding(.horizontal, 8)
            .frame(minWidth: 30, minHeight: 26)
            .background(isActive ? Color.blue.opacity(0.85) : Color.secondary.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func installKeyboardEventMonitor() {
        guard keyboardEventMonitor == nil else {
            return
        }

        let mapper = FocusKeyboardCommandMapper()
        keyboardEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let command = mapper.command(for: FocusKeyboardInput(
                keyCode: event.keyCode,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                isShiftPressed: event.modifierFlags.contains(.shift)
            )) else {
                return event
            }

            if command == .closeOverlay {
                onboarding.requestExitConfirmation()
            } else {
                onboarding.handleTutorialCommand(command)
            }

            return nil
        }
    }

    private func removeKeyboardEventMonitor() {
        if let keyboardEventMonitor {
            NSEvent.removeMonitor(keyboardEventMonitor)
            self.keyboardEventMonitor = nil
        }
    }
}

#Preview {
    OnboardingView(onboarding: OnboardingState())
}
