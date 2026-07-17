import CoreGraphics
import Foundation

/// AX tree scan 설정.
///
/// @author suho.do
/// @since 2026-07-02
struct AccessibilityScanConfiguration: Equatable, Sendable {
    let maxDepth: Int
    let maxNodes: Int
    let timeout: TimeInterval

    init(
        maxDepth: Int = 32,
        maxNodes: Int = 4_000,
        timeout: TimeInterval = 1.5
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
struct AccessibilityElementSnapshot: Equatable, Sendable {
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
struct ClickableCandidate: Equatable, Sendable {
    let role: String
    let subrole: String?
    let title: String?
    let frame: CGRect
    let actions: [String]

    /// 상태바 표시용 element 이름.
    ///
    /// 우선순위(title→role→subrole→"Element {index}")는
    /// `ElementSearchIndex.displayName(for:)`(node 기반)과 정렬한다.
    /// candidate에는 value 필드가 없어 title 다음 role로 이어진다.
    /// `index`는 fallback 라벨에만 쓰이는 candidate 순번이다.
    func displayName(index: Int) -> String {
        if let title = Self.nonEmptyTrimmed(title) {
            return title
        }
        if let role = Self.nonEmptyTrimmed(role) {
            return role
        }
        if let subrole = Self.nonEmptyTrimmed(subrole) {
            return subrole
        }
        return "Element \(index)"
    }

    private static func nonEmptyTrimmed(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// AX scan 결과와 계측 값.
///
/// @author suho.do
/// @since 2026-07-02
struct AccessibilityScanResult: Equatable, Sendable {
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

/// 진행 중인 AX scan이 overlay에 전달하는 부분 후보 snapshot.
///
/// @author suho.do
/// @since 2026-07-17
struct AccessibilityScanProgress: Equatable, Sendable {
    let candidates: [ClickableCandidate]
    let nodesVisited: Int
}

/// AX scan 실패 사유.
///
/// @author suho.do
/// @since 2026-07-02
enum AccessibilityScanFailure: Error, Equatable, Sendable {
    case accessibilityPermissionDenied
    case focusedWindowUnavailable(String)
    case childrenUnavailable(String)
    case cancelled
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
