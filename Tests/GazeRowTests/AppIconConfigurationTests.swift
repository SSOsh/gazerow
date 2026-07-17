import AppKit
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
        XCTAssertEqual(AppIconConfiguration.accessibilityDescription, "gazerow")
    }

    @MainActor
    func test_StatusItemIconFactory는_template_메뉴바아이콘을_생성한다() {
        // when
        let icon = StatusItemIconFactory.makeIcon()

        // then
        XCTAssertEqual(icon.size, StatusItemIconFactory.iconSize)
        XCTAssertTrue(icon.isTemplate)
        XCTAssertEqual(icon.accessibilityDescription, "gazerow")
        XCTAssertNotNil(icon.tiffRepresentation)
    }

    func test_AppIconAsset은_유효한_icns로_생성된다() throws {
        // given
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let iconURL = repositoryRoot
            .appendingPathComponent("Assets", isDirectory: true)
            .appendingPathComponent(AppIconConfiguration.appIconFileName)

        // when
        let icon = NSImage(contentsOf: iconURL)

        // then
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconURL.path))
        XCTAssertNotNil(icon)
        XCTAssertTrue(try Data(contentsOf: iconURL).count > 100_000)
        XCTAssertTrue(icon?.representations.contains { representation in
            representation.pixelsWide >= 512 && representation.pixelsHigh >= 512
        } == true)
    }

}
