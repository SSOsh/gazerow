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
    let appearance: OverlayAppearance

    init(
        layout: OverlayLayout,
        showsBoundary: Bool = true,
        focusedLabelID: Int? = nil,
        status: OverlayInteractionStatus = OverlayInteractionStatus(),
        appearance: OverlayAppearance = OverlayAppearance()
    ) {
        self.layout = layout
        self.showsBoundary = showsBoundary
        self.focusedLabelID = focusedLabelID
        self.status = status
        self.appearance = appearance
    }

    var body: some View {
        let statusWidth = OverlayStatusPresentation.width(in: layout.localBounds)
        let statusCenter = OverlayStatusPresentation.center(in: layout.localBounds)
        let focusStyle = QueryFocusStyle(scope: status.activeScope)
        let labelOpacity = status.activeScope == .windows ? 0.25 : 1.0

        ZStack(alignment: .topLeading) {
            if showsBoundary {
                Rectangle()
                    .stroke(Color.accentColor.opacity(appearance.boundaryOpacity), lineWidth: 2)
                    .frame(width: layout.localBounds.width, height: layout.localBounds.height)
            }

            ForEach(layout.labels) { label in
                OverlayTargetMarkerView(
                    label: label,
                    isFocused: label.id == focusedLabelID,
                    appearance: appearance,
                    focusStyle: focusStyle
                )
                .frame(width: layout.localBounds.width, height: layout.localBounds.height)
            }

            ForEach(layout.labels) { label in
                OverlayLabelView(
                    label: label,
                    isFocused: label.id == focusedLabelID,
                    appearance: appearance,
                    focusStyle: focusStyle,
                    labelOpacity: labelOpacity
                )
                    .frame(width: label.labelFrame.width, height: label.labelFrame.height)
                    .position(x: label.labelFrame.midX, y: label.labelFrame.midY)
            }

            OverlayStatusView(status: status)
                .frame(width: statusWidth, alignment: .leading)
                .position(
                    x: statusCenter.x,
                    y: statusCenter.y
                )
        }
        .frame(width: layout.localBounds.width, height: layout.localBounds.height)
        .background(Color.clear)
    }
}

private struct OverlayLabelView: View {
    let label: OverlayLabel
    let isFocused: Bool
    let appearance: OverlayAppearance
    let focusStyle: QueryFocusStyle
    let labelOpacity: Double

    var body: some View {
        Text(label.displayText)
            .font(.system(size: 15, weight: .heavy, design: .monospaced))
            .minimumScaleFactor(0.72)
            .lineLimit(1)
            .foregroundStyle(Color.white.opacity(appearance.labelTextOpacity))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white.opacity(isFocused ? 1 : 0.9), lineWidth: isFocused ? 2 : 1)
            }
            .scaleEffect(isFocused ? 1.08 : 1)
            .opacity(labelOpacity)
    }

    private var backgroundColor: Color {
        isFocused
            ? focusStyle.markerColor.opacity(0.96)
            : Color.accentColor.opacity(appearance.labelBackgroundOpacity)
    }
}

private struct OverlayTargetMarkerView: View {
    let label: OverlayLabel
    let isFocused: Bool
    let appearance: OverlayAppearance
    let focusStyle: QueryFocusStyle

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(fillColor)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(strokeColor, lineWidth: isFocused ? 2 : 1)
                }
                .frame(width: targetFrame.width, height: targetFrame.height)
                .position(x: targetFrame.midX, y: targetFrame.midY)

            Circle()
                .fill(dotColor)
                .frame(width: isFocused ? 8 : 5, height: isFocused ? 8 : 5)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(isFocused ? 0.95 : 0.65), lineWidth: 1)
                }
                .position(x: label.anchorPoint.x, y: label.anchorPoint.y)
        }
        .allowsHitTesting(false)
    }

    private var targetFrame: CGRect {
        label.candidateFrame.insetBy(dx: -2, dy: -2)
    }

    private var cornerRadius: CGFloat {
        min(8, max(4, min(targetFrame.width, targetFrame.height) / 4))
    }

    private var fillColor: Color {
        isFocused ? Color.clear : Color.accentColor.opacity(appearance.markerFillOpacity)
    }

    private var strokeColor: Color {
        isFocused ? focusStyle.markerColor.opacity(0.98) : Color.accentColor.opacity(0.42)
    }

    private var dotColor: Color {
        isFocused ? focusStyle.markerColor.opacity(1) : Color.white.opacity(0.7)
    }
}

private struct QueryFocusStyle: Equatable {
    let scope: QueryScope

    var markerColor: Color {
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

private struct OverlayStatusView: View {
    let status: OverlayInteractionStatus
    private let content = AppContent.localized(for: .english)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ForEach(QueryScope.allCases, id: \.self) { scope in
                    ScopeChip(
                        title: content.queryScopeTitle(scope),
                        isActive: status.activeScope == scope,
                        isPinned: status.pinnedScope == scope
                    )
                }

                Spacer(minLength: 8)

                Text(bufferText)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            HStack(spacing: 10) {
                Text(summaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 12)

                Text(keyHintText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.system(size: 11, weight: .regular, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.88))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
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
    private var bufferText: String {
        let buffer = status.displayBuffer
        guard !buffer.isEmpty else {
            return content.readyBadge
        }

        return "\(buffer)█"
    }

    private var summaryText: String {
        if status.matchCount > 0 {
            let displayIndex = max(1, status.matchIndex)
            return content.queryMatchSummary(
                count: status.matchCount,
                index: min(displayIndex, status.matchCount),
                displayName: status.focusedDisplayName ?? status.focusedLabel ?? ""
            )
        }

        if !status.displayBuffer.isEmpty {
            return content.queryNoMatch
        }

        if let message = status.message {
            return message
        }

        return content.readyBadge
    }

    private var keyHintText: String {
        content.queryKeyHint(for: status.activeScope, enterActionHint: status.enterActionHint)
    }
}

private struct ScopeChip: View {
    let title: String
    let isActive: Bool
    let isPinned: Bool

    var body: some View {
        Text(isPinned ? "\(title)*" : title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(isActive ? 1 : 0.74))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                isActive ? Color.white.opacity(0.28) : Color.clear,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white.opacity(isActive ? 0.84 : 0.45), lineWidth: 1)
            }
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
