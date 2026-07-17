import Foundation

/// 사용자 상호작용 이벤트(민감정보 제외)의 값 타입 표현.
///
/// TICKET-008 범위. MVP 평가에 필요한 최소 로그만 담는다.
///
/// - Important: raw window title, text value 등 원문은 담지 않는다.
///   window title은 `windowTitleHash`(session salt 기반 SHA256)만 기록한다.
///   click 위험은 class 코드(문자열)만 기록하고 원문 텍스트는 금지한다.
///   click method와 target match 결과도 허용된 코드값만 기록한다.
///
/// - Note: click 로그 종류(`InteractionEventKind`)는 코덱스 `ClickModels`의
///   타입에 결합하지 않고, 자체 문자열 코드로만 정의한다(병행 개발 분리).
///
/// @author suho.do
/// @since 2026-07-02
struct InteractionEvent: Equatable {

    /// 이벤트 발생 시각.
    let timestamp: Date

    /// 이벤트 종류(민감정보 제외 페이로드 포함).
    let kind: InteractionEventKind

    /// window title의 session salt 기반 hash. 원문은 저장하지 않는다.
    /// 창 정보가 없으면 `nil`.
    let windowTitleHash: String?

    /// 완료된 click의 실행 방식 코드. 해당 없으면 `nil`.
    let clickMethod: String?

    /// 완료된 click의 대상 검증 결과 코드. 해당 없으면 `nil`.
    let targetMatchResult: String?

    init(
        timestamp: Date,
        kind: InteractionEventKind,
        windowTitleHash: String? = nil,
        clickMethod: String? = nil,
        targetMatchResult: String? = nil
    ) {
        self.timestamp = timestamp
        self.kind = kind
        self.windowTitleHash = windowTitleHash
        self.clickMethod = clickMethod
        self.targetMatchResult = targetMatchResult
    }
}

/// interaction 이벤트 종류.
///
/// method/risk는 원문이 아닌 문자열 코드만 담는다.
/// click 관련 종류는 타입만 정의하고, 실제 wiring은 TICKET-007 커밋 후로 분리한다.
///
/// @author suho.do
/// @since 2026-07-02
enum InteractionEventKind: Equatable {

    /// 포커스 대상이 바뀜. `method`는 포커스 이동 방식 코드(예: "keyboard").
    case focusChanged(method: String)

    /// label typing으로 candidate에 jump 시도. `matched`는 입력 label이
    /// 후보와 매칭됐는지(true) 아닌지(false). TICKET-006의 label jump match/miss 기록용.
    case labelJump(matched: Bool)

    /// click 시도. `risk`는 위험 class 코드(예: "safeNavigation").
    case clickAttempt(risk: String)

    /// click 완료. `risk`는 위험 class 코드, `success`는 성공 여부.
    case clickCompleted(risk: String, success: Bool)

    /// JSON Lines 직렬화에 쓰는 종류 태그.
    var typeCode: String {
        switch self {
        case .focusChanged:
            "focusChanged"
        case .labelJump:
            "labelJump"
        case .clickAttempt:
            "clickAttempt"
        case .clickCompleted:
            "clickCompleted"
        }
    }
}

/// `InteractionEvent`의 JSON Lines 직렬화용 표현.
///
/// 파일 한 줄에 하나의 JSON object로 append한다. 민감정보를 담지 않는
/// flat 구조로, 재현/평가에 필요한 최소 필드만 포함한다.
///
/// @author suho.do
/// @since 2026-07-02
struct InteractionLogRecord: Encodable, Equatable {

    /// 이벤트 발생 시각(ISO8601 문자열).
    let timestamp: String

    /// 이벤트 종류 태그.
    let type: String

    /// 포커스 이동 방식 코드. 해당 없으면 `nil`.
    let method: String?

    /// click 위험 class 코드. 해당 없으면 `nil`.
    let risk: String?

    /// click 성공 여부. 해당 없으면 `nil`.
    let success: Bool?

    /// label jump 매칭 여부. 해당 없으면 `nil`.
    let matched: Bool?

    /// 완료된 click의 실행 방식 코드. 해당 없으면 `nil`.
    let clickMethod: String?

    /// 완료된 click의 대상 검증 결과 코드. 해당 없으면 `nil`.
    let targetMatchResult: String?

    /// window title hash. 없으면 `nil`.
    let windowTitleHash: String?

    /// fractional seconds 포함 ISO8601 포맷터를 만든다.
    ///
    /// `ISO8601DateFormatter`는 non-Sendable이라 static 공유 대신 매 인코딩마다 생성한다.
    private static func makeTimestampFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    init(event: InteractionEvent) {
        self.timestamp = Self.makeTimestampFormatter().string(from: event.timestamp)
        self.type = event.kind.typeCode
        self.windowTitleHash = event.windowTitleHash
        self.clickMethod = event.clickMethod
        self.targetMatchResult = event.targetMatchResult

        switch event.kind {
        case let .focusChanged(method):
            self.method = method
            self.risk = nil
            self.success = nil
            self.matched = nil
        case let .labelJump(matched):
            self.method = nil
            self.risk = nil
            self.success = nil
            self.matched = matched
        case let .clickAttempt(risk):
            self.method = nil
            self.risk = risk
            self.success = nil
            self.matched = nil
        case let .clickCompleted(risk, success):
            self.method = nil
            self.risk = risk
            self.success = success
            self.matched = nil
        }
    }
}
