import CoreGraphics
import Foundation

/// window tree 밖에 따로 노출되는 focused/editable AX element를 scan root로 보강한다.
///
/// @author suho.do
/// @since 2026-07-12
struct AccessibilityAdditionalRootElementCollector<Element> {
    private let attributes: [String]
    private let deduplicator: AccessibilityElementDeduplicator<Element>

    init(
        attributes: [String] = AccessibilityAdditionalRootElementCollector.defaultAttributes,
        keyProvider: @escaping (Element) -> AnyHashable
    ) {
        self.attributes = attributes
        self.deduplicator = AccessibilityElementDeduplicator(keyProvider: keyProvider)
    }

    func collect(
        focusedElement: Element?,
        within targetFrame: CGRect,
        relatedElement: (String, Element) -> Element?,
        elementFrame: (Element) -> CGRect?
    ) -> [Element] {
        guard let focusedElement else {
            return []
        }

        let relatedElements = attributes.compactMap { attribute in
            relatedElement(attribute, focusedElement)
        }
        let candidates = [focusedElement] + relatedElements

        return deduplicator.deduplicated(candidates).filter { element in
            guard let frame = elementFrame(element),
                  frame.width > 0,
                  frame.height > 0 else {
                return false
            }

            return frame.intersects(targetFrame)
        }
    }

    private static var defaultAttributes: [String] {
        [
            "AXEditableAncestor",
            "AXHighestEditableAncestor",
            "AXFocusableAncestor",
            "AXParent"
        ]
    }
}
