import ApplicationServices
import AppKit

/// frontmost 창의 표준 컨트롤 버튼을 누르는 abstraction.
///
/// dispatcher가 테스트에서 fake를 주입할 수 있게 protocol로 분리한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
protocol WindowControlButtonPressing {
    /// frontmost 앱의 focused window에서 `action`에 해당하는 버튼을 press한다.
    func press(_ action: WindowControlAction) -> WindowControlResult
}

/// macOS Accessibility API 기반 window control 버튼 press client.
///
/// frontmost 앱의 focused window(없으면 main window)를 찾아
/// 표준 title-bar 버튼 element에 `AXPress` action을 보낸다.
/// window title/텍스트 원문은 조회하지 않는다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct AXWindowControlButtonClient: WindowControlButtonPressing {

    /// frontmost 앱을 제공하는 클로저(테스트 주입 가능).
    private let frontmostApplication: () -> NSRunningApplication?

    nonisolated init(frontmostApplication: @escaping () -> NSRunningApplication? = {
        NSWorkspace.shared.frontmostApplication
    }) {
        self.frontmostApplication = frontmostApplication
    }

    func press(_ action: WindowControlAction) -> WindowControlResult {
        guard AXIsProcessTrusted() else {
            return .permissionDenied
        }

        guard let application = frontmostApplication() else {
            return .windowUnavailable
        }

        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)

        guard let windowElement = focusedWindowElement(from: applicationElement) else {
            return .windowUnavailable
        }

        guard let buttonElement = copyElement(action.axButtonAttribute, from: windowElement) else {
            return .controlUnavailable
        }

        let error = AXUIElementPerformAction(buttonElement, kAXPressAction as CFString)
        guard error == .success else {
            return .actionFailed(error.localizedDebugDescription)
        }

        return .success
    }

    /// focused window를 우선 조회하고, 없으면 main window로 대체한다.
    private func focusedWindowElement(from applicationElement: AXUIElement) -> AXUIElement? {
        copyElement(kAXFocusedWindowAttribute, from: applicationElement)
            ?? copyElement(kAXMainWindowAttribute, from: applicationElement)
    }

    /// 주어진 attribute의 AXUIElement 값을 복사한다.
    private func copyElement(_ attribute: String, from element: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )

        guard error == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }
}
