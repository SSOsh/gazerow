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

/// mouse cursor 위치 조회/이동.
///
/// @author suho.do
/// @since 2026-07-04
protocol MouseCursorControlling {
    func currentPosition() -> CGPoint?
    func move(to point: CGPoint)
}

/// CGEvent 기반 mouse cursor controller.
///
/// @author suho.do
/// @since 2026-07-04
struct CGMouseCursorController: MouseCursorControlling {
    func currentPosition() -> CGPoint? {
        CGEvent(source: nil)?.location
    }

    func move(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
    }
}

/// 단일 좌클릭 event 발행.
///
/// @author suho.do
/// @since 2026-07-04
protocol SingleClickEventPosting {
    func postSingleLeftClickEvent(at point: CGPoint, clickInterval: TimeInterval) -> ClickClientResult
}

/// CGEvent 기반 단일 좌클릭 event poster.
///
/// @author suho.do
/// @since 2026-07-04
struct CGSingleClickEventPoster: SingleClickEventPosting {
    func postSingleLeftClickEvent(at point: CGPoint, clickInterval: TimeInterval) -> ClickClientResult {
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

/// CGEvent 기반 좌표 클릭 event poster.
///
/// @author suho.do
/// @since 2026-07-04
struct CGCoordinateClickPoster: CoordinateClickPosting {
    private let clickInterval: TimeInterval
    private let cursorController: any MouseCursorControlling
    private let clickEventPoster: any SingleClickEventPosting

    init(
        clickInterval: TimeInterval = 0.035,
        cursorController: any MouseCursorControlling = CGMouseCursorController(),
        clickEventPoster: any SingleClickEventPosting = CGSingleClickEventPoster()
    ) {
        self.clickInterval = clickInterval
        self.cursorController = cursorController
        self.clickEventPoster = clickEventPoster
    }

    func postSingleLeftClick(at point: CGPoint) -> ClickClientResult {
        let originalPosition = cursorController.currentPosition()

        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        cursorController.move(to: point)
        let result = clickEventPoster.postSingleLeftClickEvent(at: point, clickInterval: clickInterval)
        if let originalPosition {
            cursorController.move(to: originalPosition)
        }
        return result
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
