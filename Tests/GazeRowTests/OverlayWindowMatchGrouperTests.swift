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
        isFocused: Bool
    ) -> OverlayWindowMatchPreview {
        OverlayWindowMatchPreview(
            id: id,
            appName: appName,
            displayName: "\(appName) — \(title)",
            ordinal: ordinal,
            isFocused: isFocused
        )
    }
}
