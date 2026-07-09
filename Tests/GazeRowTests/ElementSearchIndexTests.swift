import CoreGraphics
import XCTest
@testable import GazeRow

/// ElementSearchIndex 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-09
final class ElementSearchIndexTests: XCTestCase {

    func test_search_title_prefix_match는_top1과_높은점수를_반환한다() {
        // given
        let sut = ElementSearchIndex(
            nodes: [
                node(id: 0, title: "Open Item", frame: CGRect(x: 10, y: 10, width: 20, height: 20)),
                node(id: 1, title: "Delete Item", frame: CGRect(x: 10, y: 40, width: 20, height: 20))
            ]
        )

        // when
        let matches = sut.search("delete")

        // then
        XCTAssertEqual(matches.first?.nodeID, 1)
        XCTAssertEqual(matches.first?.score, 120)
        XCTAssertEqual(matches.first?.matchedFields, [.title])
        XCTAssertEqual(matches.first?.displayName, "Delete Item")
    }

    func test_search_case와_diacritic을_무시한다() {
        // given
        let sut = ElementSearchIndex(
            nodes: [
                node(id: 0, title: "Café Settings", frame: CGRect(x: 10, y: 10, width: 20, height: 20))
            ]
        )

        // when
        let matches = sut.search("CAFE")

        // then
        XCTAssertEqual(matches.map(\.nodeID), [0])
    }

    func test_search_value_only_node도_검색된다() {
        // given
        let sut = ElementSearchIndex(
            nodes: [
                node(id: 0, value: "general", frame: CGRect(x: 10, y: 10, width: 20, height: 20))
            ]
        )

        // when
        let matches = sut.search("gene")

        // then
        XCTAssertEqual(matches.first?.nodeID, 0)
        XCTAssertEqual(matches.first?.score, 80)
        XCTAssertEqual(matches.first?.matchedFields, [.value])
        XCTAssertEqual(matches.first?.displayName, "general")
    }

    func test_init_secureField와_zeroFrame과_emptyText를_제외한다() {
        // given
        let sut = ElementSearchIndex(
            nodes: [
                node(
                    id: 0,
                    role: AccessibilityRole.secureTextField,
                    title: "Password",
                    frame: CGRect(x: 10, y: 10, width: 20, height: 20)
                ),
                node(id: 1, title: "General", frame: .zero),
                node(id: 2, title: "   ", frame: CGRect(x: 10, y: 40, width: 20, height: 20)),
                node(id: 3, title: "Search", frame: CGRect(x: 10, y: 70, width: 20, height: 20))
            ]
        )

        // when
        let matches = sut.search("s")

        // then
        XCTAssertEqual(sut.nodes.map(\.id), [3])
        XCTAssertEqual(matches.map(\.nodeID), [3])
    }

    func test_search_동점이면_위쪽_왼쪽_node를_우선한다() {
        // given
        let sut = ElementSearchIndex(
            nodes: [
                node(id: 0, title: "Reload", frame: CGRect(x: 80, y: 40, width: 20, height: 20)),
                node(id: 1, title: "Reload", frame: CGRect(x: 10, y: 40, width: 20, height: 20)),
                node(id: 2, title: "Reload", frame: CGRect(x: 10, y: 10, width: 20, height: 20))
            ]
        )

        // when
        let matches = sut.search("reload")

        // then
        XCTAssertEqual(matches.map(\.nodeID), [2, 1, 0])
    }

    func test_search_emptyQuery는_빈배열을_반환한다() {
        // given
        let sut = ElementSearchIndex(
            nodes: [
                node(id: 0, title: "Reload", frame: CGRect(x: 10, y: 10, width: 20, height: 20))
            ]
        )

        // when & then
        XCTAssertTrue(sut.search("").isEmpty)
        XCTAssertTrue(sut.search("   ").isEmpty)
    }

    func test_init_value는_80자로_제한한다() throws {
        // given
        let longValue = String(repeating: "a", count: 120)

        // when
        let sut = ElementSearchIndex(
            nodes: [
                node(id: 0, value: longValue, frame: CGRect(x: 10, y: 10, width: 20, height: 20))
            ]
        )

        // then
        let indexedNode = try XCTUnwrap(sut.node(id: 0))
        XCTAssertEqual(indexedNode.value?.count, 80)
        XCTAssertEqual(sut.search(String(repeating: "a", count: 81)).count, 0)
    }

    func test_init_maxNodes를_넘으면_truncated가_true이고_prefix만_인덱싱한다() {
        // given
        let nodes = (0..<5).map {
            node(
                id: $0,
                title: "Item \($0)",
                frame: CGRect(x: 10, y: CGFloat($0 * 20), width: 20, height: 20)
            )
        }

        // when
        let sut = ElementSearchIndex(nodes: nodes, maxNodes: 3)

        // then
        XCTAssertTrue(sut.buildMetrics.truncated)
        XCTAssertEqual(sut.buildMetrics.nodesVisited, 3)
        XCTAssertEqual(sut.nodes.map(\.id), [0, 1, 2])
    }

    func test_search_1000개_node를_빠르게_검색한다() {
        // given
        let nodes = (0..<1_000).map {
            node(
                id: $0,
                title: $0 == 999 ? "Delete Item" : "Item \($0)",
                frame: CGRect(x: CGFloat($0 % 10), y: CGFloat($0), width: 20, height: 20)
            )
        }
        let sut = ElementSearchIndex(nodes: nodes)
        let startedAt = Date()

        // when
        let matches = sut.search("delete")

        // then
        XCTAssertEqual(matches.first?.nodeID, 999)
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 0.05)
    }

    private func node(
        id: Int,
        role: String? = AccessibilityRole.button,
        title: String? = nil,
        value: String? = nil,
        description: String? = nil,
        help: String? = nil,
        frame: CGRect,
        axPath: [Int] = []
    ) -> SearchableNode {
        SearchableNode(
            id: id,
            role: role,
            title: title,
            value: value,
            description: description,
            help: help,
            frame: frame,
            axPath: axPath
        )
    }
}
