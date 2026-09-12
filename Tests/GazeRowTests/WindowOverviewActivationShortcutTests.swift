import AppKit
import XCTest
@testable import GazeRow

/// WindowOverviewActivationShortcut 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-26
final class WindowOverviewActivationShortcutTests: XCTestCase {

    func test_matches_CommandShiftSemicolon이면_true() {
        // given
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.semicolon,
            modifiers: [.command, .shift]
        )

        // when
        let result = WindowOverviewActivationShortcut.matches(input)

        // then
        XCTAssertTrue(result)
    }

    func test_matches_modifier가다르면_false() {
        // given
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.semicolon,
            modifiers: [.control, .shift]
        )

        // when
        let result = WindowOverviewActivationShortcut.matches(input)

        // then
        XCTAssertFalse(result)
    }

    func test_matches_repeat이면_false() {
        // given
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.semicolon,
            modifiers: [.command, .shift],
            isRepeat: true
        )

        // when
        let result = WindowOverviewActivationShortcut.matches(input)

        // then
        XCTAssertFalse(result)
    }

    func test_matches_다른물리키면_false() {
        // given
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.command, .shift]
        )

        // when
        let result = WindowOverviewActivationShortcut.matches(input)

        // then
        XCTAssertFalse(result)
    }

    func test_displayName은_CommandShiftSemicolon이다() {
        // then
        XCTAssertEqual(
            WindowOverviewActivationShortcut.defaultShortcut.displayName,
            "Command+Shift+;"
        )
    }
}
