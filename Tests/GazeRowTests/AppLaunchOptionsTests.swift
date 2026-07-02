import XCTest
@testable import GazeRow

/// `AppLaunchOptions`의 인자 파싱을 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class AppLaunchOptionsTests: XCTestCase {

    func test_init_requestAccessibility_인자가있으면_true() {
        // given
        let arguments = ["GazeRow", "--request-accessibility"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertTrue(sut.requestsAccessibilityPermission)
    }

    func test_init_requestAccessibility_인자가없으면_false() {
        // given
        let arguments = ["GazeRow"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertFalse(sut.requestsAccessibilityPermission)
    }
}
