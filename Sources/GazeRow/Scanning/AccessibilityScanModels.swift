import CoreGraphics
import Foundation

/// AX tree scan 설정.
///
/// @author suho.do
/// @since 2026-07-02
struct AccessibilityScanConfiguration: Equatable {
    let maxDepth: Int
    let maxNodes: Int
    let timeout: TimeInterval

    init(
        maxDepth: Int = 32,
        maxNodes: Int = 2_000,
        timeout: TimeInterval = 1.0
    ) {
        self.maxDepth = max(0, maxDepth)
        self.maxNodes = max(1, maxNodes)
        self.timeout = max(0, timeout)
    }
}

/// AX element runtime snapshot.
///
/// title/value/help는 후보 분류와 런타임 debug 표시 용도다.
/// 기본 로그/파일 저장 대상으로 쓰지 않는다.
///
/// @author suho.do
/// @since 2026-07-02
struct AccessibilityElementSnapshot: Equatable {
    let role: String?
    let subrole: String?
    let title: String?
    let value: String?
    let help: String?
    let frame: CGRect?
    let actions: [String]

    var isSecureField: Bool {
        role == AccessibilityRole.secureTextField
    }
}

/// overlay label 대상 clickable candidate.
///
/// @author suho.do
/// @since 2026-07-02
struct ClickableCandidate: Equatable {
    let role: String
    let subrole: String?
    let title: String?
    let frame: CGRect
    let actions: [String]
}

/// AX scan 결과와 계측 값.
///
/// @author suho.do
/// @since 2026-07-02
struct AccessibilityScanResult: Equatable {
    let candidates: [ClickableCandidate]
    let nodesVisited: Int
    let scanDuration: TimeInterval
    let didHitDepthLimit: Bool
    let didHitNodeLimit: Bool
    let didTimeout: Bool
    let failedChildReadCount: Int

    var candidateCount: Int {
        candidates.count
    }
}

/// AX scan 실패 사유.
///
/// @author suho.do
/// @since 2026-07-02
enum AccessibilityScanFailure: Error, Equatable {
    case accessibilityPermissionDenied
    case focusedWindowUnavailable(String)
    case childrenUnavailable(String)
}

/// AX role/action 문자열 상수.
///
/// @author suho.do
/// @since 2026-07-02
enum AccessibilityRole {
    static let button = "AXButton"
    static let cell = "AXCell"
    static let checkBox = "AXCheckBox"
    static let comboBox = "AXComboBox"
    static let disclosureTriangle = "AXDisclosureTriangle"
    static let image = "AXImage"
    static let link = "AXLink"
    static let menuButton = "AXMenuButton"
    static let popUpButton = "AXPopUpButton"
    static let radioButton = "AXRadioButton"
    static let row = "AXRow"
    static let searchField = "AXSearchField"
    static let secureTextField = "AXSecureTextField"
    static let slider = "AXSlider"
    static let tabGroup = "AXTabGroup"
    static let textArea = "AXTextArea"
    static let textField = "AXTextField"
}

/// AX action 문자열 상수.
///
/// @author suho.do
/// @since 2026-07-02
enum AccessibilityAction {
    static let press = "AXPress"
    static let confirm = "AXConfirm"
    static let open = "AXOpen"
    static let showDefaultUI = "AXShowDefaultUI"
    static let setValue = "AXSetValue"
    static let increment = "AXIncrement"
    static let decrement = "AXDecrement"
}
