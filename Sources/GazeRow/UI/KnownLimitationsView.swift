import SwiftUI

/// Known Limitations와 앱 지원 범위를 보여주는 열람 시트.
///
/// TICKET-009. 지원/제한/미지원/미확인 앱을 구분해
/// 사용자가 어디까지 기대할 수 있는지 알 수 있게 한다.
///
/// @author suho.do
/// @since 2026-07-02
struct KnownLimitationsView: View {

    /// 시트를 닫기 위한 dismiss 액션.
    @Environment(\.dismiss) private var dismiss

    /// 표시 언어.
    let language: AppLanguage

    init(language: AppLanguage = AppLanguageSettings().selectedLanguage) {
        self.language = language
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(content.knownLimitationsTitle)
                .font(.title2)
                .fontWeight(.semibold)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    limitationsSection
                    fallbackSection
                    appSupportSection
                }
            }

            HStack {
                Spacer()
                Button(content.doneButton) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460, height: 480)
    }

    private var content: AppContent.Localized {
        AppContent.localized(for: language)
    }

    // MARK: - Sections

    private var limitationsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(content.knownLimitations, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•").foregroundStyle(.secondary)
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.callout)
            }
        }
    }

    private var fallbackSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(content.clickSafetyTitle)
                .font(.headline)
            Text(content.fallbackDisabledNotice)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appSupportSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(content.appSupportTitle)
                .font(.headline)
            ForEach(AppContent.appSupport) { app in
                HStack {
                    Text(app.name)
                    Spacer()
                    tierBadge(app.tier)
                }
                .font(.callout)
            }
        }
    }

    /// 지원 등급을 색상 배지로 표현한다.
    private func tierBadge(_ tier: AppContent.SupportTier) -> some View {
        let (label, color): (String, Color) = switch tier {
        case .supported: (content.supportedBadge, .green)
        case .limited: (content.limitedBadge, .orange)
        case .unsupported: (content.unsupportedBadge, .red)
        case .unverified: (content.unverifiedBadge, .secondary)
        }
        return Text(label)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

#Preview {
    KnownLimitationsView()
}
