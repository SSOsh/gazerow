import CoreGraphics

/// click executor가 시스템 click을 수행할 때 사용하는 client.
///
/// @author suho.do
/// @since 2026-07-02
protocol ClickExecutionClient {
    associatedtype Element

    func performAXPress(on element: Element) -> ClickClientResult
    func performCoordinateClick(at point: CGPoint) -> ClickClientResult
}
