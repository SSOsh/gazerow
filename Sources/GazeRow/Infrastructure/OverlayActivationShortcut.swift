import AppKit

/// overlay activation 단축키 정의와 매칭 규칙.
///
/// @author suho.do
/// @since 2026-07-02
struct OverlayActivationShortcut: Equatable {
    static let defaultShortcut = OverlayActivationShortcut(
        keyCode: OverlayActivationKeyCode.space,
        requiredModifiers: [.command, .shift]
    )
    static let fallbackShortcut = OverlayActivationShortcut(
        keyCode: OverlayActivationKeyCode.space,
        requiredModifiers: [.control, .option]
    )
    static let defaultShortcuts = [
        defaultShortcut,
        fallbackShortcut
    ]

    let keyCode: UInt16
    let requiredModifiers: NSEvent.ModifierFlags

    func matches(_ input: OverlayActivationShortcutInput) -> Bool {
        !input.isRepeat
            && input.keyCode == keyCode
            && input.normalizedModifiers == normalizedRequiredModifiers
    }

    static func matchesAny(_ input: OverlayActivationShortcutInput) -> Bool {
        defaultShortcuts.contains { shortcut in
            shortcut.matches(input)
        }
    }

    static var activationDisplayName: String {
        defaultShortcuts.map(\.displayName).joined(separator: " / ")
    }

    var displayName: String {
        if requiredModifiers == [.command, .shift] {
            return "Command+Shift+Space"
        }
        if requiredModifiers == [.control, .option] {
            return "Control+Option+Space"
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

/// keyDown event에서 단축키 판정에 필요한 값만 분리한 입력 모델.
///
/// @author suho.do
/// @since 2026-07-02
struct OverlayActivationShortcutInput: Equatable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    let isRepeat: Bool

    init(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        isRepeat: Bool = false
    ) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.isRepeat = isRepeat
    }

    init(event: NSEvent) {
        self.init(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags,
            isRepeat: event.isARepeat
        )
    }

    var normalizedModifiers: NSEvent.ModifierFlags {
        modifiers.intersection([
            .command,
            .shift,
            .option,
            .control
        ])
    }
}

/// macOS hardware key code 상수.
///
/// @author suho.do
/// @since 2026-07-02
enum OverlayActivationKeyCode {
    static let space: UInt16 = 49
}
