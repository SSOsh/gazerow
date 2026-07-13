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
        XCTAssertTrue(sut.usesAdaptivePlacementForDenseLayouts)
        XCTAssertEqual(sut.denseCandidateThreshold, 24)
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

    func test_LayoutConfiguration_denseThreshold는_최소2로_clamp() {
        // given
        let sut = OverlayLayoutConfiguration(denseCandidateThreshold: -1)

        // then
        XCTAssertEqual(sut.denseCandidateThreshold, 2)
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

    func test_OverlayLabel_displayText는_여러글자도_모두_대문자로_표시한다() {
        // given
        let sut = OverlayLabel(
            id: 0,
            text: "aa",
            candidateFrame: .zero,
            labelFrame: .zero,
            anchorPoint: .zero
        )

        // then
        XCTAssertEqual(sut.displayText, "AA")
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
        XCTAssertEqual(sut.phase, .idle)
        XCTAssertFalse(sut.requiresSecondConfirm)
    }

    func test_OverlayInteractionStatus_위험확인상태를명시적으로표현한다() {
        // given
        let sut = OverlayInteractionStatus(
            message: "Confirm again",
            tone: .warning,
            phase: .awaitingRiskConfirmation,
            requiresSecondConfirm: true
        )

        // then
        XCTAssertEqual(sut.phase, .awaitingRiskConfirmation)
        XCTAssertTrue(sut.requiresSecondConfirm)
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
            enterActionHint: "click"
        )

        // then
        XCTAssertEqual(sut.displayBuffer, "delete")
        XCTAssertEqual(sut.activeScope, .elements)
        XCTAssertEqual(sut.matchCount, 2)
        XCTAssertEqual(sut.matchIndex, 1)
        XCTAssertEqual(sut.focusedDisplayName, "Delete Item")
    }

}
