import ApplicationServices
import XCTest
@testable import GazeRow

/// `WindowControlAction`의 AX 버튼 attribute 매핑과 표시값 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class WindowControlActionTests: XCTestCase {

    func test_close는_AXCloseButton에_매핑() {
        // then
        XCTAssertEqual(WindowControlAction.close.axButtonAttribute, kAXCloseButtonAttribute as String)
    }

    func test_minimize는_AXMinimizeButton에_매핑() {
        // then
        XCTAssertEqual(WindowControlAction.minimize.axButtonAttribute, kAXMinimizeButtonAttribute as String)
    }

    func test_zoom은_AXZoomButton에_매핑() {
        // then
        XCTAssertEqual(WindowControlAction.zoom.axButtonAttribute, kAXZoomButtonAttribute as String)
    }

    func test_logCode는_소문자_식별자() {
        // then
        XCTAssertEqual(WindowControlAction.close.logCode, "close")
        XCTAssertEqual(WindowControlAction.minimize.logCode, "minimize")
        XCTAssertEqual(WindowControlAction.zoom.logCode, "zoom")
    }

    func test_allCases는_세가지_동작() {
        // then
        XCTAssertEqual(WindowControlAction.allCases, [.close, .minimize, .zoom])
    }
}
