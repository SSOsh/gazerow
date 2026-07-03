import AppKit
import XCTest
@testable import GazeRow

/// `GazeActivationShortcut` 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeActivationShortcutTests: XCTestCase {

    func test_matches_ControlShiftSpace이면_true() {
        // given
        let sut = GazeActivationShortcut.defaultShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.control, .shift]
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertTrue(result)
    }

    func test_matches_capsLock은_무시() {
        // given
        let sut = GazeActivationShortcut.defaultShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.control, .shift, .capsLock]
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertTrue(result)
    }

    func test_matches_CommandShiftSpace은_false() {
        // given
        let sut = GazeActivationShortcut.defaultShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.command, .shift]
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertFalse(result)
    }

    func test_matches_control만_있으면_false() {
        // given
        let sut = GazeActivationShortcut.defaultShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.control]
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertFalse(result)
    }

    func test_matches_repeat_event이면_false() {
        // given
        let sut = GazeActivationShortcut.defaultShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.control, .shift],
            isRepeat: true
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertFalse(result)
    }

    func test_matches_space가_아니면_false() {
        // given
        let sut = GazeActivationShortcut.defaultShortcut
        let input = OverlayActivationShortcutInput(
            keyCode: 36,
            modifiers: [.control, .shift]
        )

        // when
        let result = sut.matches(input)

        // then
        XCTAssertFalse(result)
    }

    func test_static_matches는_기본_단축키로_판정() {
        // given
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.control, .shift]
        )

        // when
        let result = GazeActivationShortcut.matches(input)

        // then
        XCTAssertTrue(result)
    }

    func test_displayName은_사용자_표시용_문구를_반환() {
        // given
        let sut = GazeActivationShortcut.defaultShortcut

        // when
        let result = sut.displayName

        // then
        XCTAssertEqual(result, "Control+Shift+Space")
    }

    func test_overlay_단축키와_겹치지_않는다() {
        // given: gaze 조합
        let gazeInput = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.control, .shift]
        )

        // then: overlay 매처는 gaze 조합을 잡지 않는다
        XCTAssertFalse(OverlayActivationShortcut.matchesAny(gazeInput))
        XCTAssertTrue(GazeActivationShortcut.matches(gazeInput))
    }
}
