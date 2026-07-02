import CoreGraphics

/// screen 좌표를 target-window overlay 로컬 좌표로 변환한다.
///
/// @author suho.do
/// @since 2026-07-02
struct OverlayCoordinateMapper {
    let targetFrame: CGRect

    var localBounds: CGRect {
        CGRect(origin: .zero, size: targetFrame.size)
    }

    func mapScreenFrameToLocal(_ screenFrame: CGRect) -> CGRect {
        screenFrame.offsetBy(dx: -targetFrame.minX, dy: -targetFrame.minY)
    }

    func mapScreenPointToLocal(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: screenPoint.x - targetFrame.minX,
            y: screenPoint.y - targetFrame.minY
        )
    }

    func targetBoundaryFrame() -> CGRect {
        localBounds
    }
}
