import CoreGraphics

/// click 실행 정책.
///
/// 좌표 fallback은 오클릭 리스크 때문에 기본 비활성이다.
/// 위험 action의 2단계 확인(second confirm)은 기본 비활성이며, 위험 버튼도 1회
/// 확인(Enter)으로 실행한다. 필요 시 명시적으로 켤 수 있다.
///
/// @author suho.do
/// @since 2026-07-02
struct ClickExecutionConfiguration: Equatable {
    let isCoordinateFallbackEnabled: Bool
    let requiresSecondConfirmForRiskyAction: Bool
    let prefersCoordinateClickForUntitledSmallButtons: Bool

    init(
        isCoordinateFallbackEnabled: Bool = false,
        requiresSecondConfirmForRiskyAction: Bool = false,
        prefersCoordinateClickForUntitledSmallButtons: Bool = false
    ) {
        self.isCoordinateFallbackEnabled = isCoordinateFallbackEnabled
        self.requiresSecondConfirmForRiskyAction = requiresSecondConfirmForRiskyAction
        self.prefersCoordinateClickForUntitledSmallButtons = prefersCoordinateClickForUntitledSmallButtons
    }

    static let overlayConfirmedClick = ClickExecutionConfiguration(
        isCoordinateFallbackEnabled: true,
        requiresSecondConfirmForRiskyAction: false,
        prefersCoordinateClickForUntitledSmallButtons: true
    )
}

/// click 대상.
///
/// title은 런타임 risk 분류에만 사용하고, 로그/파일 저장 대상이 아니다.
///
/// @author suho.do
/// @since 2026-07-02
struct ClickTarget<Element> {
    let element: Element
    let role: String
    let subrole: String?
    let title: String?
    let frame: CGRect
    let actions: [String]

    init(
        element: Element,
        role: String,
        subrole: String? = nil,
        title: String? = nil,
        frame: CGRect,
        actions: [String]
    ) {
        self.element = element
        self.role = role
        self.subrole = subrole
        self.title = title
        self.frame = frame
        self.actions = actions
    }

    var centerPoint: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}

/// click 실행 방식.
///
/// @author suho.do
/// @since 2026-07-02
enum ClickExecutionMethod: Equatable {
    case axPress
    case accessibilityAction(String)
    case coordinateFallback
}

/// action risk class.
///
/// @author suho.do
/// @since 2026-07-02
enum ClickRiskClass: Equatable {
    case safeNavigation
    case stateChange
    case destructive
    case externalEffect
    case unknownRisk

    var requiresSecondConfirm: Bool {
        switch self {
        case .destructive, .externalEffect, .unknownRisk:
            true
        case .safeNavigation, .stateChange:
            false
        }
    }
}

/// click 실행 실패 사유.
///
/// @author suho.do
/// @since 2026-07-02
enum ClickExecutionFailure: Error, Equatable {
    case missingPressAction
    case secondConfirmRequired(riskClass: ClickRiskClass)
    case axPressFailed(reason: String)
    case coordinateFallbackDisabled(axFailureReason: String)
    case coordinateFallbackFailed(reason: String)
}

/// low-level click client 실행 결과.
///
/// @author suho.do
/// @since 2026-07-02
enum ClickClientResult: Equatable {
    case success
    case failure(String)
}

/// click 실행 결과.
///
/// @author suho.do
/// @since 2026-07-02
struct ClickExecutionSuccess: Equatable {
    let method: ClickExecutionMethod
    let riskClass: ClickRiskClass
    let fallbackUsed: Bool
}

/// click 실행 요청.
///
/// @author suho.do
/// @since 2026-07-02
struct ClickExecutionRequest<Element> {
    let target: ClickTarget<Element>
    let isSecondConfirmProvided: Bool

    init(target: ClickTarget<Element>, isSecondConfirmProvided: Bool = false) {
        self.target = target
        self.isSecondConfirmProvided = isSecondConfirmProvided
    }
}
