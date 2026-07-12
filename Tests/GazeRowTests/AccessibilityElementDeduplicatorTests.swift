import XCTest
@testable import GazeRow

/// AccessibilityElementDeduplicator 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-12
final class AccessibilityElementDeduplicatorTests: XCTestCase {

    func test_deduplicated는_같은_key의_첫_element만_유지한다() {
        // given
        let sut = AccessibilityElementDeduplicator<TestElement> { element in
            AnyHashable(element.identifier)
        }
        let elements = [
            TestElement(identifier: 1, value: "first"),
            TestElement(identifier: 2, value: "second"),
            TestElement(identifier: 1, value: "duplicate")
        ]

        // when
        let result = sut.deduplicated(elements)

        // then
        XCTAssertEqual(result.map(\.value), ["first", "second"])
    }

    func test_deduplicated는_빈배열이면_빈배열을_반환한다() {
        // given
        let sut = AccessibilityElementDeduplicator<TestElement> { element in
            AnyHashable(element.identifier)
        }

        // when
        let result = sut.deduplicated([])

        // then
        XCTAssertTrue(result.isEmpty)
    }

}

private struct TestElement {
    let identifier: Int
    let value: String
}
