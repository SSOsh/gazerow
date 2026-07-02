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
        case KeyCode.returnKey:
            return .dryRunConfirm
        case KeyCode.escape:
            return .closeOverlay
        case KeyCode.delete:
            return .clearLabelBuffer
        default:
            return labelCommand(from: input.charactersIgnoringModifiers)
        }
    }

    private func labelCommand(from characters: String?) -> FocusKeyboardCommand? {
        guard let character = characters?.first,
              characters?.count == 1,
              character.isLetter else {
            return nil
        }

        return .typeLabel(character)
    }
}

private enum KeyCode {
    static let tab: UInt16 = 48
    static let returnKey: UInt16 = 36
    static let escape: UInt16 = 53
    static let delete: UInt16 = 51
    static let arrowUp: UInt16 = 126
    static let arrowDown: UInt16 = 125
}
