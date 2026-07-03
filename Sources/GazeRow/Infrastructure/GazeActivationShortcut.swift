import AppKit

/// gaze focus activation 단축키(Control+Shift+Space) 정의와 매칭 규칙.
///
/// overlay activation(Command+Shift+Space / Control+Option+Space)과 겹치지 않는
/// 전용 조합을 사용한다. 입력 모델은 `OverlayActivationShortcutInput`을 재사용한다.
///
/// @author suho.do
/// @since 2026-07-03
struct GazeActivationShortcut: Equatable {
    static let defaultShortcut = GazeActivationShortcut(
        keyCode: OverlayActivationKeyCode.space,
        requiredModifiers: [.control, .shift]
    )

    let keyCode: UInt16
    let requiredModifiers: NSEvent.ModifierFlags

    func matches(_ input: OverlayActivationShortcutInput) -> Bool {
        !input.isRepeat
            && input.keyCode == keyCode
            && input.normalizedModifiers == normalizedRequiredModifiers
    }

    static func matches(_ input: OverlayActivationShortcutInput) -> Bool {
        defaultShortcut.matches(input)
    }

    var displayName: String {
        if requiredModifiers == [.control, .shift] {
            return "Control+Shift+Space"
        }
        return "Space"
    }

    private var normalizedRequiredModifiers: NSEvent.ModifierFlags {
        requiredModifiers.intersection(Self.activationModifierMask)
    }

    private static let activationModifierMask: NSEvent.ModifierFlags = [
        .command,
        .shift,
        .option,
        .control
    ]
}
