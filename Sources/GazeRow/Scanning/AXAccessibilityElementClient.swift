import ApplicationServices
import CoreGraphics
import Foundation

/// macOS Accessibility API 기반 AX element client.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct AXAccessibilityElementClient: AccessibilityElementClient {

    func rootElement(for context: TargetContext) -> Result<AXUIElement, AccessibilityScanFailure> {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityPermissionDenied)
        }

        let applicationElement = AXUIElementCreateApplication(context.application.processIdentifier)
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        )

        guard error == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return .failure(.focusedWindowUnavailable(error.localizedDebugDescription))
        }

        return .success(value as! AXUIElement)
    }

    func snapshot(of element: AXUIElement) -> AccessibilityElementSnapshot {
        AccessibilityElementSnapshot(
            role: copyStringAttribute(kAXRoleAttribute, from: element),
            subrole: copyStringAttribute(kAXSubroleAttribute, from: element),
            title: copyStringAttribute(kAXTitleAttribute, from: element),
            value: copyStringAttribute(kAXValueAttribute, from: element),
            help: copyStringAttribute(kAXHelpAttribute, from: element),
            frame: copyFrame(from: element),
            actions: copyActionNames(from: element)
        )
    }

    func clickTarget(from element: AXUIElement) -> ClickTarget<AXUIElement>? {
        let snapshot = snapshot(of: element)

        guard !snapshot.isSecureField,
              let role = snapshot.role,
              let frame = snapshot.frame else {
            return nil
        }

        return ClickTarget(
            element: element,
            role: role,
            subrole: snapshot.subrole,
            title: snapshot.title,
            frame: frame,
            actions: snapshot.actions
        )
    }

    func children(of element: AXUIElement) -> Result<[AXUIElement], AccessibilityScanFailure> {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &value
        )

        if error == .noValue || error == .attributeUnsupported {
            return .success([])
        }

        guard error == .success else {
            return .failure(.childrenUnavailable(error.localizedDebugDescription))
        }

        guard let children = value as? [AXUIElement] else {
            return .success([])
        }

        return .success(children)
    }

    private func copyFrame(from element: AXUIElement) -> CGRect? {
        guard let origin = copyPointAttribute(kAXPositionAttribute, from: element),
              let size = copySizeAttribute(kAXSizeAttribute, from: element) else {
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

    private func copyActionNames(from element: AXUIElement) -> [String] {
        var names: CFArray?
        let error = AXUIElementCopyActionNames(element, &names)

        guard error == .success,
              let names,
              let actions = names as? [String] else {
            return []
        }

        return actions
    }
}
