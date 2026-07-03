import CoreGraphics

/// gaze point에 가장 가까운 overlay focus item을 고른다.
///
/// 이 타입은 focus 이동만 결정하며 click 실행은 하지 않는다.
///
/// @author suho.do
/// @since 2026-07-03
struct GazeFocusController {

    let maximumActivationDistance: CGFloat?

    init(maximumActivationDistance: CGFloat? = nil) {
        self.maximumActivationDistance = maximumActivationDistance
    }

    func nearestItem(to gazePoint: CGPoint, in items: [FocusItem]) -> FocusItem? {
        guard let nearest = items.min(by: { lhs, rhs in
            distance(from: gazePoint, to: lhs.frame) < distance(from: gazePoint, to: rhs.frame)
        }) else {
            return nil
        }

        if let maximumActivationDistance,
           distance(from: gazePoint, to: nearest.frame) > maximumActivationDistance {
            return nil
        }

        return nearest
    }

    private func distance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        hypot(point.x - frame.midX, point.y - frame.midY)
    }
}
