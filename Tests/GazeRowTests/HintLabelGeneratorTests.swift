import XCTest
@testable import GazeRow

/// HintLabelGenerator 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-07
final class HintLabelGeneratorTests: XCTestCase {

    func test_labels_count가_0이면_빈배열() {
        // given
        let sut = HintLabelGenerator()

        // when
        let labels = sut.labels(count: 0)

        // then
        XCTAssertTrue(labels.isEmpty)
    }

    func test_labels_후보가_1개면_홈로우_첫키_1글자() {
        // given
        let sut = HintLabelGenerator()

        // when
        let labels = sut.labels(count: 1)

        // then
        XCTAssertEqual(labels, ["A"])
    }

    func test_labels_키개수_이하이면_홈로우_우선_1글자로만_배정() {
        // given
        let sut = HintLabelGenerator()

        // when
        let labels = sut.labels(count: 5)

        // then
        XCTAssertEqual(labels, ["A", "S", "D", "F", "G"])
    }

    func test_labels_키개수와_같으면_전부_고유한_1글자() {
        // given
        let sut = HintLabelGenerator()

        // when
        let labels = sut.labels(count: 26)

        // then
        XCTAssertEqual(labels.count, 26)
        XCTAssertTrue(labels.allSatisfy { $0.count == 1 })
        XCTAssertEqual(Set(labels).count, 26)
    }

    func test_labels_키개수_초과_제곱이하이면_대부분_1글자_일부만_2글자() {
        // given
        let sut = HintLabelGenerator()

        // when
        let labels = sut.labels(count: 30)

        // then
        XCTAssertEqual(labels.count, 30)
        let singleCount = labels.filter { $0.count == 1 }.count
        let doubleCount = labels.filter { $0.count == 2 }.count
        XCTAssertEqual(singleCount, 25)
        XCTAssertEqual(doubleCount, 5)
        XCTAssertTrue(isPrefixFree(labels))
    }

    func test_labels_제곱_초과이면_균일폭이라_prefixFree() {
        // given
        let sut = HintLabelGenerator()

        // when
        let labels = sut.labels(count: 1000)

        // then
        XCTAssertEqual(labels.count, 1000)
        XCTAssertEqual(Set(labels.map(\.count)).count, 1)
        XCTAssertEqual(Set(labels).count, 1000)
        XCTAssertTrue(isPrefixFree(labels))
    }

    func test_labels_2글자_label의_prefix는_1글자_label과_겹치지_않음() {
        // given
        let sut = HintLabelGenerator()

        // when
        let labels = sut.labels(count: 40)

        // then
        let singles = Set(labels.filter { $0.count == 1 })
        let twoCharPrefixes = Set(labels.filter { $0.count == 2 }.map { String($0.prefix(1)) })
        XCTAssertTrue(singles.isDisjoint(with: twoCharPrefixes))
    }

    func test_labels_키가_1개뿐이면_고유_label을_반환하고_무한루프에_빠지지_않음() {
        // given
        // 단일 키는 prefix-free가 불가능하므로, 길이를 늘려 고유성만 보장한다.
        let sut = HintLabelGenerator(keys: "A")

        // when
        let labels = sut.labels(count: 3)

        // then
        XCTAssertEqual(labels, ["A", "AA", "AAA"])
        XCTAssertEqual(Set(labels).count, 3)
    }

    func test_labels_커스텀_키셋_정규화하고_중복_비문자_제거() {
        // given
        let sut = HintLabelGenerator(keys: "a-a b!b")

        // when
        let labels = sut.labels(count: 2)

        // then
        XCTAssertEqual(labels, ["A", "B"])
    }

    /// 어떤 label도 다른 label의 prefix가 아님을 검증한다.
    private func isPrefixFree(_ labels: [String]) -> Bool {
        for outer in labels {
            for inner in labels where outer != inner {
                if inner.hasPrefix(outer) {
                    return false
                }
            }
        }
        return true
    }
}
