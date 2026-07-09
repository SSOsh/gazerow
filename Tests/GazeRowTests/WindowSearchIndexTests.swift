import XCTest
@testable import GazeRow

/// WindowSearchIndex 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-09
final class WindowSearchIndexTests: XCTestCase {

    func test_search_windowTitle_exact가_가장_높은_score를_반환한다() {
        // given
        let sut = WindowSearchIndex(entries: [
            entry(id: 0, appName: "Slack", title: "#general"),
            entry(id: 1, appName: "General", title: nil)
        ])

        // when
        let matches = sut.search("#general")

        // then
        XCTAssertEqual(matches.first, WindowMatch(entryID: 0, score: 200, displayLine: "Slack — #general"))
    }

    func test_search_appName_contains도_검색된다() {
        // given
        let sut = WindowSearchIndex(entries: [
            entry(id: 0, appName: "Visual Studio Code", bundleID: "com.microsoft.VSCode", title: "README.md")
        ])

        // when
        let matches = sut.search("code")

        // then
        XCTAssertEqual(matches.map(\.entryID), [0])
        XCTAssertEqual(matches.first?.score, 60)
    }

    func test_search_bundleID_contains는_낮은_score로_검색된다() {
        // given
        let sut = WindowSearchIndex(entries: [
            entry(id: 0, appName: "Preview", bundleID: "com.apple.Preview", title: nil)
        ])

        // when
        let matches = sut.search("apple.preview")

        // then
        XCTAssertEqual(matches.first?.entryID, 0)
        XCTAssertEqual(matches.first?.score, 40)
    }

    func test_search_emptyQuery는_빈배열을_반환한다() {
        // given
        let sut = WindowSearchIndex(entries: [entry(id: 0, appName: "Finder", title: nil)])

        // when & then
        XCTAssertTrue(sut.search("").isEmpty)
        XCTAssertTrue(sut.search("   ").isEmpty)
    }

    func test_isStale은_30초_초과시_true다() {
        // given
        let builtAt = Date(timeIntervalSince1970: 100)
        let sut = WindowSearchIndex(entries: [], builtAt: builtAt)

        // when & then
        XCTAssertFalse(sut.isStale(now: Date(timeIntervalSince1970: 130)))
        XCTAssertTrue(sut.isStale(now: Date(timeIntervalSince1970: 131)))
    }

    private func entry(
        id: Int,
        appName: String,
        bundleID: String = "com.example.app",
        title: String?
    ) -> WindowEntry {
        WindowEntry(
            id: id,
            appName: appName,
            bundleID: bundleID,
            windowTitle: title,
            windowTitleHash: title.map { "hash-\($0)" },
            pid: pid_t(id + 100),
            axWindow: nil,
            appIcon: nil
        )
    }
}
