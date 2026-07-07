import CoreGraphics
import XCTest
@testable import GazeRow

/// CandidateOrdering 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-07
final class CandidateOrderingTests: XCTestCase {

    func test_ordered_같은_행이면_x_오름차순으로_정렬() {
        // given
        let candidates = [
            makeCandidate(x: 300, y: 100),
            makeCandidate(x: 100, y: 100),
            makeCandidate(x: 200, y: 100)
        ]
        let sut = CandidateOrdering()

        // when
        let order = sut.ordered(candidates)

        // then
        XCTAssertEqual(order, [1, 2, 0])
    }

    func test_ordered_여러_행이면_좌상에서_우하_순서로_정렬() {
        // given
        let candidates = [
            makeCandidate(x: 200, y: 300),
            makeCandidate(x: 100, y: 100),
            makeCandidate(x: 300, y: 100),
            makeCandidate(x: 50, y: 300)
        ]
        let sut = CandidateOrdering()

        // when
        let order = sut.ordered(candidates)

        // then
        XCTAssertEqual(order, [1, 2, 3, 0])
    }

    func test_ordered_밴드_안의_미세한_y차이는_x우선으로_같은_행_취급() {
        // given
        // 세 후보의 midY(= y + height/2)가 모두 같은 밴드에 들도록 rowBandHeight를 크게 둔다.
        let candidates = [
            makeCandidate(x: 300, y: 105),
            makeCandidate(x: 100, y: 100),
            makeCandidate(x: 200, y: 110)
        ]
        let sut = CandidateOrdering(rowBandHeight: 100)

        // when
        let order = sut.ordered(candidates)

        // then
        XCTAssertEqual(order, [1, 2, 0])
    }

    func test_ordered_밴드_경계를_넘으면_아래_행으로_분리() {
        // given
        let candidates = [
            makeCandidate(x: 300, y: 130),
            makeCandidate(x: 100, y: 100)
        ]
        let sut = CandidateOrdering(rowBandHeight: 24)

        // when
        let order = sut.ordered(candidates)

        // then
        XCTAssertEqual(order, [1, 0])
    }

    func test_ordered_완전히_같은_좌표는_원본_index순서로_stable() {
        // given
        let candidates = [
            makeCandidate(x: 100, y: 100),
            makeCandidate(x: 100, y: 100),
            makeCandidate(x: 100, y: 100)
        ]
        let sut = CandidateOrdering()

        // when
        let order = sut.ordered(candidates)

        // then
        XCTAssertEqual(order, [0, 1, 2])
    }

    func test_ordered_빈_배열은_빈_순열을_반환() {
        // given
        let sut = CandidateOrdering()

        // when
        let order = sut.ordered([])

        // then
        XCTAssertTrue(order.isEmpty)
    }

    func test_ordered_단일_후보는_그대로_반환() {
        // given
        let candidates = [makeCandidate(x: 10, y: 10)]
        let sut = CandidateOrdering()

        // when
        let order = sut.ordered(candidates)

        // then
        XCTAssertEqual(order, [0])
    }

    private func makeCandidate(x: CGFloat, y: CGFloat) -> ClickableCandidate {
        ClickableCandidate(
            role: AccessibilityRole.button,
            subrole: nil,
            title: "Button",
            frame: CGRect(x: x, y: y, width: 20, height: 20),
            actions: [AccessibilityAction.press]
        )
    }
}
