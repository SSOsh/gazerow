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

    func test_CGCoordinateClickPoster는_클릭후_원래커서위치로_복원한다() {
        // given
        let cursorController = StubMouseCursorController(currentPosition: CGPoint(x: 400, y: 500))
        let eventPoster = StubSingleClickEventPoster(result: .success)
        let sut = CGCoordinateClickPoster(
            cursorController: cursorController,
            clickEventPoster: eventPoster
        )
        let clickPoint = CGPoint(x: 146, y: 128)

        // when
        let result = sut.postSingleLeftClick(at: clickPoint)

        // then
        XCTAssertEqual(result, .success)
        XCTAssertEqual(eventPoster.points, [clickPoint])
        XCTAssertEqual(cursorController.movedPoints, [clickPoint, CGPoint(x: 400, y: 500)])
    }

    func test_CGCoordinateClickPoster는_클릭실패후에도_원래커서위치로_복원한다() {
        // given
        let cursorController = StubMouseCursorController(currentPosition: CGPoint(x: 300, y: 700))
        let eventPoster = StubSingleClickEventPoster(result: .failure("event failed"))
        let sut = CGCoordinateClickPoster(
            cursorController: cursorController,
            clickEventPoster: eventPoster
        )
        let clickPoint = CGPoint(x: 10, y: 20)

        // when
        let result = sut.postSingleLeftClick(at: clickPoint)

        // then
        XCTAssertEqual(result, .failure("event failed"))
        XCTAssertEqual(cursorController.movedPoints, [clickPoint, CGPoint(x: 300, y: 700)])
    }

    func test_CGCoordinateClickPoster는_원래커서위치를_읽지못하면_복원하지_않는다() {
        // given
        let cursorController = StubMouseCursorController(currentPosition: nil)
        let eventPoster = StubSingleClickEventPoster(result: .success)
        let sut = CGCoordinateClickPoster(
            cursorController: cursorController,
            clickEventPoster: eventPoster
        )
        let clickPoint = CGPoint(x: 10, y: 20)

        // when
        let result = sut.postSingleLeftClick(at: clickPoint)

        // then
        XCTAssertEqual(result, .success)
        XCTAssertEqual(cursorController.movedPoints, [clickPoint])
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

private final class StubMouseCursorController: MouseCursorControlling {
    private let position: CGPoint?
    private(set) var movedPoints: [CGPoint] = []

    init(currentPosition: CGPoint?) {
        self.position = currentPosition
    }

    func currentPosition() -> CGPoint? {
        position
    }

    func move(to point: CGPoint) {
        movedPoints.append(point)
    }
}

private final class StubSingleClickEventPoster: SingleClickEventPosting {
    private let result: ClickClientResult
    private(set) var points: [CGPoint] = []

    init(result: ClickClientResult) {
        self.result = result
    }

    func postSingleLeftClickEvent(at point: CGPoint) -> ClickClientResult {
        points.append(point)
        return result
    }
}
