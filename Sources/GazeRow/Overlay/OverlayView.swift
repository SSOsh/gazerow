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
        let focusStyle = QueryFocusStyle(scope: status.activeScope)
        let highlightFrame = localHighlightFrame
        let renderingStrategy = OverlayRenderingStrategy.resolve(labelCount: layout.labels.count)
        ZStack(alignment: .topLeading) {
            if showsBoundary {
                Rectangle()
                    .stroke(Color.accentColor.opacity(appearance.boundaryOpacity), lineWidth: 2)
                    .frame(width: layout.localBounds.width, height: layout.localBounds.height)
            }

            if renderingStrategy == .canvas {
                OverlayTargetMarkerCanvas(
                    labels: layout.labels,
                    focusedLabelID: focusedLabelID,
                    appearance: appearance,
                    focusStyle: focusStyle
                )
            } else {
                ForEach(layout.labels) { label in
                    OverlayTargetMarkerView(
                        label: label,
                        isFocused: label.id == focusedLabelID,
                        appearance: appearance,
                        focusStyle: focusStyle
                    )
                    .frame(width: layout.localBounds.width, height: layout.localBounds.height)
                }
            }

            if let highlightFrame {
                SearchHitHighlightView(scope: status.activeScope)
                    .frame(width: highlightFrame.width, height: highlightFrame.height)
                    .position(x: highlightFrame.midX, y: highlightFrame.midY)
            }

            if renderingStrategy == .canvas {
                OverlayLabelCanvas(
                    labels: layout.labels,
                    focusedLabelID: focusedLabelID,
                    status: status,
                    appearance: appearance,
                    focusStyle: focusStyle
                )
            } else {
                ForEach(layout.labels) { label in
                    OverlayLabelView(
                        label: label,
                        isFocused: label.id == focusedLabelID,
                        appearance: appearance,
                        focusStyle: focusStyle,
                        labelOpacity: OverlayLabelVisibility.opacity(
                            for: label,
                            focusedLabelID: focusedLabelID,
                            status: status
                        )
                    )
                    .frame(width: label.labelFrame.width, height: label.labelFrame.height)
                    .position(x: label.labelFrame.midX, y: label.labelFrame.midY)
                }
            }

        }
        .frame(width: layout.localBounds.width, height: layout.localBounds.height)
        .background(Color.clear)
    }

    private var localHighlightFrame: CGRect? {
        guard let highlightFrame = status.highlightFrame,
              highlightFrame.width > 0,
              highlightFrame.height > 0 else {
            return nil
        }

        let localFrame = OverlayCoordinateMapper(targetFrame: layout.targetFrame)
            .mapScreenFrameToLocal(highlightFrame)
        return localFrame.intersection(layout.localBounds).isNull ? nil : localFrame
    }
}

/// 대량 target marker를 하나의 Canvas에서 그린다.
private struct OverlayTargetMarkerCanvas: View {
    let labels: [OverlayLabel]
    let focusedLabelID: Int?
    let appearance: OverlayAppearance
    let focusStyle: QueryFocusStyle

    var body: some View {
        Canvas { context, _ in
            for label in labels {
                drawMarker(
                    label,
                    isFocused: label.id == focusedLabelID,
                    in: &context
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func drawMarker(
        _ label: OverlayLabel,
        isFocused: Bool,
        in context: inout GraphicsContext
    ) {
        let targetFrame = label.candidateFrame.insetBy(dx: -2, dy: -2)
        let cornerRadius = min(8, max(4, min(targetFrame.width, targetFrame.height) / 4))
        let targetPath = Path(roundedRect: targetFrame, cornerRadius: cornerRadius)
        if !isFocused {
            context.fill(
                targetPath,
                with: .color(Color.accentColor.opacity(appearance.markerFillOpacity))
            )
        }
        context.stroke(
            targetPath,
            with: .color(markerStrokeColor(isFocused: isFocused)),
            lineWidth: isFocused ? 2 : 1
        )

        let dotSize: CGFloat = isFocused ? 8 : 5
        let dotFrame = CGRect(
            x: label.anchorPoint.x - dotSize / 2,
            y: label.anchorPoint.y - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
        let dotPath = Path(ellipseIn: dotFrame)
        context.fill(dotPath, with: .color(markerDotColor(isFocused: isFocused)))
        context.stroke(
            dotPath,
            with: .color(Color.white.opacity(isFocused ? 0.95 : 0.65)),
            lineWidth: 1
        )
    }

    private func markerStrokeColor(isFocused: Bool) -> Color {
        isFocused ? focusStyle.markerColor.opacity(0.98) : Color.accentColor.opacity(0.42)
    }

    private func markerDotColor(isFocused: Bool) -> Color {
        isFocused ? focusStyle.markerColor.opacity(1) : Color.white.opacity(0.7)
    }
}

/// 대량 label background와 text를 하나의 Canvas에서 그린다.
private struct OverlayLabelCanvas: View {
    let labels: [OverlayLabel]
    let focusedLabelID: Int?
    let status: OverlayInteractionStatus
    let appearance: OverlayAppearance
    let focusStyle: QueryFocusStyle

    var body: some View {
        Canvas { context, _ in
            for label in labels {
                drawLabel(
                    label,
                    isFocused: label.id == focusedLabelID,
                    in: &context
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func drawLabel(
        _ label: OverlayLabel,
        isFocused: Bool,
        in context: inout GraphicsContext
    ) {
        let opacity = OverlayLabelVisibility.opacity(
            for: label,
            focusedLabelID: focusedLabelID,
            status: status
        )
        let frame = scaledFrame(label.labelFrame, isFocused: isFocused)
        let path = Path(roundedRect: frame, cornerRadius: 5)

        context.drawLayer { layer in
            layer.opacity = opacity
            layer.fill(path, with: .color(labelBackgroundColor(isFocused: isFocused)))
            layer.stroke(
                path,
                with: .color(Color.white.opacity(isFocused ? 1 : 0.9)),
                lineWidth: isFocused ? 2 : 1
            )
            let text = Text(label.displayText)
                .font(.system(size: isFocused ? 16.2 : 15, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.white.opacity(appearance.labelTextOpacity))
            layer.draw(layer.resolve(text), at: CGPoint(x: frame.midX, y: frame.midY), anchor: .center)
        }
    }

    private func scaledFrame(_ frame: CGRect, isFocused: Bool) -> CGRect {
        guard isFocused else {
            return frame
        }

        let widthDelta = frame.width * 0.08
        let heightDelta = frame.height * 0.08
        return frame.insetBy(dx: -widthDelta / 2, dy: -heightDelta / 2)
    }

    private func labelBackgroundColor(isFocused: Bool) -> Color {
        isFocused
            ? focusStyle.markerColor.opacity(min(1.0, appearance.labelBackgroundOpacity + 0.16))
            : Color.accentColor.opacity(appearance.labelBackgroundOpacity)
    }
}

private struct SearchHitHighlightView: View {
    let scope: QueryScope

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .stroke(color.opacity(0.92), lineWidth: 2)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
            .allowsHitTesting(false)
    }

    private var color: Color {
        QueryFocusStyle(scope: scope).markerColor
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
            ? focusStyle.markerColor.opacity(min(1.0, appearance.labelBackgroundOpacity + 0.16))
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
