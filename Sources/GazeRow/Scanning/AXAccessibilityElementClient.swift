import ApplicationServices
import CoreGraphics
import Foundation

/// macOS Accessibility API 기반 AX element client.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct AXAccessibilityElementClient: AccessibilityElementClient {
    private let rootElementSelector: AccessibilityRootElementSelector<AXUIElement>
    private let childAttributeCollector: AccessibilityChildAttributeCollector<AXUIElement>
    private let additionalRootElementCollector = AccessibilityAdditionalRootElementCollector<AXUIElement> { element in
        AnyHashable(CFHash(element))
    }
    private let messagingTimeout: Float

    nonisolated init(
        rootElementSelector: AccessibilityRootElementSelector<AXUIElement> =
            AccessibilityRootElementSelector<AXUIElement>(),
        childAttributeCollector: AccessibilityChildAttributeCollector<AXUIElement> =
            AccessibilityChildAttributeCollector<AXUIElement>(),
        messagingTimeout: Float = 1.0
    ) {
        self.rootElementSelector = rootElementSelector
        self.childAttributeCollector = childAttributeCollector
        self.messagingTimeout = messagingTimeout
    }

    func rootElement(for context: TargetContext) -> Result<AXUIElement, AccessibilityScanFailure> {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityPermissionDenied)
        }

        let applicationElement = AXUIElementCreateApplication(context.application.processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, messagingTimeout)

        return rootElementSelector.select(
            focusedWindow: copyWindowElement(kAXFocusedWindowAttribute, from: applicationElement),
            mainWindow: copyWindowElement(kAXMainWindowAttribute, from: applicationElement),
            windows: copyWindowElements(from: applicationElement),
            isUsable: { windowElement in
                configureTimeout(for: windowElement)
                guard let frame = copyFrame(from: windowElement) else {
                    return false
                }
                return frame.width > 0 && frame.height > 0
            }
        )
    }

    func additionalRootElements(for context: TargetContext) -> [AXUIElement] {
        guard AXIsProcessTrusted() else {
            return []
        }

        let applicationElement = AXUIElementCreateApplication(context.application.processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, messagingTimeout)

        let roots = additionalRootElementCollector.collect(
            focusedElement: copyFocusedUIElement(from: applicationElement),
            within: context.window.frame,
            relatedElement: { attribute, element in
                copyRelatedRootElement(attribute, from: element)
            },
            elementFrame: { element in
                copyFrame(from: element)
            }
        )
        roots.forEach(configureTimeout)
        return roots
    }

    private func copyFocusedUIElement(from applicationElement: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        guard error == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private func copyRelatedRootElement(_ attribute: String, from element: AXUIElement) -> AXUIElement? {
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

    private func copyWindowElement(
        _ attribute: String,
        from applicationElement: AXUIElement
    ) -> Result<AXUIElement, AccessibilityScanFailure> {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            applicationElement,
            attribute as CFString,
            &value
        )

        guard error == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return .failure(.focusedWindowUnavailable(error.localizedDebugDescription))
        }

        let windowElement = value as! AXUIElement
        configureTimeout(for: windowElement)
        return .success(windowElement)
    }

    private func copyWindowElements(from applicationElement: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXWindowsAttribute as CFString,
            &value
        )

        guard error == .success,
              let values = value as? [AnyObject] else {
            return []
        }

        return values.compactMap { value in
            guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
                return nil
            }

            let windowElement = value as! AXUIElement
            configureTimeout(for: windowElement)
            return windowElement
        }
    }

    private func configureTimeout(for element: AXUIElement) {
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
    }

    func snapshot(of element: AXUIElement) -> AccessibilityElementSnapshot {
        guard let values = copyMultipleAttributes(
            [
                kAXRoleAttribute,
                kAXSubroleAttribute,
                kAXTitleAttribute,
                kAXValueAttribute,
                kAXHelpAttribute,
                kAXPositionAttribute,
                kAXSizeAttribute
            ],
            from: element
        ) else {
            return fallbackSnapshot(of: element)
        }

        return AccessibilityElementSnapshot(
            role: copyStringAttribute(kAXRoleAttribute, from: values),
            subrole: copyStringAttribute(kAXSubroleAttribute, from: values),
            title: copyStringAttribute(kAXTitleAttribute, from: values),
            value: copyStringAttribute(kAXValueAttribute, from: values),
            help: copyStringAttribute(kAXHelpAttribute, from: values),
            frame: copyFrame(from: values),
            actions: copyActionNames(from: element)
        )
    }

    private func fallbackSnapshot(of element: AXUIElement) -> AccessibilityElementSnapshot {
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

    func role(of element: AXUIElement) -> String? {
        copyStringAttribute(kAXRoleAttribute, from: element)
    }

    func subrole(of element: AXUIElement) -> String? {
        copyStringAttribute(kAXSubroleAttribute, from: element)
    }

    func title(of element: AXUIElement) -> String? {
        copyStringAttribute(kAXTitleAttribute, from: element)
    }

    func value(of element: AXUIElement) -> String? {
        copyStringAttribute(kAXValueAttribute, from: element)
    }

    func help(of element: AXUIElement) -> String? {
        copyStringAttribute(kAXHelpAttribute, from: element)
    }

    func frame(of element: AXUIElement) -> CGRect? {
        copyFrame(from: element)
    }

    func actions(of element: AXUIElement) -> [String] {
        copyActionNames(from: element)
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
        childAttributeCollector.collect(
            readBatch: { attributes in
                copyChildElements(attributes, from: element)
            },
            fallbackReadElements: { attribute in
                copyChildElements(attribute, from: element)
            }
        ).map { elements in
            AccessibilityElementDeduplicator<AXUIElement> { element in
                AnyHashable(CFHash(element))
            }
            .deduplicated(elements)
        }
    }

    /// 여러 child-like AX 속성을 한 IPC로 읽어 유효한 element 배열만 합친다.
    private func copyChildElements(
        _ attributes: [String],
        from element: AXUIElement
    ) -> Result<[AXUIElement], AccessibilityScanFailure> {
        var values: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(
            element,
            attributes as CFArray,
            AXCopyMultipleAttributeOptions(rawValue: 0),
            &values
        )

        guard error == .success,
              let valueArray = values as? [AnyObject] else {
            return .failure(.childrenUnavailable(error.localizedDebugDescription))
        }

        let elements = valueArray.flatMap { value -> [AXUIElement] in
            value as? [AXUIElement] ?? []
        }
        return .success(elements)
    }

    private func copyChildElements(
        _ attribute: String,
        from element: AXUIElement
    ) -> Result<[AXUIElement], AccessibilityScanFailure> {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
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

    private func copyFrame(from values: [String: AnyObject]) -> CGRect? {
        guard let origin = copyPointAttribute(kAXPositionAttribute, from: values),
              let size = copySizeAttribute(kAXSizeAttribute, from: values) else {
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

    private func copyPointAttribute(_ attribute: String, from values: [String: AnyObject]) -> CGPoint? {
        guard let value = copyAXValueAttribute(attribute, from: values),
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

    private func copySizeAttribute(_ attribute: String, from values: [String: AnyObject]) -> CGSize? {
        guard let value = copyAXValueAttribute(attribute, from: values),
              AXValueGetType(value) == .cgSize else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else {
            return nil
        }

        return size
    }

    private func copyMultipleAttributes(
        _ attributes: [String],
        from element: AXUIElement
    ) -> [String: AnyObject]? {
        var values: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(
            element,
            attributes as CFArray,
            AXCopyMultipleAttributeOptions(rawValue: 0),
            &values
        )

        guard error == .success,
              let valueArray = values as? [AnyObject] else {
            return nil
        }

        return Dictionary(
            uniqueKeysWithValues: zip(attributes, valueArray)
        )
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

    private func copyAXValueAttribute(_ attribute: String, from values: [String: AnyObject]) -> AXValue? {
        guard let value = values[attribute],
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

    private func copyStringAttribute(_ attribute: String, from values: [String: AnyObject]) -> String? {
        values[attribute] as? String
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
