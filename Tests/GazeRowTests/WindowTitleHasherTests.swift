import XCTest
@testable import GazeRow

/// `WindowTitleHasher`의 salt 기반 hash 동작 단위 테스트.
///
/// raw title을 저장하지 않고, salt에 따라 hash가 달라지는지 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class WindowTitleHasherTests: XCTestCase {

    func test_동일salt와title이면_동일hash() {
        // given
        let salt = SessionSalt(value: "fixed-salt")
        let sut = WindowTitleHasher(salt: salt)

        // when
        let first = sut.hash("Untitled Window")
        let second = sut.hash("Untitled Window")

        // then
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }

    func test_다른salt면_다른hash() {
        // given
        let title = "Untitled Window"
        let hasherA = WindowTitleHasher(salt: SessionSalt(value: "salt-a"))
        let hasherB = WindowTitleHasher(salt: SessionSalt(value: "salt-b"))

        // when
        let hashA = hasherA.hash(title)
        let hashB = hasherB.hash(title)

        // then
        XCTAssertNotNil(hashA)
        XCTAssertNotNil(hashB)
        XCTAssertNotEqual(hashA, hashB)
    }

    func test_hash는_원문과_다르다() {
        // given
        let title = "Secret Document"
        let sut = WindowTitleHasher(salt: SessionSalt(value: "salt"))

        // when
        let hashed = sut.hash(title)

        // then
        XCTAssertNotNil(hashed)
        XCTAssertNotEqual(hashed, title)
        XCTAssertFalse(hashed!.contains(title))
    }

    func test_nil_title이면_nil반환() {
        // given
        let sut = WindowTitleHasher(salt: SessionSalt(value: "salt"))

        // when
        let hashed = sut.hash(nil)

        // then
        XCTAssertNil(hashed)
    }

    func test_빈_title이면_nil반환() {
        // given
        let sut = WindowTitleHasher(salt: SessionSalt(value: "salt"))

        // when
        let hashed = sut.hash("")

        // then
        XCTAssertNil(hashed)
    }
}
