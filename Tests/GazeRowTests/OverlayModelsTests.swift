import CoreGraphics
import XCTest
@testable import GazeRow

/// overlay 모델 값 타입의 init clamping과 Retina 경계 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class OverlayModelsTests: XCTestCase {

    func test_LayoutConfiguration_기본값() {
        // given
        let sut = OverlayLayoutConfiguration()

        // then
        XCTAssertEqual(sut.labelSize, CGSize(width: 32, height: 22))
        XCTAssertEqual(sut.labelSpacing, 6)
        XCTAssertEqual(sut.edgeInset, 4)
        XCTAssertEqual(sut.collisionShiftLimit, 12)
    }

    func test_LayoutConfiguration_음수_spacing은_0으로_clamp() {
        // given
        let sut = OverlayLayoutConfiguration(labelSpacing: -5)

        // then
        XCTAssertEqual(sut.labelSpacing, 0)
    }

    func test_LayoutConfiguration_음수_edgeInset은_0으로_clamp() {
        // given
        let sut = OverlayLayoutConfiguration(edgeInset: -3)

        // then
        XCTAssertEqual(sut.edgeInset, 0)
    }

    func test_LayoutConfiguration_음수_collisionShiftLimit은_0으로_clamp() {
        // given
        let sut = OverlayLayoutConfiguration(collisionShiftLimit: -2)

        // then
        XCTAssertEqual(sut.collisionShiftLimit, 0)
    }

    func test_DisplayInfo_isRetina_scaleFactor_2이상이면_true() {
        // given
        let sut = OverlayDisplayInfo(scaleFactor: 2, visibleFrame: nil)

        // then
        XCTAssertTrue(sut.isRetina)
    }

    func test_DisplayInfo_isRetina_scaleFactor_2미만이면_false() {
        // given
        let sut = OverlayDisplayInfo(scaleFactor: 1.9, visibleFrame: nil)

        // then
        XCTAssertFalse(sut.isRetina)
    }

    func test_LayoutMetrics_isRetina_displayScaleFactor_경계() {
        // given
        let retina = OverlayLayoutMetrics(
            labelCount: 0,
            collisionCount: 0,
            occlusionCount: 0,
            displayScaleFactor: 2
        )
        let nonRetina = OverlayLayoutMetrics(
            labelCount: 0,
            collisionCount: 0,
            occlusionCount: 0,
            displayScaleFactor: 1
        )

        // then
        XCTAssertTrue(retina.isRetina)
        XCTAssertFalse(nonRetina.isRetina)
    }

    func test_OverlayInteractionStatus_queryBuffer가_nil이면_legacyBuffer를_표시값으로_사용한다() {
        // given
        let sut = OverlayInteractionStatus(typedLabelBuffer: "A")

        // then
        XCTAssertEqual(sut.queryBuffer, "A")
        XCTAssertEqual(sut.displayBuffer, "A")
        XCTAssertEqual(sut.activeScope, .labels)
        XCTAssertEqual(sut.enterActionHint, "click")
    }

    func test_OverlayInteractionStatus_queryBuffer가_있으면_표시값을_우선한다() {
        // given
        let sut = OverlayInteractionStatus(
            typedLabelBuffer: "A",
            queryBuffer: "delete",
            activeScope: .elements,
            matchCount: 2,
            matchIndex: 1,
            focusedDisplayName: "Delete Item",
            highlightFrame: CGRect(x: 10, y: 20, width: 30, height: 40),
            enterActionHint: "click"
        )

        // then
        XCTAssertEqual(sut.displayBuffer, "delete")
        XCTAssertEqual(sut.activeScope, .elements)
        XCTAssertEqual(sut.matchCount, 2)
        XCTAssertEqual(sut.matchIndex, 1)
        XCTAssertEqual(sut.focusedDisplayName, "Delete Item")
        XCTAssertEqual(sut.highlightFrame, CGRect(x: 10, y: 20, width: 30, height: 40))
    }

    func test_StatusBarLayout_큰_창은_하단에_고정하고_기존_위치를_유지한다() {
        // given
        let bounds = CGRect(x: 0, y: 0, width: 360, height: 220)

        // when
        let sut = OverlayStatusBarLayout(bounds: bounds)

        // then
        XCTAssertEqual(sut.width, 344)          // min(360 - 16, 420)
        XCTAssertEqual(sut.centerX, 180)        // 8 + 344 / 2
        XCTAssertEqual(sut.centerY, 186)        // 220 - 34 (하단 고정)
    }

    func test_StatusBarLayout_넓은_창은_최대_폭을_넘지_않는다() {
        // given
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 600)

        // when
        let sut = OverlayStatusBarLayout(bounds: bounds)

        // then
        XCTAssertEqual(sut.width, 420)          // maxWidth clamp
        XCTAssertEqual(sut.centerX, 218)        // 8 + 420 / 2
        XCTAssertEqual(sut.centerY, 566)        // 600 - 34
    }

    func test_StatusBarLayout_작은_창은_상태바를_세로_중앙에_두어_이탈을_막는다() {
        // given: height(40)가 estimatedHeight(44) + bottomInset(34)보다 작다
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 40)

        // when
        let sut = OverlayStatusBarLayout(bounds: bounds)

        // then
        XCTAssertEqual(sut.centerY, 20)         // height / 2 (하단 고정 대신 중앙)
        XCTAssertEqual(sut.width, 184)          // min(200 - 16, 420)
    }

    func test_StatusBarLayout_아주_좁은_창은_폭이_음수가_되지_않는다() {
        // given
        let bounds = CGRect(x: 0, y: 0, width: 10, height: 200)

        // when
        let sut = OverlayStatusBarLayout(bounds: bounds)

        // then
        XCTAssertEqual(sut.width, 0)            // max(0, 10 - 16)
        XCTAssertEqual(sut.centerX, 8)          // 8 + 0 / 2
    }
}
