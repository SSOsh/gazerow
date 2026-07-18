import XCTest
@testable import GazeRow

/// BrowserTabCountFetcher 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-18
final class BrowserTabCountFetcherTests: XCTestCase {

    func test_tabCounts_스크립트_출력을_창제목별_탭개수로_파싱한다() {
        // given
        let sut = BrowserTabCountFetcher()
        let output = "Gmail\u{1F}5\u{1E}GitHub\u{1F}2\u{1E}"

        // when
        let result = sut.tabCounts(for: .init(bundleID: "com.google.Chrome")) { _ in output }

        // then
        XCTAssertEqual(result, ["Gmail": 5, "GitHub": 2])
    }

    func test_tabCounts_스크립트가_nil을_반환하면_빈결과다() {
        // given: Firefox처럼 탭 스크립팅을 지원하지 않는 브라우저를 흉내낸다
        let sut = BrowserTabCountFetcher()

        // when
        let result = sut.tabCounts(for: .init(bundleID: "org.mozilla.firefox")) { _ in nil }

        // then
        XCTAssertTrue(result.isEmpty)
    }

    func test_tabCounts_빈문자열이면_빈결과다() {
        // given
        let sut = BrowserTabCountFetcher()

        // when
        let result = sut.tabCounts(for: .init(bundleID: "com.google.Chrome")) { _ in "" }

        // then
        XCTAssertTrue(result.isEmpty)
    }

    func test_tabCounts_형식이_깨진_record는_건너뛴다() {
        // given
        let sut = BrowserTabCountFetcher()
        let output = "Gmail\u{1F}notanumber\u{1E}GitHub\u{1F}2\u{1E}"

        // when
        let result = sut.tabCounts(for: .init(bundleID: "com.google.Chrome")) { _ in output }

        // then
        XCTAssertEqual(result, ["GitHub": 2])
    }

    func test_knownBrowsers_Safari는_windowTitleProperty로_name을_쓴다() {
        // given & when
        let safari = BrowserTabCountFetcher.knownBrowsers.first { $0.bundleID == "com.apple.Safari" }

        // then
        XCTAssertEqual(safari?.windowTitleProperty, "name")
    }

    func test_knownBrowsers_Chrome계열은_windowTitleProperty로_title을_쓴다() {
        // given & when
        let chrome = BrowserTabCountFetcher.knownBrowsers.first { $0.bundleID == "com.google.Chrome" }
        let brave = BrowserTabCountFetcher.knownBrowsers.first { $0.bundleID == "com.brave.Browser" }

        // then
        XCTAssertEqual(chrome?.windowTitleProperty, "title")
        XCTAssertEqual(brave?.windowTitleProperty, "title")
    }
}
