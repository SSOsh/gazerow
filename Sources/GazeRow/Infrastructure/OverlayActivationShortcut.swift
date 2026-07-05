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
        requiredModifiers: [.control, .option, .command]
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
        if requiredModifiers == [.control, .option, .command] {
            return "Control+Option+Command+Space"
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

/// NSEvent keyDown monitor가 activation 단축키를 어떻게 처리할지 나타내는 라우팅 결정.
///
/// overlay activation은 Carbon hotkey가 유일한 실행 경로이므로, monitor는 activation
/// 입력을 소비(consume)만 하고 `showOverlay()`를 호출하지 않는다(중복 실행 방지).
///
/// @author suho.do
/// @since 2026-07-05
enum OverlayActivationMonitorRoute: Equatable {
    /// gaze focus activation. `showGazeOverlay()`로 이어진다.
    case gaze
    /// overlay activation 입력. Carbon가 실행을 담당하므로 monitor는 소비만 한다.
    case consumeOverlayActivation
    /// activation과 무관한 입력. window control 처리로 넘긴다.
    case windowControl
}

/// keyDown 입력을 monitor 라우팅 결정으로 변환한다.
///
/// AppDelegate의 global/local monitor가 동일한 판정 규칙을 공유하도록 순수 함수로 분리한다.
/// gaze > overlay activation > window control 순으로 우선순위를 둔다.
///
/// - Parameters:
///   - input: keyDown 입력 모델.
///   - gazeMatcher: gaze activation 매칭 함수(테스트 주입용).
///   - overlayMatcher: overlay activation 매칭 함수(테스트 주입용).
/// - Returns: monitor가 수행할 라우팅 결정.
///
/// @author suho.do
/// @since 2026-07-05
func overlayActivationMonitorRoute(
    for input: OverlayActivationShortcutInput,
    gazeMatcher: (OverlayActivationShortcutInput) -> Bool = GazeActivationShortcut.matches,
    overlayMatcher: (OverlayActivationShortcutInput) -> Bool = OverlayActivationShortcut.matchesAny
) -> OverlayActivationMonitorRoute {
    if gazeMatcher(input) {
        return .gaze
    }
    if overlayMatcher(input) {
        return .consumeOverlayActivation
    }
    return .windowControl
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
