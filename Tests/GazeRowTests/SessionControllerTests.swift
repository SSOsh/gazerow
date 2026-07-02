import XCTest
@testable import GazeRow

/// `SessionController`의 kill switch 상태 전이 단위 테스트.
///
/// 싱글톤(`shared`) 대신 격리된 인스턴스를 생성해 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class SessionControllerTests: XCTestCase {

    func test_초기값_기본_활성() {
        // given
        let sut = SessionController()

        // then
        XCTAssertTrue(sut.isEnabled)
    }

    func test_초기값_비활성_주입() {
        // given
        let sut = SessionController(isEnabled: false)

        // then
        XCTAssertFalse(sut.isEnabled)
    }

    func test_disable_비활성으로_전환() {
        // given
        let sut = SessionController(isEnabled: true)

        // when
        sut.disable()

        // then
        XCTAssertFalse(sut.isEnabled)
    }

    func test_enable_활성으로_전환() {
        // given
        let sut = SessionController(isEnabled: false)

        // when
        sut.enable()

        // then
        XCTAssertTrue(sut.isEnabled)
    }

    func test_toggle_상태_반전() {
        // given
        let sut = SessionController(isEnabled: true)

        // when
        sut.toggle()
        // then
        XCTAssertFalse(sut.isEnabled)

        // when
        sut.toggle()
        // then
        XCTAssertTrue(sut.isEnabled)
    }
}
