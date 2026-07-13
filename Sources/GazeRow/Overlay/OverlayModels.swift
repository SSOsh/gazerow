import AppKit
import CoreGraphics

/// overlay label 배치 설정.
///
/// @author suho.do
/// @since 2026-07-02
/// overlay label 배치 전략.
///
/// @author suho.do
/// @since 2026-07-07
enum LabelPlacement: Equatable {
    /// 후보 중앙에 겹쳐 배치. 겹침·가림은 계측만 한다. (현행 기본)
    case centered
    /// 후보 모서리 바깥에 배치해 occlusion을 피하고, 겹치면 밀어내 collision을 해소한다.
    case adaptive
}

struct OverlayLayoutConfiguration: Equatable {
    let labelSize: CGSize
    let labelSpacing: CGFloat
    let edgeInset: CGFloat
    let collisionShiftLimit: Int
    let ordersLabelsSpatially: Bool
    let rowBandHeight: CGFloat
    let labelPlacement: LabelPlacement
    let labelStrategy: LabelStrategy
    let usesAdaptivePlacementForDenseLayouts: Bool
    let denseCandidateThreshold: Int

    init(
        labelSize: CGSize = CGSize(width: 32, height: 22),
        labelSpacing: CGFloat = 6,
        edgeInset: CGFloat = 4,
        collisionShiftLimit: Int = 12,
        ordersLabelsSpatially: Bool = true,
        rowBandHeight: CGFloat = 24,
        labelPlacement: LabelPlacement = .centered,
        labelStrategy: LabelStrategy = .prefixFree,
        usesAdaptivePlacementForDenseLayouts: Bool = true,
        denseCandidateThreshold: Int = 24
    ) {
        self.labelSize = labelSize
        self.labelSpacing = max(0, labelSpacing)
        self.edgeInset = max(0, edgeInset)
        self.collisionShiftLimit = max(0, collisionShiftLimit)
        self.ordersLabelsSpatially = ordersLabelsSpatially
        self.rowBandHeight = max(1, rowBandHeight)
        self.labelPlacement = labelPlacement
        self.labelStrategy = labelStrategy
        self.usesAdaptivePlacementForDenseLayouts = usesAdaptivePlacementForDenseLayouts
        self.denseCandidateThreshold = max(2, denseCandidateThreshold)
    }
}

/// overlay 표시용 display 정보.
///
/// @author suho.do
/// @since 2026-07-02
struct OverlayDisplayInfo: Equatable {
    let scaleFactor: CGFloat
    let visibleFrame: CGRect?

    var isRetina: Bool {
        scaleFactor >= 2
    }
}

/// 후보 하나에 대응하는 overlay label.
///
/// @author suho.do
/// @since 2026-07-02
struct OverlayLabel: Equatable, Identifiable {
    let id: Int
    let text: String
    let candidateFrame: CGRect
    let labelFrame: CGRect
    let anchorPoint: CGPoint

    var displayText: String {
        text.uppercased()
    }
}

/// target window overlay layout.
///
/// @author suho.do
/// @since 2026-07-02
struct OverlayLayout: Equatable {
    let targetFrame: CGRect
    let localBounds: CGRect
    let labels: [OverlayLabel]
    let metrics: OverlayLayoutMetrics
    let displayInfo: OverlayDisplayInfo
}

/// overlay 품질 계측 값.
///
/// @author suho.do
/// @since 2026-07-02
struct OverlayLayoutMetrics: Equatable {
    let labelCount: Int
    let collisionCount: Int
    let occlusionCount: Int
    let displayScaleFactor: CGFloat

    var isRetina: Bool {
        displayScaleFactor >= 2
    }
}

/// overlay 하단에 표시할 현재 입력/실행 상태.
///
/// @author suho.do
/// @since 2026-07-03
enum OverlayInteractionPhase: Equatable {
    case idle
    case typing
    case matching
    case noMatches
    case awaitingRiskConfirmation
    case success
    case failure
}

