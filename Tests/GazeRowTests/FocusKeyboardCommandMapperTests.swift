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

    func test_keypadEnter는_dryRunConfirm으로_변환() {
        // given
        let sut = FocusKeyboardCommandMapper()

        // when
        let command = sut.command(for: FocusKeyboardInput(keyCode: 76))

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

    func test_한글_ㄹ은_물리위치_F로_변환() {
        // given: 한글 "ㄹ"은 QWERTY "F"와 같은 물리 키(keyCode 3).
        let sut = FocusKeyboardCommandMapper()

        // when
        let command = sut.command(
            for: FocusKeyboardInput(keyCode: 3, charactersIgnoringModifiers: "ㄹ")
        )

        // then
        XCTAssertEqual(command, .typeLabel("F"))
    }

    func test_한글_ㅁ은_물리위치_A로_변환() {
        // given: 한글 "ㅁ"은 QWERTY "A"와 같은 물리 키(keyCode 0).
        let sut = FocusKeyboardCommandMapper()

        // when
        let command = sut.command(
            for: FocusKeyboardInput(keyCode: 0, charactersIgnoringModifiers: "ㅁ")
        )

        // then
        XCTAssertEqual(command, .typeLabel("A"))
    }

    func test_한글_ㄷ은_물리위치_E로_변환() {
        // given: 한글 "ㄷ"은 QWERTY "E"와 같은 물리 키(keyCode 14).
        let sut = FocusKeyboardCommandMapper()

        // when
        let command = sut.command(
            for: FocusKeyboardInput(keyCode: 14, charactersIgnoringModifiers: "ㄷ")
        )

        // then
        XCTAssertEqual(command, .typeLabel("E"))
    }

    func test_한글IME가_문자없이_keyCode만_주면_물리위치_E로_변환() {
        // given: 한글 조합 중 AppKit 이벤트가 문자 없이 E 위치 keyCode만 줄 수 있다.
        let sut = FocusKeyboardCommandMapper()

        // when
        let command = sut.command(
            for: FocusKeyboardInput(keyCode: 14, charactersIgnoringModifiers: nil)
        )

        // then
        XCTAssertEqual(command, .typeLabel("E"))
    }

    func test_한글IME가_빈문자열과_keyCode를_주면_물리위치_E로_변환() {
        // given
        let sut = FocusKeyboardCommandMapper()

        // when
        let command = sut.command(
            for: FocusKeyboardInput(keyCode: 14, charactersIgnoringModifiers: "")
        )

        // then
        XCTAssertEqual(command, .typeLabel("E"))
    }

    func test_영문_letter는_keyCode와_무관하게_문자그대로() {
        // given: ASCII 문자는 keyCode 매핑보다 문자를 우선한다(Dvorak 등 보호).
        let sut = FocusKeyboardCommandMapper()

        // when: keyCode 3(F 위치)이지만 문자가 "j"이면 "j"로.
        let command = sut.command(
            for: FocusKeyboardInput(keyCode: 3, charactersIgnoringModifiers: "j")
        )

        // then
        XCTAssertEqual(command, .typeLabel("j"))
    }

    func test_비ASCII_문자에_매핑없는_keyCode면_문자유지() {
        // given: letter이지만 ASCII 아니고 keyCode 매핑도 없는 경우 문자를 그대로 둔다.
        let sut = FocusKeyboardCommandMapper()

        // when: keyCode 999는 매핑 테이블에 없음.
        let command = sut.command(
            for: FocusKeyboardInput(keyCode: 999, charactersIgnoringModifiers: "ㅎ")
        )

        // then
        XCTAssertEqual(command, .typeLabel("ㅎ"))
    }
}
