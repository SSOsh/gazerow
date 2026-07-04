import ApplicationServices
import CoreGraphics
import Foundation

/// 좌표 기반 단일 좌클릭 event 발행.
///
/// @author suho.do
/// @since 2026-07-04
protocol CoordinateClickPosting {
    func postSingleLeftClick(at point: CGPoint) -> ClickClientResult
}

/// CGEvent 기반 좌표 클릭 event poster.
///
/// @author suho.do
/// @since 2026-07-04
struct CGCoordinateClickPoster: CoordinateClickPosting {
    private let clickInterval: TimeInterval

    init(clickInterval: TimeInterval = 0.035) {
        self.clickInterval = clickInterval
    }

    func postSingleLeftClick(at point: CGPoint) -> ClickClientResult {
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        CGWarpMouseCursorPosition(point)

        guard let source = CGEventSource(stateID: .hidSystemState),
              let mouseDown = CGEvent(
                  mouseEventSource: source,
                  mouseType: .leftMouseDown,
                  mouseCursorPosition: point,
                  mouseButton: .left
              ),
              let mouseUp = CGEvent(
                  mouseEventSource: source,
                  mouseType: .leftMouseUp,
                  mouseCursorPosition: point,
                  mouseButton: .left
              ) else {
            return .failure("Failed to create coordinate click events.")
        }

        mouseDown.flags = []
        mouseUp.flags = []
        mouseDown.setIntegerValueField(.mouseEventClickState, value: 1)
        mouseUp.setIntegerValueField(.mouseEventClickState, value: 1)

        mouseDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: clickInterval)
        mouseUp.post(tap: .cghidEventTap)
        return .success
    }
}

/// macOS AX/CGEvent 기반 click execution client.
///
/// coordinate fallback은 executor configuration이 켠 경우에만 호출된다.
///
/// @author suho.do
/// @since 2026-07-02
struct AXClickExecutionClient: ClickExecutionClient {
    private let coordinateClickPoster: any CoordinateClickPosting

    init(coordinateClickPoster: any CoordinateClickPosting = CGCoordinateClickPoster()) {
        self.coordinateClickPoster = coordinateClickPoster
    }

    func performAXPress(on element: AXUIElement) -> ClickClientResult {
        performAXAction(AccessibilityAction.press, on: element)
    }

    func performAXAction(_ action: String, on element: AXUIElement) -> ClickClientResult {
        let error = AXUIElementPerformAction(element, action as CFString)

        guard error == .success else {
            return .failure(error.localizedDebugDescription)
        }

        return .success
    }

    func performCoordinateClick(at point: CGPoint) -> ClickClientResult {
        AppLogger.interaction.info(
            "coordinate click point=(\(Int(point.x), privacy: .public),\(Int(point.y), privacy: .public))"
        )

        return coordinateClickPoster.postSingleLeftClick(at: point)
    }
}
