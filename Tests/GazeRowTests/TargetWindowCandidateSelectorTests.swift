import CoreGraphics
import XCTest
@testable import GazeRow

/// `TargetWindowCandidateSelector`의 usable window 선택 규칙을 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class TargetWindowCandidateSelectorTests: XCTestCase {

    func test_firstUsableWindow_첫번째_usable_window를_반환() {
        // given
        let invalidWindow = TargetWindow(frame: CGRect(x: 0, y: 0, width: 0, height: 100), title: "Invalid")
        let usableWindow = TargetWindow(frame: CGRect(x: 10, y: 20, width: 300, height: 200), title: "Usable")
        let sut = TargetWindowCandidateSelector()

        // when
        let result = sut.firstUsableWindow(from: [invalidWindow, usableWindow])

        // then
        XCTAssertEqual(result, usableWindow)
    }

    func test_firstUsableWindow_usable_window가_없으면_nil() {
        // given
        let candidates = [
            TargetWindow(frame: CGRect(x: 0, y: 0, width: 0, height: 100), title: "No width"),
            TargetWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 0), title: "No height")
        ]
        let sut = TargetWindowCandidateSelector()

        // when
        let result = sut.firstUsableWindow(from: candidates)

        // then
        XCTAssertNil(result)
    }
}
