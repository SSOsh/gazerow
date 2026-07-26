import XCTest
@testable import GazeRow

/// window overview 라벨 선택과 focus 이동 테스트.
///
/// @author suho.do
/// @since 2026-07-26
final class OverlayWindowInteractionTests: XCTestCase {

    func test_select_한글자label은_즉시index를반환한다() {
        // given
        let sut = OverlayWindowLabelSelector()

        // when
        let result = sut.select(appending: "s", to: "", labels: ["A", "S", "D"])

        // then
        XCTAssertEqual(result, .exact(index: 1))
    }

    func test_select_두글자label의_prefix는_buffer를유지한다() {
        // given
        let sut = OverlayWindowLabelSelector()

        // when
        let result = sut.select(appending: "z", to: "", labels: ["ZA", "ZS"])

        // then
        XCTAssertEqual(result, .partial(buffer: "Z"))
    }

    func test_select_일치하지않거나_문자가아니면_noMatch다() {
        // given
        let sut = OverlayWindowLabelSelector()

        // when & then
        XCTAssertEqual(sut.select(appending: "x", to: "", labels: ["A", "S"]), .noMatch)
        XCTAssertEqual(sut.select(appending: " ", to: "", labels: ["A", "S"]), .noMatch)
        XCTAssertEqual(sut.select(appending: "한", to: "", labels: ["A", "S"]), .noMatch)
    }

    func test_navigation_좌우와_tab은_순환한다() {
        // given
        let sut = OverlayWindowOverviewNavigation()

        // when & then
        XCTAssertEqual(sut.index(after: .right, currentIndex: 5, itemCount: 6), 0)
        XCTAssertEqual(sut.index(after: .left, currentIndex: 0, itemCount: 6), 5)
        XCTAssertEqual(sut.index(after: .next, currentIndex: 0, itemCount: 6), 1)
        XCTAssertEqual(sut.index(after: .previous, currentIndex: 0, itemCount: 6), 5)
    }

    func test_navigation_상하는_3열grid의_같은열로이동한다() {
        // given
        let sut = OverlayWindowOverviewNavigation()

        // when & then
        XCTAssertEqual(sut.index(after: .down, currentIndex: 1, itemCount: 6), 4)
        XCTAssertEqual(sut.index(after: .up, currentIndex: 4, itemCount: 6), 1)
        XCTAssertEqual(sut.index(after: .up, currentIndex: 1, itemCount: 6), 0)
        XCTAssertEqual(sut.index(after: .down, currentIndex: 4, itemCount: 6), 5)
    }

    func test_navigation_후보가없으면_안전하게0을반환한다() {
        // given
        let sut = OverlayWindowOverviewNavigation()

        // when & then
        XCTAssertEqual(sut.index(after: .down, currentIndex: 3, itemCount: 0), 0)
    }
}
