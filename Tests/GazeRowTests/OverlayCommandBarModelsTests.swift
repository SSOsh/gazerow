import CoreGraphics
import XCTest
@testable import GazeRow

/// command bar 화면 배치 순수 모델 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-13
final class OverlayCommandBarModelsTests: XCTestCase {

    func test_makeLayout_일반화면에서_하단중앙에_compactBar를_배치한다() {
        // given
        let sut = OverlayCommandBarLayoutEngine()
        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

        // when
        let result = sut.makeLayout(
            visibleFrame: visibleFrame,
            showsWindowPreviews: false,
            showsMessage: false
        )

        // then
        XCTAssertEqual(result.commandBarFrame, CGRect(x: 380, y: 16, width: 680, height: 72))
        XCTAssertEqual(result.panelFrame, result.commandBarFrame)
        XCTAssertNil(result.previewFrame)
    }

    func test_makeLayout_visibleFrame하단이올라가도_그기준으로배치한다() {
        // given
        let sut = OverlayCommandBarLayoutEngine()
        let visibleFrame = CGRect(x: 0, y: 96, width: 1440, height: 804)

        // when
        let result = sut.makeLayout(
            visibleFrame: visibleFrame,
            showsWindowPreviews: false,
            showsMessage: false
        )

        // then
        XCTAssertEqual(result.commandBarFrame.minY, 112)
    }

    func test_makeLayout_좁은화면은_8pt여백을사용한다() {
        // given
        let sut = OverlayCommandBarLayoutEngine()
        let visibleFrame = CGRect(x: 0, y: 0, width: 380, height: 600)

        // when
        let result = sut.makeLayout(
            visibleFrame: visibleFrame,
            showsWindowPreviews: false,
            showsMessage: false
        )

        // then
        XCTAssertEqual(result.commandBarFrame, CGRect(x: 8, y: 16, width: 364, height: 72))
    }

    func test_makeLayout_preview와_message가있어도_barY를유지한다() {
        // given
        let sut = OverlayCommandBarLayoutEngine()
        let visibleFrame = CGRect(x: -1280, y: -900, width: 1280, height: 800)

        // when
        let result = sut.makeLayout(
            visibleFrame: visibleFrame,
            showsWindowPreviews: true,
            showsMessage: true
        )

        // then
        XCTAssertEqual(result.commandBarFrame.minY, -884)
        XCTAssertEqual(result.commandBarFrame.height, 88)
        XCTAssertEqual(result.previewFrame, CGRect(x: -980, y: -788, width: 680, height: 88))
        XCTAssertEqual(result.panelFrame, CGRect(x: -980, y: -884, width: 680, height: 184))
    }

    func test_screen_target과교차면적이가장큰화면을선택한다() {
        // given
        let sut = OverlayCommandBarLayoutEngine()
        let leftScreen = OverlayScreenDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 760),
            scaleFactor: 2
        )
        let rightScreen = OverlayScreenDescriptor(
            frame: CGRect(x: 1000, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 1000, y: 0, width: 1000, height: 760),
            scaleFactor: 1
        )

        // when
        let result = sut.screen(
            containing: CGRect(x: 850, y: 100, width: 500, height: 400),
            in: [leftScreen, rightScreen]
        )

        // then
        XCTAssertEqual(result, rightScreen)
    }

    func test_screen_화면이없으면_targetFrame을fallback으로사용한다() {
        // given
        let sut = OverlayCommandBarLayoutEngine()
        let targetFrame = CGRect(x: -200, y: 100, width: 300, height: 200)

        // when
        let result = sut.screen(containing: targetFrame, in: [])

        // then
        XCTAssertEqual(result.frame, targetFrame)
        XCTAssertEqual(result.visibleFrame, targetFrame)
        XCTAssertEqual(result.scaleFactor, 1)
    }
}