/// overlay의 현재 입력/실행 상태.
///
/// @author suho.do
/// @since 2026-07-13
struct OverlayInteractionStatus: Equatable {
    let focusedLabel: String?
    let typedLabelBuffer: String
    let queryBuffer: String
    let activeScope: QueryScope
    let pinnedScope: QueryScope?
    let matchCount: Int
    let matchIndex: Int
    let focusedDisplayName: String?
    /// elements scope에서 gaze로 element를 겨냥 중임을 나타낸다.
    /// 검색 매칭(matchCount)과 구분해 요약 문구를 분기하기 위한 플래그다.
    let isGazeTargeting: Bool
    let enterActionHint: String
    let windowMatchPreviews: [OverlayWindowMatchPreview]
    let message: String?
    let tone: Tone
    let phase: OverlayInteractionPhase
    let requiresSecondConfirm: Bool

    init(
        focusedLabel: String? = nil,
        typedLabelBuffer: String = "",
        queryBuffer: String? = nil,
        activeScope: QueryScope = .labels,
        pinnedScope: QueryScope? = nil,
        matchCount: Int = 0,
        matchIndex: Int = 0,
        focusedDisplayName: String? = nil,
        isGazeTargeting: Bool = false,
        enterActionHint: String = "click",
        windowMatchPreviews: [OverlayWindowMatchPreview] = [],
        message: String? = nil,
        tone: Tone = .neutral,
        phase: OverlayInteractionPhase = .idle,
        requiresSecondConfirm: Bool = false
    ) {
        self.focusedLabel = focusedLabel
        self.typedLabelBuffer = typedLabelBuffer
        self.queryBuffer = queryBuffer ?? typedLabelBuffer
        self.activeScope = activeScope
        self.pinnedScope = pinnedScope
        self.matchCount = max(0, matchCount)
        self.matchIndex = max(0, matchIndex)
        self.focusedDisplayName = focusedDisplayName
        self.isGazeTargeting = isGazeTargeting
        self.enterActionHint = enterActionHint
        self.windowMatchPreviews = windowMatchPreviews
        self.message = message
        self.tone = tone
        self.phase = phase
        self.requiresSecondConfirm = requiresSecondConfirm
    }

    var displayBuffer: String {
        queryBuffer.isEmpty ? typedLabelBuffer : queryBuffer
    }

    enum Tone: Equatable {
        case neutral
        case success
        case warning
        case failure
    }
}

/// windows scope 매칭 후보를 overlay에 표시하기 위한 preview.
///
/// @author suho.do
/// @since 2026-07-13
struct OverlayWindowMatchPreview: Equatable, Identifiable {
    let id: Int
    let appName: String
    let displayName: String
    let ordinal: Int
    let isFocused: Bool
    let appIcon: NSImage?

    init(
        id: Int,
        appName: String,
        displayName: String,
        ordinal: Int,
        isFocused: Bool,
        appIcon: NSImage? = nil
    ) {
        self.id = id
        self.appName = appName
        self.displayName = displayName
        self.ordinal = max(1, ordinal)
        self.isFocused = isFocused
        self.appIcon = appIcon
    }

    static func == (lhs: OverlayWindowMatchPreview, rhs: OverlayWindowMatchPreview) -> Bool {
        lhs.id == rhs.id
            && lhs.appName == rhs.appName
            && lhs.displayName == rhs.displayName
            && lhs.ordinal == rhs.ordinal
            && lhs.isFocused == rhs.isFocused
    }

    var hasAppIcon: Bool {
        appIcon != nil
    }

    var detailText: String {
        let prefix = "\(appName) — "
        if displayName.hasPrefix(prefix) {
            return String(displayName.dropFirst(prefix.count))
        }

        return displayName == appName ? "" : displayName
    }
}

/// label 개수와 candidate 개수가 맞지 않을 때의 정책.
///
/// @author suho.do
/// @since 2026-07-02
enum OverlayLabelPolicy {
    static func label(for index: Int) -> String {
        LabelGenerator().label(for: index)
    }
}
