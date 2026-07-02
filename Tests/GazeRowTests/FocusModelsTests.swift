import CoreGraphics
import XCTest
@testable import GazeRow

/// `FocusItem`의 label 정규화 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class FocusModelsTests: XCTestCase {

    func test_FocusItem_label은_대문자로_저장() {
        // given
        let sut = FocusItem(id: 1, label: "ab", frame: .zero)

        // then
        XCTAssertEqual(sut.label, "AB")
    }

    func test_FocusItem_이미_대문자면_그대로_유지() {
        // given
        let sut = FocusItem(id: 2, label: "XY", frame: .zero)

        // then
        XCTAssertEqual(sut.label, "XY")
    }

    func test_FocusItem_id와_frame은_보존() {
        // given
        let frame = CGRect(x: 10, y: 20, width: 30, height: 40)
        let sut = FocusItem(id: 7, label: "qz", frame: frame)

        // then
        XCTAssertEqual(sut.id, 7)
        XCTAssertEqual(sut.frame, frame)
        XCTAssertEqual(sut.label, "QZ")
    }
}
