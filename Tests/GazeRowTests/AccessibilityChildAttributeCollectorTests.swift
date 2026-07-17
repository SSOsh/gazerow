import XCTest
@testable import GazeRow

/// AccessibilityChildAttributeCollector 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class AccessibilityChildAttributeCollectorTests: XCTestCase {

    func test_collect_기본순서는_contents를_children보다_먼저_읽는다() {
        // given
        let sut = AccessibilityChildAttributeCollector<Int>()
        var readAttributes: [String] = []

        // when
        _ = sut.collect { attribute in
            readAttributes.append(attribute)
            return .success([])
        }

        // then
        XCTAssertEqual(readAttributes.prefix(3), ["AXContents", "AXVisibleChildren", "AXChildren"])
    }

    func test_collect_기본순서는_navigation과_visibleRow계열도_읽는다() {
        // given
        let sut = AccessibilityChildAttributeCollector<Int>()
        var readAttributes: [String] = []

        // when
        _ = sut.collect { attribute in
            readAttributes.append(attribute)
            return .success([])
        }

        // then
        XCTAssertTrue(readAttributes.contains("AXChildrenInNavigationOrder"))
        XCTAssertTrue(readAttributes.contains("AXVisibleRows"))
        XCTAssertTrue(readAttributes.contains("AXTabs"))
        XCTAssertTrue(readAttributes.contains("AXSelectedRows"))
    }

    func test_collect_nonEmpty_attribute들을_모두_합쳐서_반환한다() {
        // given
        let sut = AccessibilityChildAttributeCollector<Int>(
            attributes: ["AXChildren", "AXVisibleChildren", "AXContents"]
        )
        var readAttributes: [String] = []

        // when
        let result = sut.collect { attribute in
            readAttributes.append(attribute)
            switch attribute {
            case "AXChildren":
                return .success([1, 2])
            case "AXVisibleChildren":
                return .success([3])
            case "AXContents":
                return .success([4, 5])
            default:
                return .success([])
            }
        }

        // then
        XCTAssertEqual(try? result.get(), [1, 2, 3, 4, 5])
        XCTAssertEqual(readAttributes, ["AXChildren", "AXVisibleChildren", "AXContents"])
    }

    func test_collect_앞_attribute가_실패해도_뒤_attribute가_있으면_성공한다() {
        // given
        let sut = AccessibilityChildAttributeCollector<Int>(
            attributes: ["AXChildren", "AXVisibleChildren"]
        )

        // when
        let result = sut.collect { attribute in
            switch attribute {
            case "AXChildren":
                .failure(.childrenUnavailable("cannot complete"))
            case "AXVisibleChildren":
                .success([7])
            default:
                .success([])
            }
        }

        // then
        XCTAssertEqual(try? result.get(), [7])
    }

    func test_collect_모든_attribute가_비어있으면_빈배열을_반환한다() {
        // given
        let sut = AccessibilityChildAttributeCollector<Int>(
            attributes: ["AXChildren", "AXVisibleChildren"]
        )

        // when
        let result = sut.collect { _ in .success([]) }

        // then
        XCTAssertEqual(try? result.get(), [])
    }

    func test_collect_모든_attribute가_실패하면_첫_실패를_반환한다() {
        // given
        let sut = AccessibilityChildAttributeCollector<Int>(
            attributes: ["AXChildren", "AXVisibleChildren"]
        )

        // when
        let result = sut.collect { attribute in
            .failure(.childrenUnavailable(attribute))
        }

        // then
        XCTAssertEqual(result.failureValue, .childrenUnavailable("AXChildren"))
    }

    func test_collect_batch는_모든_attribute를_한번에_읽는다() {
        // given
        let sut = AccessibilityChildAttributeCollector<Int>(
            attributes: ["AXChildren", "AXVisibleChildren", "AXContents"]
        )
        var batchRequests: [[String]] = []
        var fallbackReadCount = 0

        // when
        let result = sut.collect(
            readBatch: { attributes in
                batchRequests.append(attributes)
                return .success([1, 2, 3])
            },
            fallbackReadElements: { _ in
                fallbackReadCount += 1
                return .success([])
            }
        )

        // then
        XCTAssertEqual(try? result.get(), [1, 2, 3])
        XCTAssertEqual(batchRequests, [["AXChildren", "AXVisibleChildren", "AXContents"]])
        XCTAssertEqual(fallbackReadCount, 0)
    }

    func test_collect_batch가_실패하면_기존_attribute별_조회로_fallback한다() {
        // given
        let sut = AccessibilityChildAttributeCollector<Int>(
            attributes: ["AXChildren", "AXVisibleChildren"]
        )
        var fallbackAttributes: [String] = []

        // when
        let result = sut.collect(
            readBatch: { _ in
                .failure(.childrenUnavailable("batch unsupported"))
            },
            fallbackReadElements: { attribute in
                fallbackAttributes.append(attribute)
                return attribute == "AXVisibleChildren" ? .success([7]) : .success([])
            }
        )

        // then
        XCTAssertEqual(try? result.get(), [7])
        XCTAssertEqual(fallbackAttributes, ["AXChildren", "AXVisibleChildren"])
    }

    func test_collect_batch의_빈결과는_leaf로_처리하고_fallback하지않는다() {
        // given
        let sut = AccessibilityChildAttributeCollector<Int>(
            attributes: ["AXChildren", "AXVisibleChildren"]
        )
        var fallbackReadCount = 0

        // when
        let result = sut.collect(
            readBatch: { _ in .success([]) },
            fallbackReadElements: { _ in
                fallbackReadCount += 1
                return .success([1])
            }
        )

        // then
        XCTAssertEqual(try? result.get(), [])
        XCTAssertEqual(fallbackReadCount, 0)
    }
}

private extension Result where Failure == AccessibilityScanFailure {
    var failureValue: AccessibilityScanFailure? {
        if case .failure(let failure) = self {
            return failure
        }
        return nil
    }
}
