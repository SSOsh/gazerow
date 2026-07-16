import XCTest
@testable import GazeRow

/// AppIconConfiguration 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-12
final class AppIconConfigurationTests: XCTestCase {

    func test_appIconConfiguration은_icns와_bundleIconName을_제공한다() {
        // then
        XCTAssertEqual(AppIconConfiguration.appIconFileName, "AppIcon.icns")
        XCTAssertEqual(AppIconConfiguration.bundleIconName, "AppIcon")
        XCTAssertEqual(AppIconConfiguration.accessibilityDescription, "keyCursor")
    }

    @MainActor
    func test_StatusItemIconFactory는_template_메뉴바아이콘을_생성한다() {
        // when
        let icon = StatusItemIconFactory.makeIcon()

        // then
        XCTAssertEqual(icon.size, StatusItemIconFactory.iconSize)
        XCTAssertTrue(icon.isTemplate)
        XCTAssertEqual(icon.accessibilityDescription, "keyCursor")
        XCTAssertNotNil(icon.tiffRepresentation)
    }

}
