import CoreGraphics
import Foundation

/// scanner가 AX tree를 읽기 위해 사용하는 client abstraction.
///
/// production은 `AXUIElement`, 테스트는 in-memory node를 사용한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
protocol AccessibilityElementClient {
    associatedtype Element

    func rootElement(for context: TargetContext) -> Result<Element, AccessibilityScanFailure>
    func additionalRootElements(for context: TargetContext) -> [Element]
    func snapshot(of element: Element) -> AccessibilityElementSnapshot
    func role(of element: Element) -> String?
    func subrole(of element: Element) -> String?
    func title(of element: Element) -> String?
    func value(of element: Element) -> String?
    func help(of element: Element) -> String?
    func frame(of element: Element) -> CGRect?
    func actions(of element: Element) -> [String]
    func children(of element: Element) -> Result<[Element], AccessibilityScanFailure>
}

extension AccessibilityElementClient {
    func additionalRootElements(for context: TargetContext) -> [Element] {
        []
    }

    func role(of element: Element) -> String? {
        snapshot(of: element).role
    }

    func subrole(of element: Element) -> String? {
        snapshot(of: element).subrole
    }

    func title(of element: Element) -> String? {
        snapshot(of: element).title
    }

    func value(of element: Element) -> String? {
        snapshot(of: element).value
    }

    func help(of element: Element) -> String? {
        snapshot(of: element).help
    }

    func frame(of element: Element) -> CGRect? {
        snapshot(of: element).frame
    }

    func actions(of element: Element) -> [String] {
        snapshot(of: element).actions
    }
}
