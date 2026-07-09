import XCTest
@testable import GazeRow

/// OverlayAppearanceSettings 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-07
final class OverlayAppearanceSettingsTests: XCTestCase {

    func test_기본값은_OverlayAppearance_기본_투명도() {
        // given
        let sut = OverlayAppearanceSettings(defaults: makeDefaults())

        // then
        XCTAssertEqual(
            sut.labelBackgroundOpacity,
            OverlayAppearance.defaultLabelBackgroundOpacity,
            accuracy: 0.0001
        )
    }

    func test_투명도를_UserDefaults에_저장() {
        // given
        let defaults = makeDefaults()
        let sut = OverlayAppearanceSettings(defaults: defaults)

        // when
        sut.labelBackgroundOpacity = 0.6

        // then
        XCTAssertEqual(
            defaults.double(forKey: OverlayAppearanceSettings.labelBackgroundOpacityKey),
            0.6,
            accuracy: 0.0001
        )
    }

    func test_저장한_값을_다시_읽어온다() {
        // given
        let sut = OverlayAppearanceSettings(defaults: makeDefaults())

        // when
        sut.labelBackgroundOpacity = 0.75

        // then
        XCTAssertEqual(sut.labelBackgroundOpacity, 0.75, accuracy: 0.0001)
    }

    func test_appearance는_저장된_투명도를_반영() {
        // given
        let sut = OverlayAppearanceSettings(defaults: makeDefaults())

        // when
        sut.labelBackgroundOpacity = 0.5

        // then
        XCTAssertEqual(sut.appearance.labelBackgroundOpacity, 0.5, accuracy: 0.0001)
    }

    func test_appearance는_범위를_벗어난_값을_clamp() {
        // given
        let sut = OverlayAppearanceSettings(defaults: makeDefaults())

        // when: 저장소는 원시 값을 그대로 두고, appearance 생성 시 clamp된다.
        sut.labelBackgroundOpacity = 5.0

        // then
        XCTAssertEqual(
            sut.appearance.labelBackgroundOpacity,
            OverlayAppearance.labelBackgroundOpacityRange.upperBound,
            accuracy: 0.0001
        )
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "OverlayAppearanceSettingsTests.\(UUID().uuidString)")!
    }
}
