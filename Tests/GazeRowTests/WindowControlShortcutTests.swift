import AppKit
import XCTest
@testable import GazeRow

/// `WindowControlShortcut`의 keyDown 매칭 규칙과 표시 이름 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class WindowControlShortcutTests: XCTestCase {

    private func makeSUT() -> WindowControlShortcut {
        WindowControlShortcut(
            keyCode: WindowControlKeyCode.c,
            requiredModifiers: [.control, .option],
            action: .close
        )
    }

    func test_정확히_일치하는_입력이면_matches_true() {
        // given
        let sut = makeSUT()
        let input = OverlayActivationShortcutInput(
            keyCode: WindowControlKeyCode.c,
            modifiers: [.control, .option]
        )

        // then
        XCTAssertTrue(sut.matches(input))
    }

    func test_modifier가_다르면_matches_false() {
        // given
        let sut = makeSUT()
        let input = OverlayActivationShortcutInput(
            keyCode: WindowControlKeyCode.c,
            modifiers: [.command, .shift]
        )

        // then
        XCTAssertFalse(sut.matches(input))
    }

    func test_keyCode가_다르면_matches_false() {
        // given
        let sut = makeSUT()
        let input = OverlayActivationShortcutInput(
            keyCode: WindowControlKeyCode.m,
            modifiers: [.control, .option]
        )

        // then
        XCTAssertFalse(sut.matches(input))
    }

    func test_repeat_이벤트면_matches_false() {
        // given
        let sut = makeSUT()
        let input = OverlayActivationShortcutInput(
            keyCode: WindowControlKeyCode.c,
            modifiers: [.control, .option],
            isRepeat: true
        )

        // then
        XCTAssertFalse(sut.matches(input))
    }

    func test_관계없는_modifier는_무시하고_matches() {
        // given
        // capsLock 같은 비교대상 외 modifier가 섞여도 정규화되어 매칭된다.
        let sut = makeSUT()
        let input = OverlayActivationShortcutInput(
            keyCode: WindowControlKeyCode.c,
            modifiers: [.control, .option, .capsLock]
        )

        // then
        XCTAssertTrue(sut.matches(input))
    }

    func test_displayName은_modifier와_key_조합() {
        // given
        let sut = makeSUT()

        // then
        XCTAssertEqual(sut.displayName, "Control+Option+C")
    }
}
