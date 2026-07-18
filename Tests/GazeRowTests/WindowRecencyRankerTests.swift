import CoreGraphics
import XCTest
@testable import GazeRow

/// WindowRecencyRanker 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-18
final class WindowRecencyRankerTests: XCTestCase {

    func test_ranks_전면부터_순서대로_rank를_부여한다() {
        // given
        let sut = WindowRecencyRanker()
        let frontFrame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let backFrame = CGRect(x: 100, y: 100, width: 400, height: 300)

        // when
        let result = sut.ranks {
            [
                self.windowInfo(pid: 111, frame: frontFrame),
                self.windowInfo(pid: 222, frame: backFrame)
            ]
        }

        // then
        XCTAssertEqual(result[WindowRecencyKey(pid: 111, frame: frontFrame)], 0)
        XCTAssertEqual(result[WindowRecencyKey(pid: 222, frame: backFrame)], 1)
    }

    func test_ranks_필수_필드가_없는_항목은_건너뛴다() {
        // given
        let sut = WindowRecencyRanker()

        // when
        let result = sut.ranks { [["SomeKey": "value" as AnyObject]] }

        // then
        XCTAssertTrue(result.isEmpty)
    }

    func test_ranks_같은_pid_frame이_중복되면_먼저_나온_rank를_유지한다() {
        // given
        let sut = WindowRecencyRanker()
        let frame = CGRect(x: 0, y: 0, width: 200, height: 200)

        // when
        let result = sut.ranks {
            [
                self.windowInfo(pid: 1, frame: frame),
                self.windowInfo(pid: 1, frame: frame)
            ]
        }

        // then
        XCTAssertEqual(result[WindowRecencyKey(pid: 1, frame: frame)], 0)
        XCTAssertEqual(result.count, 1)
    }

    func test_ranks_비어있으면_빈_결과를_반환한다() {
        // given
        let sut = WindowRecencyRanker()

        // when
        let result = sut.ranks { [] }

        // then
        XCTAssertTrue(result.isEmpty)
    }

    private func windowInfo(pid: pid_t, frame: CGRect) -> [String: AnyObject] {
        [
            kCGWindowOwnerPID as String: NSNumber(value: pid),
            kCGWindowBounds as String: frame.dictionaryRepresentation
        ]
    }
}
