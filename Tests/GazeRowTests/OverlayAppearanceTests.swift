import XCTest
@testable import GazeRow

/// OverlayAppearance 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-07
final class OverlayAppearanceTests: XCTestCase {

    func test_기본값은_뒤_콘텐츠가_보이도록_label배경을_반투명하게_유지() {
        // given
        let sut = OverlayAppearance()

        // then
        XCTAssertEqual(sut.labelBackgroundOpacity, 0.62, accuracy: 0.0001)
        XCTAssertEqual(sut.labelTextOpacity, 1.0, accuracy: 0.0001)
        XCTAssertEqual(sut.markerFillOpacity, 0.06, accuracy: 0.0001)
        XCTAssertEqual(sut.boundaryOpacity, 0.75, accuracy: 0.0001)
    }

    func test_상한을_초과하면_상한으로_clamp() {
        // given
        let sut = OverlayAppearance(
            labelBackgroundOpacity: 5.0,
            labelTextOpacity: 5.0,
            markerFillOpacity: 5.0,
            boundaryOpacity: 5.0
        )

        // then
        XCTAssertEqual(sut.labelBackgroundOpacity, 1.0, accuracy: 0.0001)
        XCTAssertEqual(sut.labelTextOpacity, 1.0, accuracy: 0.0001)
        XCTAssertEqual(sut.markerFillOpacity, 0.4, accuracy: 0.0001)
        XCTAssertEqual(sut.boundaryOpacity, 1.0, accuracy: 0.0001)
    }

    func test_하한_미만이면_하한으로_clamp() {
        // given
        let sut = OverlayAppearance(
            labelBackgroundOpacity: -1.0,
            labelTextOpacity: -1.0,
            markerFillOpacity: -1.0,
            boundaryOpacity: -1.0
        )

        // then
        XCTAssertEqual(sut.labelBackgroundOpacity, 0.4, accuracy: 0.0001)
        XCTAssertEqual(sut.labelTextOpacity, 0.6, accuracy: 0.0001)
        XCTAssertEqual(sut.markerFillOpacity, 0.0, accuracy: 0.0001)
        XCTAssertEqual(sut.boundaryOpacity, 0.0, accuracy: 0.0001)
    }

    func test_범위_안의_값은_그대로_유지() {
        // given
        let sut = OverlayAppearance(
            labelBackgroundOpacity: 0.6,
            labelTextOpacity: 0.8,
            markerFillOpacity: 0.2,
            boundaryOpacity: 0.5
        )

        // then
        XCTAssertEqual(sut.labelBackgroundOpacity, 0.6, accuracy: 0.0001)
        XCTAssertEqual(sut.labelTextOpacity, 0.8, accuracy: 0.0001)
        XCTAssertEqual(sut.markerFillOpacity, 0.2, accuracy: 0.0001)
        XCTAssertEqual(sut.boundaryOpacity, 0.5, accuracy: 0.0001)
    }
}
