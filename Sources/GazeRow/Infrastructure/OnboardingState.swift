import Foundation
import Observation

/// 첫 실행 안내(onboarding) 표시 여부를 관리한다.
///
/// 완료 여부는 `UserDefaults`에 영속 저장한다. 저장소를 주입할 수 있어
/// 단위 테스트에서는 임시 `UserDefaults`(suite)를 사용한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
@Observable
final class OnboardingState {

    /// onboarding 완료 여부를 저장하는 UserDefaults 키.
    private static let completedKey = "onboarding.completed"

    /// onboarding 시트 표시 여부. UI가 바인딩한다.
    var isPresenting: Bool = false

    /// 완료 여부 저장소.
    private let defaults: UserDefaults

    /// - Parameter defaults: 완료 여부를 저장할 UserDefaults. 기본값은 `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// onboarding을 이미 완료했는지 여부.
    var hasCompleted: Bool {
        defaults.bool(forKey: Self.completedKey)
    }

    /// 아직 완료하지 않았다면 시트를 표시하도록 `isPresenting`을 켠다.
    func presentIfNeeded() {
        if !hasCompleted {
            isPresenting = true
        }
    }

    /// 완료로 표시하고 시트를 닫는다.
    func complete() {
        defaults.set(true, forKey: Self.completedKey)
        isPresenting = false
    }
}
