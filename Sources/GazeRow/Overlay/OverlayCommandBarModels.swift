import CoreGraphics

/// command bar keycap이 설명하는 사용자 동작.
///
/// @author suho.do
/// @since 2026-07-13
enum OverlayCommandBarAction: Equatable {
    case select
    case searchElements
    case switchWindows
    case close
    case click
    case next
    case previous
    case clear
    case typeToSearch
    case confirmAgain
    case cancel
    case retry
}

/// command bar에 표시할 keycap 하나.
///
/// @author suho.do
/// @since 2026-07-13
struct OverlayKeyHint: Equatable, Identifiable {
    let key: String
    let action: String
    let priority: Int

    var id: String {
        "\(key):\(action)"
    }
}

/// command bar가 상태를 표시하기 위한 순수 presentation 모델.
///
/// @author suho.do
/// @since 2026-07-13
struct OverlayCommandBarPresentation: Equatable {
    private static let maximumKeyHintCount = 5

    let modeTitle: String
    let inputText: String
    let summaryText: String
    let keyHints: [OverlayKeyHint]
    let helperText: String?
    let tone: OverlayInteractionStatus.Tone

    init(status: OverlayInteractionStatus, content: AppContent.Localized) {
        modeTitle = content.commandBarModeTitle(for: status.activeScope)
        inputText = status.displayBuffer
        summaryText = Self.summaryText(for: status, content: content)
        keyHints = Self.keyHints(for: status, content: content)
        helperText = Self.helperText(for: status, content: content)
        tone = status.tone
    }

    private static func summaryText(
        for status: OverlayInteractionStatus,
        content: AppContent.Localized
    ) -> String {
        switch status.phase {
        case .idle:
            return content.commandBarIdleSummary(for: status.activeScope)
        case .typing:
            return content.commandBarTypingSummary(status.displayBuffer)
        case .matching:
            if status.isGazeTargeting, let displayName = status.focusedDisplayName {
                return content.gazeTargetSummary(displayName: displayName)
            }

            return content.queryMatchSummary(
                count: status.matchCount,
                index: status.matchIndex,
                displayName: status.focusedDisplayName ?? status.focusedLabel ?? ""
            )
        case .noMatches:
            return content.commandBarNoMatchSummary(for: status.activeScope)
        case .awaitingRiskConfirmation:
            return content.commandBarRiskTitle
        case .success, .failure:
            return status.message ?? content.commandBarIdleSummary(for: status.activeScope)
        }
    }

    private static func keyHints(
        for status: OverlayInteractionStatus,
        content: AppContent.Localized
    ) -> [OverlayKeyHint] {
        let hints: [OverlayKeyHint]

        if status.requiresSecondConfirm || status.phase == .awaitingRiskConfirmation {
            hints = [
                hint("Return", .confirmAgain, priority: 0, content: content),
                hint("Esc", .cancel, priority: 1, content: content)
            ]
        } else {
            switch status.phase {
            case .idle:
                hints = idleHints(for: status.activeScope, content: content)
            case .typing:
                hints = inputHints(
                    for: status.activeScope,
                    action: status.activeScope == .windows ? .switchWindows : .click,
                    content: content
                )
            case .matching:
                hints = inputHints(
                    for: status.activeScope,
                    action: status.activeScope == .windows ? .switchWindows : .click,
                    content: content
                )
            case .noMatches:
                hints = noMatchHints(for: status.activeScope, content: content)
            case .awaitingRiskConfirmation:
                hints = []
            case .success:
                hints = [hint("Esc", .close, priority: 0, content: content)]
            case .failure:
                hints = [
                    hint("Return", .retry, priority: 0, content: content),
                    hint("Esc", .close, priority: 1, content: content)
                ]
            }
        }

        return Array(hints.sorted { $0.priority < $1.priority }.prefix(maximumKeyHintCount))
    }

    private static func idleHints(
        for scope: QueryScope,
        content: AppContent.Localized
    ) -> [OverlayKeyHint] {
        switch scope {
        case .labels:
            [
                hint("A-Z", .select, priority: 0, content: content),
                hint("/", .searchElements, priority: 1, content: content),
                hint(";", .switchWindows, priority: 2, content: content),
                hint("Esc", .close, priority: 3, content: content)
            ]
        case .elements:
            [
                hint("Type", .typeToSearch, priority: 0, content: content),
                hint(";", .switchWindows, priority: 1, content: content),
                hint("Delete", .clear, priority: 2, content: content),
                hint("Esc", .close, priority: 3, content: content)
            ]
        case .windows:
            [
                hint("Type", .typeToSearch, priority: 0, content: content),
                hint("/", .searchElements, priority: 1, content: content),
                hint("Delete", .clear, priority: 2, content: content),
                hint("Esc", .close, priority: 3, content: content)
            ]
        }
    }

    private static func inputHints(
        for scope: QueryScope,
        action: OverlayCommandBarAction,
        content: AppContent.Localized
    ) -> [OverlayKeyHint] {
        var hints = [hint("Return", action, priority: 0, content: content)]

        if scope != .labels {
            hints.append(hint("Tab", .next, priority: 1, content: content))
            hints.append(hint("Shift+Tab", .previous, priority: 2, content: content))
        } else {
            hints.append(hint("Tab", .next, priority: 1, content: content))
        }

        hints.append(hint("Delete", .clear, priority: 3, content: content))
        hints.append(hint("Esc", .close, priority: 4, content: content))
        return hints
    }

