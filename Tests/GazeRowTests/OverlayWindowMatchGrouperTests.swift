import XCTest
@testable import GazeRow

/// OverlayWindowMatchGrouper 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-18
final class OverlayWindowMatchGrouperTests: XCTestCase {

    func test_grouped_같은앱_창이_하나뿐이면_그대로_반환한다() {
        // given
        let sut = OverlayWindowMatchGrouper()
        let preview = makePreview(id: 0, appName: "Slack", title: "Alpha", ordinal: 1, isFocused: true)

        // when
        let result = sut.grouped(from: [preview])

        // then
        XCTAssertEqual(result, [preview])
    }

    func test_grouped_focus된_창은_단독으로_유지하고_나머지는_요약row로_묶는다() {
        // given
        let sut = OverlayWindowMatchGrouper()
        let alpha = makePreview(id: 0, appName: "Slack", title: "Alpha", ordinal: 1, isFocused: true)
        let beta = makePreview(id: 1, appName: "Slack", title: "Beta", ordinal: 2, isFocused: false)
        let gamma = makePreview(id: 2, appName: "Slack", title: "Gamma", ordinal: 3, isFocused: false)

        // when
        let result = sut.grouped(from: [alpha, beta, gamma])

        // then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], alpha)
        XCTAssertEqual(result[1].displayName, "Slack — Beta 외 1개 창")
        XCTAssertEqual(result[1].additionalWindowCount, 1)
        XCTAssertFalse(result[1].isFocused)
    }

    func test_grouped_focus된_창이_없으면_첫번째_창을_대표로_요약한다() {
        // given
        let sut = OverlayWindowMatchGrouper()
        let alpha = makePreview(id: 0, appName: "Chrome", title: "Alpha", ordinal: 1, isFocused: false)
        let beta = makePreview(id: 1, appName: "Chrome", title: "Beta", ordinal: 2, isFocused: false)

        // when
        let result = sut.grouped(from: [alpha, beta])

        // then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].displayName, "Chrome — Alpha 외 1개 창")
        XCTAssertEqual(result[0].additionalWindowCount, 1)
    }

    func test_grouped_recencyRank가_낮은_창을_배열_순서와_무관하게_대표로_고른다() {
        // given
        let sut = OverlayWindowMatchGrouper()
        let alpha = makePreview(id: 0, appName: "Chrome", title: "Alpha", ordinal: 1, isFocused: false, recencyRank: 5)
        let beta = makePreview(id: 1, appName: "Chrome", title: "Beta", ordinal: 2, isFocused: false, recencyRank: 1)
        let gamma = makePreview(id: 2, appName: "Chrome", title: "Gamma", ordinal: 3, isFocused: false, recencyRank: 9)

        // when
        let result = sut.grouped(from: [alpha, beta, gamma])

        // then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].displayName, "Chrome — Beta 외 2개 창")
    }

    func test_grouped_요약row는_대표_창의_tabCount를_그대로_전달한다() {
        // given
        let sut = OverlayWindowMatchGrouper()
        let alpha = makePreview(id: 0, appName: "Chrome", title: "Alpha", ordinal: 1, isFocused: false, tabCount: 3)
        let beta = makePreview(id: 1, appName: "Chrome", title: "Beta", ordinal: 2, isFocused: false, tabCount: 7)

        // when
        let result = sut.grouped(from: [alpha, beta])

        // then: recencyRank가 동률이면 배열상 첫번째(alpha)가 대표가 되므로 alpha의 tabCount(3)를 그대로 들고 있어야 한다
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].tabCount, 3)
    }

    func test_grouped_서로_다른앱은_순서를_유지하며_그룹핑하지_않는다() {
        // given
        let sut = OverlayWindowMatchGrouper()
        let slack = makePreview(id: 0, appName: "Slack", title: "Alpha", ordinal: 1, isFocused: true)
        let chrome = makePreview(id: 1, appName: "Chrome", title: "Beta", ordinal: 2, isFocused: false)

        // when
        let result = sut.grouped(from: [slack, chrome])

        // then
        XCTAssertEqual(result, [slack, chrome])
    }

    private func makePreview(
        id: Int,
        appName: String,
        title: String,
        ordinal: Int,
        isFocused: Bool,
        recencyRank: Int = Int.max,
        tabCount: Int? = nil
    ) -> OverlayWindowMatchPreview {
        OverlayWindowMatchPreview(
            id: id,
            appName: appName,
            displayName: "\(appName) — \(title)",
            ordinal: ordinal,
            isFocused: isFocused,
            recencyRank: recencyRank,
            tabCount: tabCount
        )
    }
}
