import Foundation

/// Settings 상단에 표시할 기본 사용 가능 상태.
///
/// Overlay 사용을 실제로 막는 조건만 우선순위로 요약해 사용자가 다음 행동을
/// 바로 판단할 수 있게 한다.
///
/// @author suho.do
/// @since 2026-07-12
struct SettingsReadinessSummary: Equatable {

    /// Settings에서 강조할 현재 상태.
    enum State: Equatable {
        /// Accessibility 권한이 없어 overlay와 클릭을 사용할 수 없음.
        case permissionRequired

        /// kill switch가 꺼져 있어 overlay 활성화가 차단됨.
        case sessionDisabled

        /// 기본 overlay 사용 조건을 만족함.
        case ready
    }

    /// 현재 우선순위 상태.
    let state: State

    init(
        isAccessibilityGranted: Bool,
        isSessionEnabled: Bool
    ) {
        if !isAccessibilityGranted {
            state = .permissionRequired
        } else if !isSessionEnabled {
            state = .sessionDisabled
        } else {
            state = .ready
        }
    }
}
