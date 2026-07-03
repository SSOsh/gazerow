import Foundation

/// Camera gaze focus opt-in 상태를 UserDefaults에 저장한다.
///
/// 기본값은 반드시 off이며, 사용자가 Settings에서 명시적으로 켜기 전에는
/// Camera 권한 요청이나 frame capture를 시작하지 않는다.
///
/// @author suho.do
/// @since 2026-07-03
struct CameraGazeSettings {
    static let optInKey = "GazeRow.cameraGazeOptInEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isOptInEnabled: Bool {
        get {
            defaults.bool(forKey: Self.optInKey)
        }
        nonmutating set {
            defaults.set(newValue, forKey: Self.optInKey)
        }
    }
}
