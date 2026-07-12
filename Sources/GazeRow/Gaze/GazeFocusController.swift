import CoreGraphics

/// gaze point에 가장 가까운 overlay focus item을 고른다.
///
/// 이 타입은 focus 이동만 결정하며 click 실행은 하지 않는다.
///
/// @author suho.do
/// @since 2026-07-03
struct GazeFocusController {

    let maximumActivationDistance: CGFloat?
    let hysteresisMargin: CGFloat

    init(maximumActivationDistance: CGFloat? = nil, hysteresisMargin: CGFloat = 0) {
        self.maximumActivationDistance = maximumActivationDistance
        self.hysteresisMargin = max(0, hysteresisMargin)
    }

    /// gaze point에 가장 가까운 item을 고른다.
    ///
    /// `current`(현재 focus)가 주어지고 `hysteresisMargin`이 있으면 현재 focus에 관성을 부여한다.
    /// 새 최근접 후보가 현재 focus보다 margin 이상 더 가깝지 않으면 현재 focus를 유지해
    /// 시선 미세 흔들림으로 focus가 두 후보 사이에서 튀는 것을 막는다.
    func nearestItem(
        to gazePoint: CGPoint,
        in items: [FocusItem],
        current: FocusItem? = nil
    ) -> FocusItem? {
        guard let nearest = items.min(by: { lhs, rhs in
            distance(from: gazePoint, to: lhs.frame) < distance(from: gazePoint, to: rhs.frame)
        }) else {
            return nil
        }

        if let maximumActivationDistance,
           distance(from: gazePoint, to: nearest.frame) > maximumActivationDistance {
            return nil
        }

        if let held = heldByHysteresis(current: current, nearest: nearest, gazePoint: gazePoint) {
            return held
        }

        return nearest
    }

    /// 히스테리시스로 현재 focus를 유지해야 하면 current를, 아니면 nil을 반환한다.
    private func heldByHysteresis(
        current: FocusItem?,
        nearest: FocusItem,
        gazePoint: CGPoint
    ) -> FocusItem? {
        guard hysteresisMargin > 0,
              let current,
              current.id != nearest.id else {
            return nil
        }

        let currentDistance = distance(from: gazePoint, to: current.frame)

        // 현재 focus가 활성 거리 밖으로 벗어났으면 관성을 풀고 새 후보로 전환한다.
        if let maximumActivationDistance, currentDistance > maximumActivationDistance {
            return nil
        }

        let nearestDistance = distance(from: gazePoint, to: nearest.frame)
        return currentDistance - nearestDistance < hysteresisMargin ? current : nil
    }

    private func distance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        hypot(point.x - frame.midX, point.y - frame.midY)
    }
}
