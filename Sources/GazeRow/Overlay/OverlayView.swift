import SwiftUI

/// target window 위에 표시되는 transparent overlay content.
///
/// @author suho.do
/// @since 2026-07-02
struct OverlayView: View {
    let layout: OverlayLayout
    let showsBoundary: Bool
    let focusedLabelID: Int?
    let status: OverlayInteractionStatus

    init(
        layout: OverlayLayout,
        showsBoundary: Bool = true,
        focusedLabelID: Int? = nil,
        status: OverlayInteractionStatus = OverlayInteractionStatus()
    ) {
        self.layout = layout
        self.showsBoundary = showsBoundary
        self.focusedLabelID = focusedLabelID
        self.status = status
    }

    var body: some View {
        let statusWidth = max(0, min(layout.localBounds.width - 16, 420))

        ZStack(alignment: .topLeading) {
            if showsBoundary {
                Rectangle()
                    .stroke(Color.accentColor.opacity(0.75), lineWidth: 2)
                    .frame(width: layout.localBounds.width, height: layout.localBounds.height)
            }

            ForEach(layout.labels) { label in
                OverlayLabelView(
                    label: label,
                    isFocused: label.id == focusedLabelID
                )
                    .frame(width: label.labelFrame.width, height: label.labelFrame.height)
                    .position(x: label.labelFrame.midX, y: label.labelFrame.midY)
            }

            OverlayStatusView(status: status)
                .frame(width: statusWidth, alignment: .leading)
                .position(
                    x: statusWidth / 2 + 8,
                    y: layout.localBounds.height - 22
                )
        }
        .frame(width: layout.localBounds.width, height: layout.localBounds.height)
        .background(Color.clear)
    }
}

private struct OverlayLabelView: View {
    let label: OverlayLabel
    let isFocused: Bool

    var body: some View {
        Text(label.text)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white.opacity(isFocused ? 1 : 0.9), lineWidth: isFocused ? 2 : 1)
            }
            .scaleEffect(isFocused ? 1.08 : 1)
    }

    private var backgroundColor: Color {
        isFocused ? Color.orange.opacity(0.96) : Color.accentColor.opacity(0.92)
    }
}

private struct OverlayStatusView: View {
    let status: OverlayInteractionStatus

    var body: some View {
        HStack(spacing: 10) {
            Text(primaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 12)

            if let focusedLabel = status.focusedLabel {
                Text(focusedLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    }
            }
        }
        .font(.system(size: 12, weight: .regular, design: .rounded))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
    }

    private var backgroundColor: Color {
        switch status.tone {
        case .neutral:
            Color.black.opacity(0.72)
        case .success:
            Color.green.opacity(0.82)
        case .warning:
            Color.orange.opacity(0.86)
        case .failure:
            Color.red.opacity(0.86)
        }
    }

    private var primaryText: String {
        if let message = status.message {
            if !status.typedLabelBuffer.isEmpty {
                return "\(message) · Typed \(status.typedLabelBuffer)"
            }

            return message
        }

        if !status.typedLabelBuffer.isEmpty {
            return "Typed \(status.typedLabelBuffer)"
        }

        return "Ready"
    }
}

#Preview {
    let candidate = ClickableCandidate(
        role: AccessibilityRole.button,
        subrole: nil,
        title: "Open",
        frame: CGRect(x: 120, y: 140, width: 80, height: 24),
        actions: [AccessibilityAction.press]
    )
    let layout = OverlayLayoutEngine().makeLayout(
        targetFrame: CGRect(x: 100, y: 100, width: 360, height: 220),
        candidates: [candidate],
        displayInfo: OverlayDisplayInfo(scaleFactor: 2, visibleFrame: nil)
    )
    OverlayView(
        layout: layout,
        focusedLabelID: 0,
        status: OverlayInteractionStatus(
            focusedLabel: "A",
            typedLabelBuffer: "",
            message: "Ready",
            tone: .neutral
        )
    )
}
