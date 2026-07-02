import CoreGraphics
import Foundation
import XCTest
@testable import GazeRow

/// AccessibilityScanner 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class AccessibilityScannerTests: XCTestCase {

    func test_scan_AXPress가_있는_요소를_candidate로_수집() {
        // given
        let button = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "Open",
                frame: CGRect(x: 10, y: 20, width: 80, height: 24),
                actions: [AccessibilityAction.press]
            )
        )
        let root = FakeElement(children: [button])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidateCount, 1)
        XCTAssertEqual(scanResult.candidates.first?.title, "Open")
        XCTAssertEqual(scanResult.nodesVisited, 2)
    }

    func test_scan_clickableRole은_action이_없어도_candidate로_수집() {
        // given
        let textField = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.textField,
                title: "Search",
                frame: CGRect(x: 10, y: 20, width: 160, height: 24)
            )
        )
        let root = FakeElement(children: [textField])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidateCount, 1)
        XCTAssertEqual(scanResult.candidates.first?.role, AccessibilityRole.textField)
    }

    func test_scan_selectableContainerRole은_action이_없어도_candidate로_수집() {
        // given
        let row = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.row,
                title: "Finder Sidebar Item",
                frame: CGRect(x: 10, y: 20, width: 180, height: 24)
            )
        )
        let cell = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.cell,
                title: "Finder Sidebar Cell",
                frame: CGRect(x: 10, y: 52, width: 180, height: 24)
            )
        )
        let image = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.image,
                title: "VS Code Activity Bar Item",
                frame: CGRect(x: 10, y: 84, width: 32, height: 32)
            )
        )
        let root = FakeElement(children: [row, cell, image])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(
            scanResult.candidates.map(\.role),
            [
                AccessibilityRole.row,
                AccessibilityRole.cell,
                AccessibilityRole.image
            ]
        )
    }

    func test_scan_defaultDepth는_VSCode_activityBar처럼_깊은_candidate를_수집() {
        // given
        let activityBarItem = FakeElement(
            snapshot: AccessibilityElementSnapshot(
                role: AccessibilityRole.radioButton,
                subrole: "AXTabButton",
                title: nil,
                value: nil,
                help: nil,
                frame: CGRect(x: 0, y: 99, width: 48, height: 48),
                actions: [AccessibilityAction.press, "AXShowMenu", "AXScrollToVisible"]
            )
        )
        let root = nestedElement(depth: 17, leaf: activityBarItem)
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidates.first?.role, AccessibilityRole.radioButton)
        XCTAssertEqual(scanResult.candidates.first?.subrole, "AXTabButton")
    }

    func test_scan_secureField는_AXPress가_있어도_제외() {
        // given
        let secureField = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.secureTextField,
                title: "Password",
                frame: CGRect(x: 10, y: 20, width: 160, height: 24),
                actions: [AccessibilityAction.press]
            )
        )
        let root = FakeElement(children: [secureField])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertTrue(scanResult.candidates.isEmpty)
    }

    func test_scan_frame이_없는_요소는_제외() {
        // given
        let button = FakeElement(
            snapshot: AccessibilityElementSnapshot(
                role: AccessibilityRole.button,
                subrole: nil,
                title: "Open",
                value: nil,
                help: nil,
                frame: nil,
                actions: [AccessibilityAction.press]
            )
        )
        let root = FakeElement(children: [button])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertTrue(scanResult.candidates.isEmpty)
    }

    func test_scan_중복_candidate는_하나만_남김() {
        // given
        let duplicateFrame = CGRect(x: 10, y: 20, width: 80, height: 24)
        let first = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "First",
                frame: duplicateFrame,
                actions: [AccessibilityAction.press]
            )
        )
        let second = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "Second",
                frame: duplicateFrame,
                actions: [AccessibilityAction.press]
            )
        )
        let root = FakeElement(children: [first, second])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidateCount, 1)
        XCTAssertEqual(scanResult.candidates.first?.title, "First")
    }

    func test_scan_maxDepth_초과_하위요소는_순회하지_않음() {
        // given
        let deepButton = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "Deep",
                frame: CGRect(x: 10, y: 20, width: 80, height: 24),
                actions: [AccessibilityAction.press]
            )
        )
        let child = FakeElement(children: [deepButton])
        let root = FakeElement(children: [child])
        let sut = AccessibilityScanner(
            client: FakeAccessibilityElementClient(root: .success(root)),
            configuration: AccessibilityScanConfiguration(maxDepth: 1)
        )

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertTrue(scanResult.candidates.isEmpty)
        XCTAssertTrue(scanResult.didHitDepthLimit)
    }

    func test_scan_maxNodes에_도달하면_중단() {
        // given
        let first = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "First",
                frame: CGRect(x: 10, y: 20, width: 80, height: 24),
                actions: [AccessibilityAction.press]
            )
        )
        let second = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "Second",
                frame: CGRect(x: 100, y: 20, width: 80, height: 24),
                actions: [AccessibilityAction.press]
            )
        )
        let root = FakeElement(children: [first, second])
        let sut = AccessibilityScanner(
            client: FakeAccessibilityElementClient(root: .success(root)),
            configuration: AccessibilityScanConfiguration(maxNodes: 2)
        )

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.nodesVisited, 2)
        XCTAssertEqual(scanResult.candidateCount, 1)
        XCTAssertTrue(scanResult.didHitNodeLimit)
    }

    func test_scan_rootElement_실패를_반환() {
        // given
        let sut = AccessibilityScanner(
            client: FakeAccessibilityElementClient(root: .failure(.accessibilityPermissionDenied))
        )

        // when
        let result = sut.scan(context: targetContext)

        // then
        XCTAssertEqual(result, .failure(.accessibilityPermissionDenied))
    }

    func test_scan_children_조회_실패는_카운트하고_계속진행() {
        // given
        let button = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "Open",
                frame: CGRect(x: 10, y: 20, width: 80, height: 24),
                actions: [AccessibilityAction.press]
            ),
            childrenFailure: .childrenUnavailable("cannot complete")
        )
        let root = FakeElement(children: [button])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidateCount, 1)
        XCTAssertEqual(scanResult.failedChildReadCount, 1)
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
        role: String?,
        title: String? = nil,
        frame: CGRect,
        actions: [String] = []
    ) -> AccessibilityElementSnapshot {
        AccessibilityElementSnapshot(
            role: role,
            subrole: nil,
            title: title,
            value: nil,
            help: nil,
            frame: frame,
            actions: actions
        )
    }

    private func nestedElement(depth: Int, leaf: FakeElement) -> FakeElement {
        guard depth > 0 else {
            return leaf
        }

        return FakeElement(children: [nestedElement(depth: depth - 1, leaf: leaf)])
    }
}

private struct FakeElement {
    let snapshot: AccessibilityElementSnapshot
    let children: [FakeElement]
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
        children: [FakeElement] = [],
        childrenFailure: AccessibilityScanFailure? = nil
    ) {
        self.snapshot = snapshot
        self.children = children
        self.childrenFailure = childrenFailure
    }
}

@MainActor
private struct FakeAccessibilityElementClient: AccessibilityElementClient {
    let root: Result<FakeElement, AccessibilityScanFailure>

    func rootElement(for context: TargetContext) -> Result<FakeElement, AccessibilityScanFailure> {
        root
    }

    func snapshot(of element: FakeElement) -> AccessibilityElementSnapshot {
        element.snapshot
    }

    func children(of element: FakeElement) -> Result<[FakeElement], AccessibilityScanFailure> {
        if let childrenFailure = element.childrenFailure {
            return .failure(childrenFailure)
        }

        return .success(element.children)
    }
}
