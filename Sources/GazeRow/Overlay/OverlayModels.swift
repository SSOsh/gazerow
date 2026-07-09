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

    init(
        labelSize: CGSize = CGSize(width: 32, height: 22),
        labelSpacing: CGFloat = 6,
        edgeInset: CGFloat = 4,
        collisionShiftLimit: Int = 12,
        ordersLabelsSpatially: Bool = true,
        rowBandHeight: CGFloat = 24,
        labelPlacement: LabelPlacement = .centered,
        labelStrategy: LabelStrategy = .prefixFree
    ) {
        self.labelSize = labelSize
        self.labelSpacing = max(0, labelSpacing)
        self.edgeInset = max(0, edgeInset)
        self.collisionShiftLimit = max(0, collisionShiftLimit)
        self.ordersLabelsSpatially = ordersLabelsSpatially
        self.rowBandHeight = max(1, rowBandHeight)
        self.labelPlacement = labelPlacement
        self.labelStrategy = labelStrategy
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
    let message: String?
    let tone: Tone

    init(
        focusedLabel: String? = nil,
        typedLabelBuffer: String = "",
        message: String? = nil,
        tone: Tone = .neutral
    ) {
        self.focusedLabel = focusedLabel
        self.typedLabelBuffer = typedLabelBuffer
        self.message = message
        self.tone = tone
    }

    enum Tone: Equatable {
        case neutral
        case success
        case warning
        case failure
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
