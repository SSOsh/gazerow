import Observation

/// 세션 활성/비활성(kill switch) 상태를 관리한다.
///
/// SD-006에 따라 메뉴바에서 즉시 중단 경로를 제공한다.
/// `isEnabled`가 `false`이면 이후 overlay activation을 차단한다.
///
/// 메뉴바(AppDelegate)와 Settings가 같은 상태를 공유해야 하므로 `shared`
/// 싱글톤을 제공하되, 단위 테스트를 위해 별도 인스턴스도 생성할 수 있다.
///
/// - Note: 실제 overlay/입력 처리는 TICKET-005 이후 작업이다. 현재는 gate
///   플래그와 상태 전이만 담당하며, 후속 티켓의 activation이 이 값을 참조한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
@Observable
final class SessionController {

    /// 메뉴바와 Settings가 공유하는 전역 인스턴스.
    static let shared = SessionController()

    /// 세션 활성 여부. `false`이면 kill switch가 눌린 상태로 activation을 차단한다.
    private(set) var isEnabled: Bool

    /// - Parameter isEnabled: 초기 활성 상태. 기본값은 `true`.
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    /// 활성/비활성 상태를 뒤집는다. 메뉴바 kill switch 토글에 연결한다.
    func toggle() {
        setEnabled(!isEnabled)
    }

    /// 세션을 활성화한다.
    func enable() {
        setEnabled(true)
    }

    /// 세션을 비활성화한다(kill switch).
    func disable() {
        setEnabled(false)
    }

    /// 상태를 지정 값으로 바꾸고, 실제 변경이 있을 때만 로그를 남긴다.
    private func setEnabled(_ newValue: Bool) {
        guard newValue != isEnabled else { return }
        isEnabled = newValue
        AppLogger.session.info("session enabled: \(newValue, privacy: .public)")
    }
}
