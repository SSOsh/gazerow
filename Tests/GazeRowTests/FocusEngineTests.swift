import CoreGraphics
import XCTest
@testable import GazeRow

/// FocusEngine 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class FocusEngineTests: XCTestCase {

    func test_init_초기_focus는_첫번째_item() {
        // given
        let sut = FocusEngine(items: items)

        // then
        XCTAssertEqual(sut.focusedItemID, 0)
    }

    func test_move_next_Tab_다음_item으로_순환() {
        // given
        var sut = FocusEngine(items: items)

        // when
        let firstEvent = sut.move(.next)
        let secondEvent = sut.move(.next)
        let thirdEvent = sut.move(.next)

        // then
        XCTAssertEqual(sut.focusedItemID, 0)
        XCTAssertEqual(firstEvent, .focusChanged(from: 0, to: 1, method: .tab))
        XCTAssertEqual(secondEvent, .focusChanged(from: 1, to: 2, method: .tab))
        XCTAssertEqual(thirdEvent, .focusChanged(from: 2, to: 0, method: .tab))
    }

    func test_move_previous_ShiftTab_이전_item으로_순환() {
        // given
        var sut = FocusEngine(items: items)

        // when
        let event = sut.move(.previous)

        // then
        XCTAssertEqual(sut.focusedItemID, 2)
        XCTAssertEqual(event, .focusChanged(from: 0, to: 2, method: .shiftTab))
    }

    func test_move_down_가장가까운_아래_item으로_이동() {
        // given
        var sut = FocusEngine(items: items)

        // when
        let event = sut.move(.down)

        // then
        XCTAssertEqual(sut.focusedItemID, 1)
        XCTAssertEqual(event, .focusChanged(from: 0, to: 1, method: .arrowDown))
    }

    func test_move_up_가장가까운_위_item으로_이동() {
        // given
        var sut = FocusEngine(items: items, initialFocusedItemID: 2)

        // when
        let event = sut.move(.up)

        // then
        XCTAssertEqual(sut.focusedItemID, 1)
        XCTAssertEqual(event, .focusChanged(from: 2, to: 1, method: .arrowUp))
    }

    func test_typeLabelCharacter_정확히_일치하면_labelJump_성공() {
        // given
        var sut = FocusEngine(items: items)

        // when
        let result = sut.typeLabelCharacter("C")

        // then
        XCTAssertEqual(sut.focusedItemID, 2)
        XCTAssertEqual(result.matchedItemID, 2)
        XCTAssertTrue(result.isExactMatch)
        XCTAssertEqual(result.event, .labelJump(typedLabel: "C", matched: true, to: 2))
    }

    func test_typeLabelCharacter_prefix_match는_buffer를_유지하고_event없음() {
        // given
        var sut = FocusEngine(
            items: [
                FocusItem(id: 0, label: "AA", frame: CGRect(x: 0, y: 0, width: 10, height: 10)),
                FocusItem(id: 1, label: "AB", frame: CGRect(x: 0, y: 20, width: 10, height: 10))
            ]
        )

        // when
        let result = sut.typeLabelCharacter("A")

        // then
        XCTAssertEqual(result.buffer, "A")
        XCTAssertNil(result.event)
        XCTAssertEqual(sut.focusedItemID, 0)
    }

    func test_typeLabelCharacter_일치하지_않으면_labelJump_miss_기록하고_buffer초기화() {
        // given
        var sut = FocusEngine(items: items)

        // when
        let result = sut.typeLabelCharacter("X")

        // then
        XCTAssertEqual(result.buffer, "")
        XCTAssertFalse(result.isExactMatch)
        XCTAssertEqual(result.event, .labelJump(typedLabel: "X", matched: false, to: nil))
    }

    func test_dryRunConfirm은_실제_click없이_focus_event만_반환() {
        // given
        let sut = FocusEngine(items: items, initialFocusedItemID: 1)

        // when
        let result = sut.dryRunConfirm()

        // then
        XCTAssertEqual(result.focusedItemID, 1)
        XCTAssertEqual(result.event, .dryRunConfirm(index: 1))
    }

    func test_init_layout에서_focus_item을_생성() {
        // given
        let layout = OverlayLayout(
            targetFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            localBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            labels: [
                OverlayLabel(
                    id: 4,
                    text: "D",
                    candidateFrame: CGRect(x: 10, y: 20, width: 10, height: 10),
                    labelFrame: CGRect(x: 10, y: 0, width: 20, height: 10),
                    anchorPoint: CGPoint(x: 15, y: 25)
                )
            ],
            metrics: OverlayLayoutMetrics(
                labelCount: 1,
                collisionCount: 0,
                occlusionCount: 0,
                displayScaleFactor: 2
            ),
            displayInfo: OverlayDisplayInfo(scaleFactor: 2, visibleFrame: nil)
        )

        // when
        let sut = FocusEngine(layout: layout)

        // then
        XCTAssertEqual(sut.focusedItemID, 4)
        XCTAssertEqual(sut.items.first?.label, "D")
    }

    private var items: [FocusItem] {
        [
            FocusItem(id: 0, label: "A", frame: CGRect(x: 0, y: 0, width: 10, height: 10)),
            FocusItem(id: 1, label: "B", frame: CGRect(x: 0, y: 20, width: 10, height: 10)),
            FocusItem(id: 2, label: "C", frame: CGRect(x: 0, y: 40, width: 10, height: 10))
        ]
    }
}
