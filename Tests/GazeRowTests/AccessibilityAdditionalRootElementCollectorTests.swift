import CoreGraphics
import XCTest
@testable import GazeRow

/// AccessibilityAdditionalRootElementCollector 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-12
final class AccessibilityAdditionalRootElementCollectorTests: XCTestCase {

    func test_collect_focusedElement와_relatedAncestor를_함께_반환한다() {
        // given
        let sut = AccessibilityAdditionalRootElementCollector<Int> { AnyHashable($0) }
        let frames: [Int: CGRect] = [
            1: CGRect(x: 20, y: 20, width: 100, height: 30),
            2: CGRect(x: 10, y: 10, width: 130, height: 50)
        ]

        // when
        let result = sut.collect(
            focusedElement: 1,
            within: CGRect(x: 0, y: 0, width: 200, height: 200),
            relatedElement: { attribute, _ in
                attribute == "AXEditableAncestor" ? 2 : nil
            },
            elementFrame: { frames[$0] }
        )

        // then
        XCTAssertEqual(result, [1, 2])
    }

    func test_collect_focusedElement_frame이_없어도_relatedAncestor를_반환한다() {
        // given
        let sut = AccessibilityAdditionalRootElementCollector<Int> { AnyHashable($0) }
        let frames: [Int: CGRect] = [
            2: CGRect(x: 10, y: 10, width: 130, height: 50)
        ]

        // when
        let result = sut.collect(
            focusedElement: 1,
            within: CGRect(x: 0, y: 0, width: 200, height: 200),
            relatedElement: { attribute, _ in
                attribute == "AXFocusableAncestor" ? 2 : nil
            },
            elementFrame: { frames[$0] }
        )

        // then
        XCTAssertEqual(result, [2])
    }

    func test_collect_targetFrame밖의_relatedElement는_제외한다() {
        // given
        let sut = AccessibilityAdditionalRootElementCollector<Int> { AnyHashable($0) }
        let frames: [Int: CGRect] = [
            1: CGRect(x: 10, y: 10, width: 80, height: 20),
            2: CGRect(x: 500, y: 500, width: 130, height: 50)
        ]

        // when
        let result = sut.collect(
            focusedElement: 1,
            within: CGRect(x: 0, y: 0, width: 200, height: 200),
            relatedElement: { _, _ in 2 },
            elementFrame: { frames[$0] }
        )

        // then
        XCTAssertEqual(result, [1])
    }

    func test_collect_relatedElement_중복은_제거한다() {
        // given
        let sut = AccessibilityAdditionalRootElementCollector<Int> { AnyHashable($0) }
        let frames: [Int: CGRect] = [
            1: CGRect(x: 10, y: 10, width: 80, height: 20)
        ]

        // when
        let result = sut.collect(
            focusedElement: 1,
            within: CGRect(x: 0, y: 0, width: 200, height: 200),
            relatedElement: { _, _ in 1 },
            elementFrame: { frames[$0] }
        )

        // then
        XCTAssertEqual(result, [1])
    }
}
