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
    func snapshot(of element: Element) -> AccessibilityElementSnapshot
    func children(of element: Element) -> Result<[Element], AccessibilityScanFailure>
}
