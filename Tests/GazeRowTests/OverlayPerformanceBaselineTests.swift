import CoreGraphics
import XCTest
@testable import GazeRow

/// 대량 overlay 성능 비교에 사용할 고정 후보 fixture를 검증한다.
///
/// @author suho.do
/// @since 2026-07-17
final class OverlayPerformanceBaselineTests: XCTestCase {

    func test_layoutBaselineFixture는_25_100_675개후보의고유label을생성한다() {
        // given
        let sut = OverlayLayoutEngine(
            configuration: OverlayLayoutConfiguration(
                labelSize: CGSize(width: 32, height: 22),
                edgeInset: 0
            )
        )

        // when & then
        for candidateCount in [25, 100, 675] {
            let layout = sut.makeLayout(
                targetFrame: CGRect(x: 0, y: 0, width: 2_300, height: 600),
                candidates: makeCandidates(count: candidateCount)
            )

            XCTAssertEqual(layout.labels.count, candidateCount)
            XCTAssertEqual(Set(layout.labels.map(\.text)).count, candidateCount)
        }
    }

    func test_measure_layoutBaselineFixture_675개후보() {
        // given
        let sut = OverlayLayoutEngine(
            configuration: OverlayLayoutConfiguration(
                labelSize: CGSize(width: 32, height: 22),
                edgeInset: 0
            )
        )
        let candidates = makeCandidates(count: 675)

        // when & then
        measure {
            _ = sut.makeLayout(
                targetFrame: CGRect(x: 0, y: 0, width: 2_300, height: 600),
                candidates: candidates
            )
        }
    }

    private func makeCandidates(count: Int) -> [ClickableCandidate] {
        (0..<count).map { index in
            let column = index % 45
            let row = index / 45
            return ClickableCandidate(
                role: AccessibilityRole.button,
                subrole: nil,
                title: nil,
                frame: CGRect(
                    x: CGFloat(column * 50),
                    y: CGFloat(row * 34),
                    width: 20,
                    height: 18
                ),
                actions: [AccessibilityAction.press]
            )
        }
    }
}