    private static func noMatchHints(
        for scope: QueryScope,
        content: AppContent.Localized
    ) -> [OverlayKeyHint] {
        var hints = [hint("Delete", .clear, priority: 0, content: content)]

        switch scope {
        case .labels:
            hints.append(hint("/", .searchElements, priority: 1, content: content))
            hints.append(hint(";", .switchWindows, priority: 2, content: content))
        case .elements:
            hints.append(hint(";", .switchWindows, priority: 1, content: content))
        case .windows:
            hints.append(hint("/", .searchElements, priority: 1, content: content))
        }

        hints.append(hint("Esc", .close, priority: 3, content: content))
        return hints
    }

    private static func helperText(
        for status: OverlayInteractionStatus,
        content: AppContent.Localized
    ) -> String? {
        switch status.phase {
        case .idle:
            return status.activeScope == .labels ? content.commandBarLabelHelper : content.commandBarModeHelper(for: status.activeScope)
        case .awaitingRiskConfirmation, .failure:
            return status.message
        case .typing, .matching, .noMatches, .success:
            return nil
        }
    }

    private static func hint(
        _ key: String,
        _ action: OverlayCommandBarAction,
        priority: Int,
        content: AppContent.Localized
    ) -> OverlayKeyHint {
        OverlayKeyHint(
            key: key,
            action: content.commandBarAction(action),
            priority: priority
        )
    }
}

/// command bar를 표시할 화면 정보.
///
/// @author suho.do
/// @since 2026-07-13
struct OverlayScreenDescriptor: Equatable {
    let frame: CGRect
    let visibleFrame: CGRect
    let scaleFactor: CGFloat
}

/// command bar panel과 내부 요소의 화면 좌표 배치 결과.
///
/// @author suho.do
/// @since 2026-07-13
struct OverlayCommandBarLayout: Equatable {
    let panelFrame: CGRect
    let commandBarFrame: CGRect
    let previewFrame: CGRect?
}

/// target 화면 하단 command bar의 frame을 계산한다.
///
/// @author suho.do
/// @since 2026-07-13
struct OverlayCommandBarLayoutEngine {
    static let maximumWidth: CGFloat = 680
    static let standardHorizontalInset: CGFloat = 16
    static let narrowHorizontalInset: CGFloat = 8
    static let bottomInset: CGFloat = 16
    static let compactHeight: CGFloat = 72
    static let messageHeight: CGFloat = 88
    static let previewHeight: CGFloat = 88
    static let previewSpacing: CGFloat = 8
    static let narrowWidthThreshold: CGFloat = 392

    func makeLayout(
        visibleFrame: CGRect,
        showsWindowPreviews: Bool,
        showsMessage: Bool
    ) -> OverlayCommandBarLayout {
        let horizontalInset = visibleFrame.width < Self.narrowWidthThreshold
            ? Self.narrowHorizontalInset
            : Self.standardHorizontalInset
        let availableWidth = max(0, visibleFrame.width - horizontalInset * 2)
        let commandBarWidth = min(Self.maximumWidth, availableWidth)
        let commandBarHeight = showsMessage ? Self.messageHeight : Self.compactHeight
        let commandBarFrame = CGRect(
            x: visibleFrame.midX - commandBarWidth / 2,
            y: visibleFrame.minY + Self.bottomInset,
            width: commandBarWidth,
            height: commandBarHeight
        )
        let previewFrame = showsWindowPreviews
            ? CGRect(
                x: commandBarFrame.minX,
                y: commandBarFrame.maxY + Self.previewSpacing,
                width: commandBarFrame.width,
                height: Self.previewHeight
            )
            : nil
        let panelFrame = previewFrame.map { commandBarFrame.union($0) } ?? commandBarFrame

        return OverlayCommandBarLayout(
            panelFrame: panelFrame,
            commandBarFrame: commandBarFrame,
            previewFrame: previewFrame
        )
    }

    func screen(
        containing targetFrame: CGRect,
        in screens: [OverlayScreenDescriptor]
    ) -> OverlayScreenDescriptor {
        guard !screens.isEmpty else {
            return OverlayScreenDescriptor(
                frame: targetFrame,
                visibleFrame: targetFrame,
                scaleFactor: 1
            )
        }

        let largestIntersection = screens.map { screen in
            (screen, intersectionArea(of: targetFrame, and: screen.frame))
        }.max { lhs, rhs in
            lhs.1 < rhs.1
        }?.1 ?? 0
        let candidates = screens.filter {
            intersectionArea(of: targetFrame, and: $0.frame) == largestIntersection
        }
        let targetCenter = CGPoint(x: targetFrame.midX, y: targetFrame.midY)

        return candidates.first(where: { $0.frame.contains(targetCenter) })
            ?? candidates.first
            ?? screens[0]
    }

    private func intersectionArea(of lhs: CGRect, and rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else {
            return 0
        }

        return intersection.width * intersection.height
    }
}
