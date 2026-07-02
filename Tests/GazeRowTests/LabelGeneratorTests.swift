import XCTest
@testable import GazeRow

/// LabelGenerator 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class LabelGeneratorTests: XCTestCase {

    func test_labels_26개_이하는_한글자_label을_생성() {
        // given
        let sut = LabelGenerator()

        // when
        let labels = sut.labels(count: 26)

        // then
        XCTAssertEqual(labels.first, "A")
        XCTAssertEqual(labels.last, "Z")
        XCTAssertEqual(Set(labels).count, 26)
    }

    func test_labels_26개_초과는_prefix충돌_없는_고정길이_label을_생성() {
        // given
        let sut = LabelGenerator()

        // when
        let labels = sut.labels(count: 28)

        // then
        XCTAssertEqual(labels[0], "AA")
        XCTAssertEqual(labels[25], "AZ")
        XCTAssertEqual(labels[26], "BA")
        XCTAssertEqual(labels[27], "BB")
        XCTAssertFalse(hasPrefixCollision(labels))
    }

    func test_labels_빈_count는_빈배열() {
        // given
        let sut = LabelGenerator()

        // when
        let labels = sut.labels(count: 0)

        // then
        XCTAssertTrue(labels.isEmpty)
    }

    private func hasPrefixCollision(_ labels: [String]) -> Bool {
        for label in labels {
            if labels.contains(where: { $0 != label && $0.hasPrefix(label) }) {
                return true
            }
        }

        return false
    }
}
