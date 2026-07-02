import ApplicationServices
import CoreGraphics
import Foundation

/// focused window AX 조회 abstraction.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
protocol AccessibilityTargetClient {
    func focusedWindow(for application: TargetApplication) -> Result<TargetWindow, AccessibilityReadFailure>
}

/// macOS Accessibility API 기반 focused window client.
///
/// TICKET-003 범위에서는 window title/frame을 런타임에서만 조회한다.
/// 원문 title은 로그나 파일에 저장하지 않는다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct AXAccessibilityTargetClient: AccessibilityTargetClient {

    func focusedWindow(for application: TargetApplication) -> Result<TargetWindow, AccessibilityReadFailure> {
        guard AXIsProcessTrusted() else {
            return .failure(.permissionDenied)
        }

        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)

        switch copyFocusedWindow(from: applicationElement) {
        case .success(let windowElement):
            return buildWindow(from: windowElement)
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func copyFocusedWindow(
        from applicationElement: AXUIElement
    ) -> Result<AXUIElement, AccessibilityReadFailure> {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        )

        guard error == .success,
              let windowElement = value,
              CFGetTypeID(windowElement) == AXUIElementGetTypeID() else {
            return .failure(.focusedWindowUnavailable(error.localizedDebugDescription))
        }

        return .success(windowElement as! AXUIElement)
    }

    private func buildWindow(from windowElement: AXUIElement) -> Result<TargetWindow, AccessibilityReadFailure> {
        guard let frame = copyFrame(from: windowElement) else {
            return .failure(.frameUnavailable("AX position or size attribute is unavailable."))
        }

        return .success(
            TargetWindow(
                frame: frame,
                title: copyStringAttribute(kAXTitleAttribute, from: windowElement)
            )
        )
    }

    private func copyFrame(from windowElement: AXUIElement) -> CGRect? {
        guard let origin = copyPointAttribute(kAXPositionAttribute, from: windowElement),
              let size = copySizeAttribute(kAXSizeAttribute, from: windowElement) else {
            return nil
        }

        return CGRect(origin: origin, size: size)
    }

    private func copyPointAttribute(_ attribute: String, from element: AXUIElement) -> CGPoint? {
        guard let value = copyAXValueAttribute(attribute, from: element),
              AXValueGetType(value) == .cgPoint else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else {
            return nil
        }

        return point
    }

    private func copySizeAttribute(_ attribute: String, from element: AXUIElement) -> CGSize? {
        guard let value = copyAXValueAttribute(attribute, from: element),
              AXValueGetType(value) == .cgSize else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else {
            return nil
        }

        return size
    }

    private func copyAXValueAttribute(_ attribute: String, from element: AXUIElement) -> AXValue? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )

        guard error == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        return (value as! AXValue)
    }

    private func copyStringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )

        guard error == .success else {
            return nil
        }

        return value as? String
    }
}
