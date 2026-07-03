import AppKit

/// window control 고정키 묶음과 입력 → 동작 해석기.
///
/// 기본 매핑은 시스템/앱 단축키와 충돌이 적은 `Control+Option` 조합을 쓴다.
/// - `Control+Option+C` → close
/// - `Control+Option+M` → minimize
/// - `Control+Option+Z` → zoom
///
/// @author suho.do
/// @since 2026-07-02
struct WindowControlShortcutSet: Equatable {
    let shortcuts: [WindowControlShortcut]

    /// MVP 기본 매핑.
    static let `default` = WindowControlShortcutSet(shortcuts: [
        WindowControlShortcut(
            keyCode: WindowControlKeyCode.c,
            requiredModifiers: [.control, .option],
            action: .close
        ),
        WindowControlShortcut(
            keyCode: WindowControlKeyCode.m,
            requiredModifiers: [.control, .option],
            action: .minimize
        ),
        WindowControlShortcut(
            keyCode: WindowControlKeyCode.z,
            requiredModifiers: [.control, .option],
            action: .zoom
        )
    ])

    /// keyDown 입력에 일치하는 첫 동작을 반환한다. 일치가 없으면 `nil`.
    func resolve(_ input: OverlayActivationShortcutInput) -> WindowControlAction? {
        shortcuts.first { $0.matches(input) }?.action
    }
}
