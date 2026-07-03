import AppKit

/// 표준 윈도우 컨트롤을 실행하는 고정키 정의와 매칭 규칙.
///
/// `OverlayActivationShortcut`과 동일한 modifier 정규화 규칙을 따르며,
/// keyDown 입력이 이 단축키와 일치하면 연결된 `WindowControlAction`을 실행한다.
///
/// @author suho.do
/// @since 2026-07-02
struct WindowControlShortcut: Equatable {
    let keyCode: UInt16
    let requiredModifiers: NSEvent.ModifierFlags
    let action: WindowControlAction

    /// keyDown 입력이 이 단축키와 일치하는지 판정한다.
    ///
    /// repeat 이벤트는 오작동을 막기 위해 매칭에서 제외한다.
    func matches(_ input: OverlayActivationShortcutInput) -> Bool {
        !input.isRepeat
            && input.keyCode == keyCode
            && input.normalizedModifiers == normalizedRequiredModifiers
    }

    /// 로그/문서용 표시 이름(예: `"Control+Option+C"`).
    var displayName: String {
        var parts: [String] = []
        if requiredModifiers.contains(.control) { parts.append("Control") }
        if requiredModifiers.contains(.option) { parts.append("Option") }
        if requiredModifiers.contains(.shift) { parts.append("Shift") }
        if requiredModifiers.contains(.command) { parts.append("Command") }
        parts.append(WindowControlKeyCode.label(for: keyCode))
        return parts.joined(separator: "+")
    }

    private var normalizedRequiredModifiers: NSEvent.ModifierFlags {
        requiredModifiers.intersection(Self.controlModifierMask)
    }

    private static let controlModifierMask: NSEvent.ModifierFlags = [
        .command,
        .shift,
        .option,
        .control
    ]
}

/// window control 단축키에 사용하는 macOS hardware key code 상수.
///
/// @author suho.do
/// @since 2026-07-02
enum WindowControlKeyCode {
    static let c: UInt16 = 8
    static let m: UInt16 = 46
    static let z: UInt16 = 6

    /// 표시용 key label. 알 수 없는 code는 raw 값을 반환한다.
    static func label(for keyCode: UInt16) -> String {
        switch keyCode {
        case c:
            return "C"
        case m:
            return "M"
        case z:
            return "Z"
        default:
            return "Key(\(keyCode))"
        }
    }
}
