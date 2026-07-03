import CoreGraphics
import XCTest
@testable import GazeRow

/// OverlayWindowController 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
@MainActor
final class OverlayWindowControllerTests: XCTestCase {

    func test_OverlayScreenFrameMapper_AX좌표를_AppKit좌표로_변환한다() {
        // given
        let sut = OverlayScreenFrameMapper(
            screenFrames: [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        )

        // when
        let appKitFrame = sut.appKitFrame(
            fromAXFrame: CGRect(x: 100, y: 120, width: 400, height: 300)
        )

        // then
        XCTAssertEqual(appKitFrame, CGRect(x: 100, y: 480, width: 400, height: 300))
        XCTAssertEqual(
            sut.axFrame(fromAppKitFrame: appKitFrame),
            CGRect(x: 100, y: 120, width: 400, height: 300)
        )
    }

    func test_OverlayScreenFrameMapper_위쪽_보조화면도_union_maxY로_변환한다() {
        // given
        let sut = OverlayScreenFrameMapper(
            screenFrames: [
                CGRect(x: 0, y: 0, width: 1440, height: 900),
                CGRect(x: 0, y: 900, width: 1440, height: 900)
            ]
        )

        // when
        let appKitFrame = sut.appKitFrame(
            fromAXFrame: CGRect(x: 20, y: 100, width: 300, height: 200)
        )

        // then
        XCTAssertEqual(appKitFrame, CGRect(x: 20, y: 1500, width: 300, height: 200))
    }

    func test_show는_overlay_keyboard입력을_받도록_application을_activate한다() {
        // given
        var activateCallCount = 0
        let sut = OverlayWindowController(
            displayInfoProvider: { _ in
                OverlayDisplayInfo(scaleFactor: 1, visibleFrame: nil)
            },
            applicationActivator: {
                activateCallCount += 1
            }
        )
        let layout = OverlayLayout(
            targetFrame: CGRect(x: 0, y: 0, width: 200, height: 120),
            localBounds: CGRect(x: 0, y: 0, width: 200, height: 120),
            labels: [
                OverlayLabel(
                    id: 0,
                    text: "AA",
                    candidateFrame: CGRect(x: 20, y: 20, width: 30, height: 20),
                    labelFrame: CGRect(x: 20, y: 20, width: 32, height: 22),
                    anchorPoint: CGPoint(x: 35, y: 30)
                )
            ],
            metrics: OverlayLayoutMetrics(
                labelCount: 1,
                collisionCount: 0,
                occlusionCount: 0,
                displayScaleFactor: 1
            ),
            displayInfo: OverlayDisplayInfo(scaleFactor: 1, visibleFrame: nil)
        )

        // when
        sut.show(layout: layout)

        // then
        XCTAssertEqual(activateCallCount, 1)
        XCTAssertTrue(sut.isVisible)

        sut.close()
    }
}
