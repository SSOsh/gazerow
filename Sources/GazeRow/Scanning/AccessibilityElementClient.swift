import CoreGraphics
import Foundation

/// scanner가 한 AX node에서 후보 판정과 순회에 필요한 값을 함께 읽은 결과.
///
/// production client는 이 계약을 단일 batch 조회로 최적화할 수 있고, 일반 client는
/// 기본 구현을 통해 기존 snapshot·children 호출을 그대로 사용할 수 있다.
///
/// @author suho.do
/// @since 2026-07-17
struct AccessibilityElementInspection<Element> {
    let snapshot: AccessibilityElementSnapshot
    let children: Result<[Element], AccessibilityScanFailure>
}

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
    func inspect(_ element: Element) -> AccessibilityElementInspection<Element>
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

    func inspect(_ element: Element) -> AccessibilityElementInspection<Element> {
        AccessibilityElementInspection(
            snapshot: snapshot(of: element),
            children: children(of: element)
        )
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
