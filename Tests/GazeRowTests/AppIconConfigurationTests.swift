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

    @MainActor
    func test_StatusItemIconFactory는_3x3키보드와_우상단시선표식을_렌더링한다() throws {
        // given
        let icon = StatusItemIconFactory.makeIcon()
        let representation = try XCTUnwrap(
            icon.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))
        )

        // when
        let keyCenters = [
            NSPoint(x: 4.35, y: 5.15),
            NSPoint(x: 4.35, y: 8.85),
            NSPoint(x: 4.35, y: 12.55),
            NSPoint(x: 11.75, y: 5.15)
        ]
        let gazeCenter = NSPoint(x: 12.3, y: 11.9)

        // then
        XCTAssertTrue(keyCenters.allSatisfy {
            hasVisiblePixel(near: $0, in: representation)
        })
        XCTAssertTrue(hasVisiblePixel(near: gazeCenter, in: representation))
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

    private func hasVisiblePixel(
        near point: NSPoint,
        in representation: NSBitmapImageRep
    ) -> Bool {
        let scaleX = CGFloat(representation.pixelsWide) / StatusItemIconFactory.iconSize.width
        let scaleY = CGFloat(representation.pixelsHigh) / StatusItemIconFactory.iconSize.height
        let centerX = Int((point.x * scaleX).rounded())
        let centerY = Int((point.y * scaleY).rounded())

        for y in max(0, centerY - 1)...min(representation.pixelsHigh - 1, centerY + 1) {
            for x in max(0, centerX - 1)...min(representation.pixelsWide - 1, centerX + 1) {
                if representation.colorAt(x: x, y: y)?.alphaComponent ?? 0 > 0.35 {
                    return true
                }
            }
        }

        return false
    }

}
