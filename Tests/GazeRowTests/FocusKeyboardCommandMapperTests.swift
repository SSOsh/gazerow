import XCTest
@testable import GazeRow

/// FocusKeyboardCommandMapper 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class FocusKeyboardCommandMapperTests: XCTestCase {

    func test_tab은_next_명령으로_변환() {
        // given
        let sut = FocusKeyboardCommandMapper()

        // when
        let command = sut.command(for: FocusKeyboardInput(keyCode: 48))

        // then
        XCTAssertEqual(command, .move(.next))
    }

    func test_shiftTab은_previous_명령으로_변환() {
        // given
        let sut = FocusKeyboardCommandMapper()

        // when
        let command = sut.command(
            for: FocusKeyboardInput(keyCode: 48, isShiftPressed: true)
        )

        // then
        XCTAssertEqual(command, .move(.previous))
    }

    func test_arrowUpDown은_수직이동_명령으로_변환() {
        // given
        let sut = FocusKeyboardCommandMapper()

        // when & then
        XCTAssertEqual(
            sut.command(for: FocusKeyboardInput(keyCode: 126)),
            .move(.up)
        )
        XCTAssertEqual(
            sut.command(for: FocusKeyboardInput(keyCode: 125)),
            .move(.down)
        )
    }

    func test_return은_dryRunConfirm으로_변환() {
        // given
        let sut = FocusKeyboardCommandMapper()

        // when
        let command = sut.command(for: FocusKeyboardInput(keyCode: 36))

        // then
        XCTAssertEqual(command, .dryRunConfirm)
    }

    func test_escape는_closeOverlay로_변환() {
        // given
        let sut = FocusKeyboardCommandMapper()

        // when
        let command = sut.command(for: FocusKeyboardInput(keyCode: 53))

        // then
        XCTAssertEqual(command, .closeOverlay)
    }

    func test_letter는_typeLabel로_변환() {
        // given
        let sut = FocusKeyboardCommandMapper()

        // when
        let command = sut.command(
            for: FocusKeyboardInput(keyCode: 0, charactersIgnoringModifiers: "a")
        )

        // then
        XCTAssertEqual(command, .typeLabel("a"))
    }

    func test_letter가_아닌_문자는_무시() {
        // given
        let sut = FocusKeyboardCommandMapper()

        // when
        let command = sut.command(
            for: FocusKeyboardInput(keyCode: 0, charactersIgnoringModifiers: "1")
        )

        // then
        XCTAssertNil(command)
    }
}
