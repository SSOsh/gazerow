import AppKit
import XCTest
@testable import GazeRow

/// OverlayActivationShortcut 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class OverlayActivationShortcutTests: XCTestCase {

    func test_matches_CommandShiftSpace이면_true() {
        // given
        let sut = OverlayActivationShortcut.defaultShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.command, .shift]
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertTrue(result)
    }

    func test_matches_ControlOptionSpace이면_true() {
        // given
        let sut = OverlayActivationShortcut.fallbackShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.control, .option]
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertTrue(result)
    }

    func test_matchesAny는_기본_또는_보조_단축키이면_true() {
        // given
        let defaultInput = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.command, .shift]
        )
        let fallbackInput = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.control, .option]
        )

        // when
        let defaultResult = OverlayActivationShortcut.matchesAny(defaultInput)
        let fallbackResult = OverlayActivationShortcut.matchesAny(fallbackInput)

        // then
        XCTAssertTrue(defaultResult)
        XCTAssertTrue(fallbackResult)
    }

    func test_matches_capsLock은_무시() {
        // given
        let sut = OverlayActivationShortcut.defaultShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.command, .shift, .capsLock]
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertTrue(result)
    }

    func test_matches_shift가_없으면_false() {
        // given
        let sut = OverlayActivationShortcut.defaultShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.command]
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertFalse(result)
    }

    func test_matches_option이_추가되면_false() {
        // given
        let sut = OverlayActivationShortcut.defaultShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.command, .shift, .option]
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertFalse(result)
    }

    func test_matches_repeat_event이면_false() {
        // given
        let sut = OverlayActivationShortcut.defaultShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.command, .shift],
            isRepeat: true
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertFalse(result)
    }

    func test_matches_space가_아니면_false() {
        // given
        let sut = OverlayActivationShortcut.defaultShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: 36,
            modifiers: [.command, .shift]
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertFalse(result)
    }

    func test_displayName은_사용자_표시용_문구를_반환() {
        // given
        let sut = OverlayActivationShortcut.defaultShortcut

        // when
        let result = sut.displayName

        // then
        XCTAssertEqual(result, "Command+Shift+Space")
    }

    func test_activationDisplayName은_기본과_보조_단축키를_함께_반환() {
        // when
        let result = OverlayActivationShortcut.activationDisplayName

        // then
        XCTAssertEqual(result, "Command+Shift+Space / Control+Option+Space")
    }
}
