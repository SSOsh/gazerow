import SwiftUI

/// 첫 실행 안내 시트.
///
/// PR-006에 따라 데이터 접근 범위(Accessibility)를 먼저 설명하고,
/// 접근성/의료 보조 제품이 아님을 밝힌 뒤 setup 단계를 안내한다.
///
/// @author suho.do
/// @since 2026-07-02
struct OnboardingView: View {

    /// 시트 표시 상태를 소유하는 onboarding 상태.
    let onboarding: OnboardingState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Text(AppState.accessibilityRationale)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            stepsSection

            Text(AppContent.nonMedicalDisclaimer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Get Started") {
                    onboarding.complete()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440, height: 380)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "cursorarrow.rays")
                .font(.system(size: 28))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome to \(AppState.appName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Local keyboard-click utility")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Setup")
                .font(.headline)
            ForEach(Array(AppContent.setupSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text(step)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.callout)
            }
        }
    }
}

#Preview {
    OnboardingView(onboarding: OnboardingState())
}
