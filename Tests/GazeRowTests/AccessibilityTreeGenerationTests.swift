import ApplicationServices
import XCTest
@testable import GazeRow

/// AX tree generation 값 모델을 검증한다.
///
/// @author suho.do
/// @since 2026-07-17
final class AccessibilityTreeGenerationTests: XCTestCase {

    func test_advanced는_generation을하나증가시킨다() {
        // given
        let sut = AccessibilityTreeGeneration(value: 41)

        // when
        let result = sut.advanced()

        // then
        XCTAssertEqual(result, AccessibilityTreeGeneration(value: 42))
    }

    func test_advanced는_max에서initial로순환한다() {
        // given
        let sut = AccessibilityTreeGeneration(value: .max)

        // when
        let result = sut.advanced()

        // then
        XCTAssertEqual(result, .initial)
    }

    @MainActor
    func test_changeKind는_AXnotification을_비식별종류로변환한다() {
        XCTAssertEqual(
            AXAccessibilityChangeMonitor.changeKind(for: kAXLayoutChangedNotification),
            .layout
        )
        XCTAssertEqual(
            AXAccessibilityChangeMonitor.changeKind(for: kAXMovedNotification),
            .geometry
        )
        XCTAssertEqual(
            AXAccessibilityChangeMonitor.changeKind(for: "UnknownNotification"),
            .unknown
        )
    }
}
