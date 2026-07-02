import SwiftUI

/// GazeRow 앱 진입점.
///
/// 메뉴바 utility로 동작하며, 시작 시 큰 main window를 띄우지 않는다.
/// Settings window는 사용자가 메뉴바에서 열 때만 표시한다.
///
/// - Note: TICKET-001 범위. 권한 요청, AX 조회, overlay, hotkey, click은 포함하지 않는다.
///
/// @author suho.do
/// @since 2026-07-02
@main
struct GazeRowApp: App {
    /// AppKit lifecycle과 status item을 관리하는 delegate.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 메뉴바 앱이므로 기본 WindowGroup 대신 Settings scene만 둔다.
        // Settings scene은 status item 메뉴 또는 Cmd+, 로 열린다.
        Settings {
            SettingsView()
        }
    }
}
