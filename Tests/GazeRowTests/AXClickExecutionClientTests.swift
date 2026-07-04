import ApplicationServices
import CoreGraphics
import XCTest
@testable import GazeRow

/// AXClickExecutionClient 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-04
final class AXClickExecutionClientTests: XCTestCase {

    func test_performCoordinateClick은_좌표클릭poster에_point를_전달한다() {
        // given
        let poster = StubCoordinateClickPoster(result: .success)
        let sut = AXClickExecutionClient(coordinateClickPoster: poster)
        let point = CGPoint(x: 146, y: 128)

        // when
        let result = sut.performCoordinateClick(at: point)

        // then
        XCTAssertEqual(result, .success)
        XCTAssertEqual(poster.points, [point])
    }

    func test_performCoordinateClick은_poster실패를_전달한다() {
        // given
        let poster = StubCoordinateClickPoster(result: .failure("event failed"))
        let sut = AXClickExecutionClient(coordinateClickPoster: poster)

        // when
        let result = sut.performCoordinateClick(at: CGPoint(x: 10, y: 20))

        // then
        XCTAssertEqual(result, .failure("event failed"))
    }
}

private final class StubCoordinateClickPoster: CoordinateClickPosting {
    private let result: ClickClientResult
    private(set) var points: [CGPoint] = []

    init(result: ClickClientResult) {
        self.result = result
    }

    func postSingleLeftClick(at point: CGPoint) -> ClickClientResult {
        points.append(point)
        return result
    }
}
