import AppKit
import XCTest
@testable import GazeRow

/// `WindowControlCommandDispatcher`의 입력 해석 → 실행 위임 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class WindowControlCommandDispatcherTests: XCTestCase {

    /// press 호출을 기록하는 fake client.
    private final class SpyButtonClient: WindowControlButtonPressing {
        private(set) var pressedActions: [WindowControlAction] = []
        var stubbedResult: WindowControlResult = .success

        func press(_ action: WindowControlAction) -> WindowControlResult {
            pressedActions.append(action)
            return stubbedResult
        }
    }

    private func makeInput(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [.control, .option]
    ) -> OverlayActivationShortcutInput {
        OverlayActivationShortcutInput(keyCode: keyCode, modifiers: modifiers)
    }

    func test_매칭되는_입력이면_해당동작을_press하고_결과반환() {
        // given
        let spy = SpyButtonClient()
        spy.stubbedResult = .success
        let sut = WindowControlCommandDispatcher(shortcutSet: .default, client: spy)

        // when
        let result = sut.handle(makeInput(keyCode: WindowControlKeyCode.c))

        // then
        XCTAssertEqual(spy.pressedActions, [.close])
        XCTAssertEqual(result, .success)
    }

    func test_matching입력_minimize도_위임() {
        // given
        let spy = SpyButtonClient()
        let sut = WindowControlCommandDispatcher(shortcutSet: .default, client: spy)

        // when
        _ = sut.handle(makeInput(keyCode: WindowControlKeyCode.m))

        // then
        XCTAssertEqual(spy.pressedActions, [.minimize])
    }

    func test_매칭되지_않는_입력이면_nil반환하고_press미호출() {
        // given
        let spy = SpyButtonClient()
        let sut = WindowControlCommandDispatcher(shortcutSet: .default, client: spy)

        // when
        let result = sut.handle(makeInput(keyCode: WindowControlKeyCode.c, modifiers: [.command]))

        // then
        XCTAssertNil(result)
        XCTAssertTrue(spy.pressedActions.isEmpty)
    }

    func test_client실패결과를_그대로_전달() {
        // given
        let spy = SpyButtonClient()
        spy.stubbedResult = .controlUnavailable
        let sut = WindowControlCommandDispatcher(shortcutSet: .default, client: spy)

        // when
        let result = sut.handle(makeInput(keyCode: WindowControlKeyCode.z))

        // then
        XCTAssertEqual(result, .controlUnavailable)
        XCTAssertEqual(spy.pressedActions, [.zoom])
    }
}
