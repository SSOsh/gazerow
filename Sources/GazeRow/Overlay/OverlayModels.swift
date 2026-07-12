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
struct OverlayInteractionStatus: Equatable {
    let focusedLabel: String?
    let typedLabelBuffer: String
    let queryBuffer: String
    let activeScope: QueryScope
    let pinnedScope: QueryScope?
    let matchCount: Int
    let matchIndex: Int
    let focusedDisplayName: String?
    let enterActionHint: String
    let message: String?
    let tone: Tone

    init(
        focusedLabel: String? = nil,
        typedLabelBuffer: String = "",
        queryBuffer: String? = nil,
        activeScope: QueryScope = .labels,
        pinnedScope: QueryScope? = nil,
        matchCount: Int = 0,
        matchIndex: Int = 0,
        focusedDisplayName: String? = nil,
        enterActionHint: String = "click",
        message: String? = nil,
        tone: Tone = .neutral
    ) {
        self.focusedLabel = focusedLabel
        self.typedLabelBuffer = typedLabelBuffer
        self.queryBuffer = queryBuffer ?? typedLabelBuffer
        self.activeScope = activeScope
        self.pinnedScope = pinnedScope
        self.matchCount = max(0, matchCount)
        self.matchIndex = max(0, matchIndex)
        self.focusedDisplayName = focusedDisplayName
        self.enterActionHint = enterActionHint
        self.message = message
        self.tone = tone
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

/// overlay 상태 바의 표시 문구와 배치 계산.
///
/// @author suho.do
/// @since 2026-07-10
struct OverlayStatusPresentation: Equatable {
    static let maxWidth: CGFloat = 300
    static let horizontalInset: CGFloat = 8
    static let bottomMargin: CGFloat = 32
    static let minimumCenterPadding: CGFloat = 18

    let primaryText: String
    let helperText: String
    let focusedLabel: String?

    init(status: OverlayInteractionStatus) {
        self.primaryText = Self.primaryText(for: status)
        self.helperText = "Return: click / Esc: close"
        self.focusedLabel = status.focusedLabel
    }

    static func width(in bounds: CGRect) -> CGFloat {
        max(0, min(bounds.width - horizontalInset * 2, maxWidth))
    }

    static func center(in bounds: CGRect) -> CGPoint {
        let minY = bounds.minY + minimumCenterPadding
        let maxY = bounds.maxY - minimumCenterPadding
        let preferredY = bounds.maxY - bottomMargin
        let y = maxY < minY ? bounds.midY : min(max(preferredY, minY), maxY)

        return CGPoint(x: bounds.midX, y: y)
    }

    private static func primaryText(for status: OverlayInteractionStatus) -> String {
        if let message = status.message {
            return message
        }

        if !status.typedLabelBuffer.isEmpty {
            return "Typing \(status.typedLabelBuffer)"
        }

        return "Ready"
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
