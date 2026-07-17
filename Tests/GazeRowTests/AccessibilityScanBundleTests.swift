import CoreGraphics
import Foundation
import XCTest
@testable import GazeRow

/// 단일 AX walk bundle collector를 검증한다.
///
/// @author suho.do
/// @since 2026-07-17
final class AccessibilityScanBundleTests: XCTestCase {

    func test_collect는_node마다한번inspect해_candidate와검색tree를함께만든다() async throws {
        // given
        let button = FakeBundleElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "Open",
                actions: [AccessibilityAction.press]
            )
        )
        let row = FakeBundleElement(
            snapshot: snapshot(role: "AXGroup", title: "Downloads"),
            children: [button]
        )
        let root = FakeBundleElement(children: [row])
        let counter = BundleClientCounter()
        let sut = AccessibilityScanBundleCollector(
            client: FakeBundleClient(root: .success(root), counter: counter)
        )

        // when
        let result = await sut.collectProgressively(context: targetContext) { _ in }
        let bundle = try XCTUnwrap(result.successValue)

        // then
        XCTAssertEqual(bundle.scanResult.candidates.map(\.title), ["Open"])
        XCTAssertEqual(bundle.elementIndex.search("downloads").map(\.nodeID), [1])
        let rowNode = try XCTUnwrap(bundle.elementIndex.node(id: 1))
        let buttonNode = try XCTUnwrap(bundle.elementIndex.node(id: 2))
        XCTAssertEqual(rowNode.childrenIDs, [2])
        XCTAssertEqual(buttonNode.parentID, 1)
        XCTAssertEqual(buttonNode.axPath, [0, 0])
        XCTAssertEqual(bundle.targetDescriptors, [AccessibilityTargetDescriptor(axPath: [0, 0])])
        XCTAssertEqual(counter.snapshot(), BundleClientCounts(root: 1, inspect: 3, snapshot: 0, children: 0))
        XCTAssertEqual(bundle.metrics.inspectionCount, 3)
        XCTAssertEqual(bundle.metrics.childReadCount, 3)
    }

    func test_collect는_additionalRoot를_label과검색index에모두포함한다() async throws {
        // given
        let additional = FakeBundleElement(
            snapshot: snapshot(
                role: AccessibilityRole.textArea,
                title: "Focused editor"
            )
        )
        let sut = AccessibilityScanBundleCollector(
            client: FakeBundleClient(
                root: .success(FakeBundleElement()),
                additionalRoots: [additional]
            )
        )

        // when
        let result = await sut.collectProgressively(context: targetContext) { _ in }
        let bundle = try XCTUnwrap(result.successValue)

        // then
        XCTAssertEqual(bundle.scanResult.candidates.map(\.title), ["Focused editor"])
        XCTAssertEqual(bundle.elementIndex.search("focused").map(\.displayName), ["Focused editor"])
        XCTAssertEqual(bundle.targetDescriptors, [AccessibilityTargetDescriptor(axPath: [-1])])
    }

    func test_fallback은_candidate수만큼_nilDescriptor를만든다() {
        // given
        let scanResult = AccessibilityScanResult(
            candidates: [
                ClickableCandidate(
                    role: AccessibilityRole.button,
                    subrole: nil,
                    title: "Open",
                    frame: CGRect(x: 10, y: 10, width: 80, height: 30),
                    actions: [AccessibilityAction.press]
                ),
                ClickableCandidate(
                    role: AccessibilityRole.link,
                    subrole: nil,
                    title: "Details",
                    frame: CGRect(x: 100, y: 10, width: 80, height: 30),
                    actions: [AccessibilityAction.press]
                )
            ],
            nodesVisited: 2,
            scanDuration: 0,
            didHitDepthLimit: false,
            didHitNodeLimit: false,
            didTimeout: false,
            failedChildReadCount: 0
        )

        // when
        let bundle = AccessibilityScanBundle.fallback(scanResult: scanResult)

        // then
        XCTAssertEqual(bundle.targetDescriptors, [nil, nil])
    }

    func test_init_descriptor수가_candidate수와다르면_안전한_nil배열로대체한다() {
        // given
        let scanResult = AccessibilityScanResult(
            candidates: [
                ClickableCandidate(
                    role: AccessibilityRole.button,
                    subrole: nil,
                    title: "Open",
                    frame: CGRect(x: 10, y: 10, width: 80, height: 30),
                    actions: [AccessibilityAction.press]
                )
            ],
            nodesVisited: 1,
            scanDuration: 0,
            didHitDepthLimit: false,
            didHitNodeLimit: false,
            didTimeout: false,
            failedChildReadCount: 0
        )

        // when
        let bundle = AccessibilityScanBundle(
            scanResult: scanResult,
            elementIndex: ElementSearchIndex(nodes: []),
            metrics: AccessibilityScanBundleMetrics(inspectionCount: 1, childReadCount: 1),
            targetDescriptors: []
        )

        // then
        XCTAssertEqual(bundle.targetDescriptors, [nil])
    }

    func test_collect는_secureField를_candidate와검색index에서모두제외한다() async throws {
        // given
        let secure = FakeBundleElement(
            snapshot: snapshot(
                role: AccessibilityRole.secureTextField,
                title: "Password",
                actions: [AccessibilityAction.press]
            )
        )
        let sut = AccessibilityScanBundleCollector(
            client: FakeBundleClient(root: .success(FakeBundleElement(children: [secure])))
        )

        // when
        let result = await sut.collectProgressively(context: targetContext) { _ in }
        let bundle = try XCTUnwrap(result.successValue)

        // then
        XCTAssertTrue(bundle.scanResult.candidates.isEmpty)
        XCTAssertTrue(bundle.elementIndex.search("password").isEmpty)
    }

    func test_collect는_childRead실패를기록하고가능한결과를유지한다() async throws {
        // given
        let button = FakeBundleElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "Open",
                actions: [AccessibilityAction.press]
            ),
            childrenFailure: .childrenUnavailable("temporary")
        )
        let sut = AccessibilityScanBundleCollector(
            client: FakeBundleClient(root: .success(FakeBundleElement(children: [button])))
        )

        // when
        let result = await sut.collectProgressively(context: targetContext) { _ in }
        let bundle = try XCTUnwrap(result.successValue)

        // then
        XCTAssertEqual(bundle.scanResult.candidates.map(\.title), ["Open"])
        XCTAssertEqual(bundle.elementIndex.search("open").count, 1)
        XCTAssertEqual(bundle.scanResult.failedChildReadCount, 1)
    }

    func test_collect는_600개fixture에서도_node당inspection을한번만호출한다() async throws {
        // given
        let children = (0..<600).map { index in
            FakeBundleElement(snapshot: snapshot(role: "AXGroup", title: "Node \(index)"))
        }
        let counter = BundleClientCounter()
        let sut = AccessibilityScanBundleCollector(
            client: FakeBundleClient(
                root: .success(FakeBundleElement(children: children)),
                counter: counter
            ),
            configuration: AccessibilityScanConfiguration(maxNodes: 700, timeout: 10)
        )

        // when
        let result = await sut.collectProgressively(context: targetContext) { _ in }
        let bundle = try XCTUnwrap(result.successValue)

        // then
        XCTAssertEqual(bundle.scanResult.nodesVisited, 601)
        XCTAssertEqual(bundle.elementIndex.buildMetrics.nodesVisited, 601)
        XCTAssertEqual(counter.snapshot(), BundleClientCounts(root: 1, inspect: 601, snapshot: 0, children: 0))
    }

    func test_collect는_nodeLimit을_scan과검색index에동일하게반영한다() async throws {
        // given
        let children = (0..<10).map { index in
            FakeBundleElement(snapshot: snapshot(role: "AXGroup", title: "Node \(index)"))
        }
        let sut = AccessibilityScanBundleCollector(
            client: FakeBundleClient(root: .success(FakeBundleElement(children: children))),
            configuration: AccessibilityScanConfiguration(maxNodes: 5, timeout: 10)
        )

        // when
        let result = await sut.collectProgressively(context: targetContext) { _ in }
        let bundle = try XCTUnwrap(result.successValue)

        // then
        XCTAssertEqual(bundle.scanResult.nodesVisited, 5)
        XCTAssertTrue(bundle.scanResult.didHitNodeLimit)
        XCTAssertEqual(bundle.elementIndex.buildMetrics.nodesVisited, 5)
        XCTAssertTrue(bundle.elementIndex.buildMetrics.truncated)
    }

    private var targetContext: TargetContext {
        TargetContext(
            application: TargetApplication(
                localizedName: "Finder",
                bundleIdentifier: "com.apple.finder",
                processIdentifier: 100
            ),
            window: TargetWindow(
                frame: CGRect(x: 0, y: 0, width: 800, height: 600),
                title: "Finder"
            ),
            resolvedAt: Date(timeIntervalSince1970: 1_788_748_400)
        )
    }

    private func snapshot(
        role: String = "AXGroup",
        title: String? = nil,
        actions: [String] = []
    ) -> AccessibilityElementSnapshot {
        AccessibilityElementSnapshot(
            role: role,
            subrole: nil,
            title: title,
            value: nil,
            help: nil,
            frame: CGRect(x: 10, y: 10, width: 200, height: 40),
            actions: actions
        )
    }
}

