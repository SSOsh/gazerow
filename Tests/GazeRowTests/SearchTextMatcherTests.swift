import XCTest
@testable import GazeRow

/// SearchTextMatcher 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-12
final class SearchTextMatcherTests: XCTestCase {

    func test_match_exact_prefix_contains를_우선_구분한다() {
        // when & then
        XCTAssertEqual(SearchTextMatcher.match(value: "Delete", query: "delete"), .exact)
        XCTAssertEqual(SearchTextMatcher.match(value: "Delete Item", query: "del"), .prefix)
        XCTAssertEqual(SearchTextMatcher.match(value: "Open Delete Item", query: "delete"), .contains)
    }

    func test_match_약어를_acronym으로_매칭한다() {
        // when
        let result = SearchTextMatcher.match(value: "Visual Studio Code", query: "vsc")

        // then
        XCTAssertEqual(result, .acronym)
    }

    func test_match_순서만_맞는_입력은_subsequence로_매칭한다() {
        // when
        let result = SearchTextMatcher.match(value: "Delete Item", query: "dlt")

        // then
        XCTAssertEqual(result, .subsequence)
    }

    func test_match_공백과_구분자를_제거한_contains를_지원한다() {
        // when
        let result = SearchTextMatcher.match(value: "README - Project Notes", query: "readmeproject")

        // then
        XCTAssertEqual(result, .contains)
    }
}
