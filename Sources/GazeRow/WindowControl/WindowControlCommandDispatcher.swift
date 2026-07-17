import AppKit

/// keyDown 입력을 window control 동작으로 해석해 실행하는 dispatcher.
///
/// overlay activation shortcut과 겹치지 않는 입력만 처리하며,
/// 일치하는 단축키가 없으면 `nil`을 반환해 이벤트를 소비하지 않는다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct WindowControlCommandDispatcher {
    private let shortcutSet: WindowControlShortcutSet
    private let client: any WindowControlButtonPressing

    init(
        shortcutSet: WindowControlShortcutSet = .default,
        client: (any WindowControlButtonPressing)? = nil
    ) {
        self.shortcutSet = shortcutSet
        self.client = client ?? AXWindowControlButtonClient()
    }

    /// 입력을 해석해 일치하는 동작을 실행한다.
    ///
    /// - Returns: 처리한 경우 실행 결과, 일치하는 단축키가 없으면 `nil`.
    func handle(_ input: OverlayActivationShortcutInput) -> WindowControlResult? {
        guard let action = shortcutSet.resolve(input) else {
            return nil
        }

        return client.press(action)
    }
}
