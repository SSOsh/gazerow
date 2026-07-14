import CoreGraphics
import Foundation
import XCTest
@testable import GazeRow

/// SearchableNodeCollector 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-09
@MainActor
final class SearchableNodeCollectorTests: XCTestCase {

    func test_buildIndex는_title_value_help가_있는_node를_수집하고_tree관계를_보존한다() throws {
        // given
        let button = FakeSearchElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "Join",
                frame: CGRect(x: 20, y: 20, width: 40, height: 20)
            )
        )
        let row = FakeSearchElement(
            snapshot: snapshot(
                role: AccessibilityRole.row,
                title: "General",
                frame: CGRect(x: 10, y: 10, width: 200, height: 40)
            ),
            children: [button]
        )
        let root = FakeSearchElement(children: [row])
        let sut = AccessibilitySearchableNodeCollector(
            client: FakeSearchAccessibilityElementClient(root: .success(root))
        )

        // when
        let index = sut.buildIndex(context: targetContext)

        // then
        XCTAssertEqual(index.search("general").map(\.nodeID), [1])
        let rowNode = try XCTUnwrap(index.node(id: 1))
        let buttonNode = try XCTUnwrap(index.node(id: 2))
        XCTAssertEqual(rowNode.childrenIDs, [2])
        XCTAssertEqual(buttonNode.parentID, 1)
        XCTAssertEqual(buttonNode.axPath, [0, 0])
    }

    func test_buildIndex는_secureField와_zeroFrame을_index에서_제외한다() {
        // given
        let secure = FakeSearchElement(
            snapshot: snapshot(
                role: AccessibilityRole.secureTextField,
                title: "Password",
                frame: CGRect(x: 10, y: 10, width: 100, height: 20)
            )
        )
        let zero = FakeSearchElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "Zero",
                frame: .zero
            )
        )
        let root = FakeSearchElement(children: [secure, zero])
        let sut = AccessibilitySearchableNodeCollector(
            client: FakeSearchAccessibilityElementClient(root: .success(root))
        )

        // when
        let index = sut.buildIndex(context: targetContext)

        // then
        XCTAssertTrue(index.nodes.isEmpty)
    }

    func test_buildIndex는_maxNodes에_도달하면_truncated를_표시한다() {
        // given
        let root = FakeSearchElement(
            children: [
                FakeSearchElement(snapshot: snapshot(title: "One")),
                FakeSearchElement(snapshot: snapshot(title: "Two"))
            ]
        )
        let sut = AccessibilitySearchableNodeCollector(
            client: FakeSearchAccessibilityElementClient(root: .success(root)),
            configuration: AccessibilityScanConfiguration(maxNodes: 2)
        )

        // when
        let index = sut.buildIndex(context: targetContext)

        // then
        XCTAssertTrue(index.buildMetrics.truncated)
        XCTAssertEqual(index.buildMetrics.nodesVisited, 2)
    }

    func test_buildIndex는_defaultDepth에서_webArea_깊은_textArea도_인덱싱한다() {
        // given
        let chatInput = FakeSearchElement(
            snapshot: snapshot(
                role: AccessibilityRole.textArea,
                value: "후속 변경 사항을 부탁하세요",
                frame: CGRect(x: 750, y: 1143, width: 713, height: 44)
            )
        )
        let root = nestedElement(depth: 28, leaf: chatInput)
        let sut = AccessibilitySearchableNodeCollector(
            client: FakeSearchAccessibilityElementClient(root: .success(root))
        )

        // when
        let index = sut.buildIndex(context: targetContext)

        // then
        let matches = index.search("후속")
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.map(\.displayName), [AccessibilityRole.textArea])
        XCTAssertFalse(index.buildMetrics.truncated)
    }

    private var targetContext: TargetContext {
        TargetContext(
            application: TargetApplication(
                localizedName: "Finder",
                bundleIdentifier: "com.apple.finder",
                processIdentifier: 100
            ),
            window: TargetWindow(
                frame: CGRect(x: 0, y: 0, width: 500, height: 320),
                title: "Finder"
            ),
            resolvedAt: Date(timeIntervalSince1970: 1_788_748_400)
        )
    }

    private func snapshot(
        role: String = "AXGroup",
        title: String? = nil,
        value: String? = nil,
        help: String? = nil,
        frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600)
    ) -> AccessibilityElementSnapshot {
        AccessibilityElementSnapshot(
            role: role,
            subrole: nil,
            title: title,
            value: value,
            help: help,
            frame: frame,
            actions: []
        )
    }

    private func nestedElement(depth: Int, leaf: FakeSearchElement) -> FakeSearchElement {
        guard depth > 0 else {
            return leaf
        }

        return FakeSearchElement(children: [nestedElement(depth: depth - 1, leaf: leaf)])
    }
}

private struct FakeSearchElement {
    let snapshot: AccessibilityElementSnapshot
    let children: [FakeSearchElement]

    init(
        snapshot: AccessibilityElementSnapshot = AccessibilityElementSnapshot(
            role: "AXGroup",
            subrole: nil,
            title: nil,
            value: nil,
            help: nil,
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            actions: []
        ),
        children: [FakeSearchElement] = []
    ) {
        self.snapshot = snapshot
        self.children = children
    }
}

@MainActor
private struct FakeSearchAccessibilityElementClient: AccessibilityElementClient {
    let root: Result<FakeSearchElement, AccessibilityScanFailure>

    func rootElement(for context: TargetContext) -> Result<FakeSearchElement, AccessibilityScanFailure> {
        root
    }

    func snapshot(of element: FakeSearchElement) -> AccessibilityElementSnapshot {
        element.snapshot
    }

    func children(of element: FakeSearchElement) -> Result<[FakeSearchElement], AccessibilityScanFailure> {
        .success(element.children)
    }
}
