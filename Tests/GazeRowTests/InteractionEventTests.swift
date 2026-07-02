import XCTest
@testable import GazeRow

/// `InteractionEvent` → `InteractionLogRecord` 직렬화 스키마 단위 테스트.
///
/// 각 이벤트 종류가 올바른 type 태그와 페이로드 필드로 매핑되는지,
/// 민감정보(원문 title 등)가 포함되지 않는지 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class InteractionEventTests: XCTestCase {

    /// store와 동일한 옵션의 인코더로 record를 JSON 문자열로 만든다.
    private func encodeToJSON(_ record: InteractionLogRecord) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(record)
        return String(decoding: data, as: UTF8.self)
    }

    private func makeEvent(_ kind: InteractionEventKind, hash: String? = nil) -> InteractionEvent {
        InteractionEvent(
            timestamp: Date(timeIntervalSince1970: 0),
            kind: kind,
            windowTitleHash: hash
        )
    }

    func test_focusChanged_method만_채움() {
        // given
        let event = makeEvent(.focusChanged(method: "keyboard"))

        // when
        let record = InteractionLogRecord(event: event)

        // then
        XCTAssertEqual(record.type, "focusChanged")
        XCTAssertEqual(record.method, "keyboard")
        XCTAssertNil(record.risk)
        XCTAssertNil(record.success)
        XCTAssertNil(record.matched)
    }

    func test_labelJump_matched_true() {
        // given
        let event = makeEvent(.labelJump(matched: true))

        // when
        let record = InteractionLogRecord(event: event)

        // then
        XCTAssertEqual(record.type, "labelJump")
        XCTAssertEqual(record.matched, true)
        XCTAssertNil(record.method)
        XCTAssertNil(record.risk)
        XCTAssertNil(record.success)
    }

    func test_labelJump_matched_false() {
        // given
        let event = makeEvent(.labelJump(matched: false))

        // when
        let record = InteractionLogRecord(event: event)

        // then
        XCTAssertEqual(record.type, "labelJump")
        XCTAssertEqual(record.matched, false)
    }

    func test_clickAttempt_risk만_채움() {
        // given
        let event = makeEvent(.clickAttempt(risk: "safeNavigation"))

        // when
        let record = InteractionLogRecord(event: event)

        // then
        XCTAssertEqual(record.type, "clickAttempt")
        XCTAssertEqual(record.risk, "safeNavigation")
        XCTAssertNil(record.method)
        XCTAssertNil(record.success)
        XCTAssertNil(record.matched)
    }

    func test_clickCompleted_risk와_success_채움() {
        // given
        let event = makeEvent(.clickCompleted(risk: "destructive", success: false))

        // when
        let record = InteractionLogRecord(event: event)

        // then
        XCTAssertEqual(record.type, "clickCompleted")
        XCTAssertEqual(record.risk, "destructive")
        XCTAssertEqual(record.success, false)
        XCTAssertNil(record.matched)
    }

    func test_windowTitleHash_전달() {
        // given
        let event = makeEvent(.focusChanged(method: "keyboard"), hash: "deadbeef")

        // when
        let record = InteractionLogRecord(event: event)

        // then
        XCTAssertEqual(record.windowTitleHash, "deadbeef")
    }

    func test_labelJump_JSON에_matched포함_원문없음() throws {
        // given
        let event = makeEvent(.labelJump(matched: true), hash: "abc123")

        // when
        let json = try encodeToJSON(InteractionLogRecord(event: event))

        // then
        XCTAssertTrue(json.contains("\"type\":\"labelJump\""))
        XCTAssertTrue(json.contains("\"matched\":true"))
        XCTAssertTrue(json.contains("\"windowTitleHash\":\"abc123\""))
        // 관계없는 페이로드 키는 직렬화되지 않아야 한다(Encodable nil 생략).
        XCTAssertFalse(json.contains("\"risk\""))
        XCTAssertFalse(json.contains("\"method\""))
        XCTAssertFalse(json.contains("\"success\""))
    }

    func test_typeCode_모든종류_구분() {
        // given & when & then
        XCTAssertEqual(InteractionEventKind.focusChanged(method: "keyboard").typeCode, "focusChanged")
        XCTAssertEqual(InteractionEventKind.labelJump(matched: true).typeCode, "labelJump")
        XCTAssertEqual(InteractionEventKind.clickAttempt(risk: "x").typeCode, "clickAttempt")
        XCTAssertEqual(InteractionEventKind.clickCompleted(risk: "x", success: true).typeCode, "clickCompleted")
    }
}
