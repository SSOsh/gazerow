import XCTest
@testable import GazeRow

/// `SessionSalt`의 값 주입과 기본 랜덤 생성 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class SessionSaltTests: XCTestCase {

    func test_value주입시_그대로_저장() {
        // given
        let salt = SessionSalt(value: "fixed-salt")

        // then
        XCTAssertEqual(salt.value, "fixed-salt")
    }

    func test_기본init은_비어있지_않은_값() {
        // given
        let salt = SessionSalt()

        // then
        XCTAssertFalse(salt.value.isEmpty)
    }

    func test_기본init은_매번_다른값() {
        // given
        let first = SessionSalt()
        let second = SessionSalt()

        // then
        XCTAssertNotEqual(first.value, second.value)
    }

    func test_같은value면_Equatable_동등() {
        // given
        let a = SessionSalt(value: "same")
        let b = SessionSalt(value: "same")

        // then
        XCTAssertEqual(a, b)
    }

    func test_다른value면_Equatable_비동등() {
        // given
        let a = SessionSalt(value: "a")
        let b = SessionSalt(value: "b")

        // then
        XCTAssertNotEqual(a, b)
    }
}
