import XCTest
@testable import GazeRow

/// CameraGazeSettings 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class CameraGazeSettingsTests: XCTestCase {

    func test_기본값은_off() {
        // given
        let sut = CameraGazeSettings(defaults: makeDefaults())

        // then
        XCTAssertFalse(sut.isOptInEnabled)
    }

    func test_optIn상태를_UserDefaults에_저장() {
        // given
        let defaults = makeDefaults()
        let sut = CameraGazeSettings(defaults: defaults)

        // when
        sut.isOptInEnabled = true

        // then
        XCTAssertTrue(defaults.bool(forKey: CameraGazeSettings.optInKey))
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "CameraGazeSettingsTests.\(UUID().uuidString)")!
    }
}
