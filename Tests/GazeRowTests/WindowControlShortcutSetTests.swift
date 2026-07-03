import AppKit
import XCTest
@testable import GazeRow

/// `WindowControlShortcutSet`의 기본 매핑과 입력 해석 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class WindowControlShortcutSetTests: XCTestCase {

    private func makeInput(keyCode: UInt16) -> OverlayActivationShortcutInput {
        OverlayActivationShortcutInput(
            keyCode: keyCode,
            modifiers: [.control, .option]
        )
    }

    func test_기본매핑은_close_minimize_zoom_세개() {
        // given
        let sut = WindowControlShortcutSet.default

        // then
        XCTAssertEqual(sut.shortcuts.map(\.action), [.close, .minimize, .zoom])
    }

    func test_ControlOptionC는_close로_해석() {
        // given
        let sut = WindowControlShortcutSet.default

        // when
        let action = sut.resolve(makeInput(keyCode: WindowControlKeyCode.c))

        // then
        XCTAssertEqual(action, .close)
    }

    func test_ControlOptionM은_minimize로_해석() {
        // given
        let sut = WindowControlShortcutSet.default

        // when
        let action = sut.resolve(makeInput(keyCode: WindowControlKeyCode.m))

        // then
        XCTAssertEqual(action, .minimize)
    }

    func test_ControlOptionZ는_zoom으로_해석() {
        // given
        let sut = WindowControlShortcutSet.default

        // when
        let action = sut.resolve(makeInput(keyCode: WindowControlKeyCode.z))

        // then
        XCTAssertEqual(action, .zoom)
    }

    func test_매핑없는_입력이면_nil() {
        // given
        let sut = WindowControlShortcutSet.default
        let input = OverlayActivationShortcutInput(
            keyCode: WindowControlKeyCode.c,
            modifiers: [.command]
        )

        // when
        let action = sut.resolve(input)

        // then
        XCTAssertNil(action)
    }
}