private struct FakeBundleElement: Sendable {
    let snapshot: AccessibilityElementSnapshot
    let children: [FakeBundleElement]
    let childrenFailure: AccessibilityScanFailure?

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
        children: [FakeBundleElement] = [],
        childrenFailure: AccessibilityScanFailure? = nil
    ) {
        self.snapshot = snapshot
        self.children = children
        self.childrenFailure = childrenFailure
    }
}

private struct FakeBundleClient: AccessibilityElementClient, Sendable {
    let root: Result<FakeBundleElement, AccessibilityScanFailure>
    var additionalRoots: [FakeBundleElement] = []
    var counter: BundleClientCounter = BundleClientCounter()

    func rootElement(
        for context: TargetContext
    ) -> Result<FakeBundleElement, AccessibilityScanFailure> {
        counter.incrementRoot()
        return root
    }

    func additionalRootElements(for context: TargetContext) -> [FakeBundleElement] {
        additionalRoots
    }

    func inspect(
        _ element: FakeBundleElement
    ) -> AccessibilityElementInspection<FakeBundleElement> {
        counter.incrementInspect()
        let children: Result<[FakeBundleElement], AccessibilityScanFailure>
        if let failure = element.childrenFailure {
            children = .failure(failure)
        } else {
            children = .success(element.children)
        }
        return AccessibilityElementInspection(snapshot: element.snapshot, children: children)
    }

    func snapshot(of element: FakeBundleElement) -> AccessibilityElementSnapshot {
        counter.incrementSnapshot()
        return element.snapshot
    }

    func children(
        of element: FakeBundleElement
    ) -> Result<[FakeBundleElement], AccessibilityScanFailure> {
        counter.incrementChildren()
        return .success(element.children)
    }
}

private struct BundleClientCounts: Equatable {
    var root = 0
    var inspect = 0
    var snapshot = 0
    var children = 0
}

private final class BundleClientCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var counts = BundleClientCounts()

    func incrementRoot() {
        withLock { counts.root += 1 }
    }

    func incrementInspect() {
        withLock { counts.inspect += 1 }
    }

    func incrementSnapshot() {
        withLock { counts.snapshot += 1 }
    }

    func incrementChildren() {
        withLock { counts.children += 1 }
    }

    func snapshot() -> BundleClientCounts {
        withLock { counts }
    }

    private func withLock<T>(_ operation: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return operation()
    }
}

private extension Result {
    var successValue: Success? {
        guard case .success(let value) = self else {
            return nil
        }
        return value
    }
}
