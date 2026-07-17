import SwiftUI

/// 화면 하단 command bar의 SwiftUI content.
///
/// @author suho.do
/// @since 2026-07-13
struct OverlayCommandBarView: View {
    let status: OverlayInteractionStatus
    let language: AppLanguage

    init(
        status: OverlayInteractionStatus,
        language: AppLanguage = AppLanguageSettings().selectedLanguage
    ) {
        self.status = status
        self.language = language
    }

    var body: some View {
        let presentation = OverlayCommandBarPresentation(
            status: status,
            content: AppContent.localized(for: language)
        )

        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                ModeBadge(title: presentation.modeTitle, scope: status.activeScope)

                VStack(alignment: .leading, spacing: 2) {
                    if !presentation.inputText.isEmpty {
                        Text("\(presentation.inputText)█")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.head)
                    }

                    Text(presentation.summaryText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) {
                    ForEach(presentation.keyHints) { hint in
                        KeyHintView(hint: hint)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(presentation.keyHints) { hint in
                        KeyHintView(hint: hint)
                    }
                }
            }

            if let helperText = presentation.helperText {
                Text(helperText)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(helperColor(for: presentation.tone))
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.32), radius: 8, y: 2)
    }

    private func helperColor(for tone: OverlayInteractionStatus.Tone) -> Color {
        switch tone {
        case .neutral:
            Color.white.opacity(0.76)
        case .success:
            Color.green.opacity(0.96)
        case .warning:
            Color.orange.opacity(0.98)
        case .failure:
            Color.red.opacity(0.98)
        }
    }
}

/// command bar panel 내부에서 절대 화면 frame을 panel local frame으로 변환한다.
///
/// @author suho.do
/// @since 2026-07-13
struct OverlayCommandBarPanelView: View {
    let layout: OverlayCommandBarLayout
    let status: OverlayInteractionStatus
    let language: AppLanguage

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            OverlayCommandBarView(status: status, language: language)
                .frame(
                    width: layout.commandBarFrame.width,
                    height: layout.commandBarFrame.height,
                    alignment: .center
                )
                .position(
                    x: localCommandBarFrame.midX,
                    y: localCommandBarFrame.midY
                )

            if let previewFrame = layout.previewFrame {
                OverlayWindowMatchStripView(previews: status.windowMatchPreviews)
                    .frame(width: previewFrame.width, height: previewFrame.height, alignment: .center)
                    .position(x: localPreviewFrame(previewFrame).midX, y: localPreviewFrame(previewFrame).midY)
            }
        }
        .frame(width: layout.panelFrame.width, height: layout.panelFrame.height)
        .background(Color.clear)
    }

    private var localCommandBarFrame: CGRect {
        localFrame(from: layout.commandBarFrame)
    }

    private func localPreviewFrame(_ frame: CGRect) -> CGRect {
        localFrame(from: frame)
    }

    private func localFrame(from frame: CGRect) -> CGRect {
        frame.offsetBy(dx: -layout.panelFrame.minX, dy: -layout.panelFrame.minY)
    }
}

private struct ModeBadge: View {
    let title: String
    let scope: QueryScope

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .lineLimit(1)
            .foregroundStyle(Color.white)
            .frame(minWidth: 76)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(accentColor.opacity(0.92), in: RoundedRectangle(cornerRadius: 6))
    }

    private var accentColor: Color {
        switch scope {
        case .labels:
            Color.orange
        case .elements:
            Color(red: 0, green: 0.71, blue: 0.85)
        case .windows:
            Color(red: 0.30, green: 0.43, blue: 0.96)
        }
    }
}

private struct KeyHintView: View {
    let hint: OverlayKeyHint

    var body: some View {
        HStack(spacing: 4) {
            Text(hint.key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 7)
                .frame(minHeight: 24)
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))

            Text(hint.action)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(Color.white.opacity(0.92))
    }
}
