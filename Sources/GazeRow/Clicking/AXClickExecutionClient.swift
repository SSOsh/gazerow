import ApplicationServices
import CoreGraphics

/// macOS AX/CGEvent 기반 click execution client.
///
/// coordinate fallback은 executor configuration이 켠 경우에만 호출된다.
///
/// @author suho.do
/// @since 2026-07-02
struct AXClickExecutionClient: ClickExecutionClient {

    func performAXPress(on element: AXUIElement) -> ClickClientResult {
        let error = AXUIElementPerformAction(element, kAXPressAction as CFString)

        guard error == .success else {
            return .failure(error.localizedDebugDescription)
        }

        return .success
    }

    func performCoordinateClick(at point: CGPoint) -> ClickClientResult {
        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ),
        let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            return .failure("Failed to create coordinate click events.")
        }

        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
        return .success
    }
}
