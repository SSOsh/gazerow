/// overlay keyboard 입력을 focus engine 명령으로 변환한 값.
///
/// @author suho.do
/// @since 2026-07-02
enum FocusKeyboardCommand: Equatable {
    case move(FocusMoveCommand)
    case typeLabel(Character)
    case clearLabelBuffer
    case dryRunConfirm
    case closeOverlay
}

/// AppKit key event에서 필요한 최소 값만 분리한 입력 모델.
///
/// @author suho.do
/// @since 2026-07-02
struct FocusKeyboardInput: Equatable {
    let keyCode: UInt16
    let charactersIgnoringModifiers: String?
    let isShiftPressed: Bool

    init(
        keyCode: UInt16,
        charactersIgnoringModifiers: String? = nil,
        isShiftPressed: Bool = false
    ) {
        self.keyCode = keyCode
        self.charactersIgnoringModifiers = charactersIgnoringModifiers
        self.isShiftPressed = isShiftPressed
    }
}

/// keyCode 기반 keyboard command mapper.
///
/// 실제 NSEvent 의존 없이 단위 테스트 가능하게 유지한다.
///
/// @author suho.do
/// @since 2026-07-02
struct FocusKeyboardCommandMapper {
    func command(for input: FocusKeyboardInput) -> FocusKeyboardCommand? {
        switch input.keyCode {
        case KeyCode.tab:
            return .move(input.isShiftPressed ? .previous : .next)
        case KeyCode.arrowUp:
            return .move(.up)
        case KeyCode.arrowDown:
            return .move(.down)
        case KeyCode.returnKey, KeyCode.keypadEnter:
            return .dryRunConfirm
        case KeyCode.escape:
            return .closeOverlay
        case KeyCode.delete:
            return .clearLabelBuffer
        default:
            return labelCommand(from: input)
        }
    }

    /// label 입력을 typeLabel command로 변환한다.
    ///
    /// 영문 레이아웃은 문자를 그대로 쓰고, 한글 등 비 ASCII 입력기에서는 물리
    /// keyCode를 QWERTY 알파벳으로 되돌려 같은 물리 위치가 같은 라벨로 매칭되게 한다.
    /// (예: 한글 "ㄹ"(keyCode 3) → "F", "ㅁ"(keyCode 0) → "A")
    private func labelCommand(from input: FocusKeyboardInput) -> FocusKeyboardCommand? {
        if let character = input.singleLetterCharacter {
            if character.isASCII {
                return .typeLabel(character)
            }

            if let physicalLetter = KeyCode.letter(for: input.keyCode) {
                return .typeLabel(physicalLetter)
            }

            return .typeLabel(character)
        }

        if input.charactersIgnoringModifiers?.isEmpty != false,
           let physicalLetter = KeyCode.letter(for: input.keyCode) {
            return .typeLabel(physicalLetter)
        }

        return nil
    }
}

private extension FocusKeyboardInput {
    var singleLetterCharacter: Character? {
        guard let charactersIgnoringModifiers,
              charactersIgnoringModifiers.count == 1,
              let character = charactersIgnoringModifiers.first,
              character.isLetter else {
            return nil
        }

        return character
    }
}

private enum KeyCode {
    static let tab: UInt16 = 48
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let escape: UInt16 = 53
    static let delete: UInt16 = 51
    static let arrowUp: UInt16 = 126
    static let arrowDown: UInt16 = 125

    /// 물리 keyCode에 대응하는 ANSI(QWERTY) 알파벳을 돌려준다. 매핑이 없으면 nil.
    static func letter(for keyCode: UInt16) -> Character? {
        letterByKeyCode[keyCode]
    }

    /// macOS ANSI 키보드의 알파벳 키 물리 위치 → 문자 매핑.
    private static let letterByKeyCode: [UInt16: Character] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
        38: "J", 40: "K", 45: "N", 46: "M"
    ]
}
