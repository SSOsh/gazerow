import XCTest
@testable import GazeRow

/// AppLanguageSettings 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class AppLanguageSettingsTests: XCTestCase {

    func test_selectedLanguage_기본값은_english() {
        // given
        let sut = AppLanguageSettings(defaults: makeDefaults())

        // when & then
        XCTAssertEqual(sut.selectedLanguage, .english)
    }

    func test_selectedLanguage_저장후_다시읽을수있다() {
        // given
        let defaults = makeDefaults()
        let sut = AppLanguageSettings(defaults: defaults)

        // when
        sut.selectedLanguage = .korean
        let reloaded = AppLanguageSettings(defaults: defaults)

        // then
        XCTAssertEqual(reloaded.selectedLanguage, .korean)
    }

    func test_selectedLanguage_알수없는값이면_english로_fallback() {
        // given
        let defaults = makeDefaults()
        defaults.set("invalid", forKey: AppLanguageSettings.selectedLanguageKey)
        let sut = AppLanguageSettings(defaults: defaults)

        // when & then
        XCTAssertEqual(sut.selectedLanguage, .english)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppLanguageSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
