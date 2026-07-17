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

    func test_scanProgressively는_첫후보와_주기적진행상황을_전달한다() async {
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
        var progressUpdates: [AccessibilityScanProgress] = []

        // when
        let result = await sut.scanProgressively(context: targetContext) { progress in
            progressUpdates.append(progress)
        }

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidateCount, 1)
        XCTAssertEqual(progressUpdates.first?.candidates, [scanResult.candidates[0]])
        XCTAssertEqual(progressUpdates.first?.nodesVisited, 2)
    }

    func test_scanProgressively는_yield후_취소되면_cancelled를반환한다() async {
        // given
        let leaf = FakeElement()
        let root = nestedElement(depth: 128, leaf: leaf)
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let task = Task { @MainActor in
            await sut.scanProgressively(context: targetContext) { _ in }
        }
        await Task.yield()
        task.cancel()
        let result = await task.value

        // then
        XCTAssertEqual(result, .failure(.cancelled))
    }

    func test_scan_AXTextArea는_action이_없어도_candidate로_수집() {
        // given
        let textArea = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.textArea,
                title: "Message",
                frame: CGRect(x: 10, y: 20, width: 200, height: 80)
            )
        )
        let root = FakeElement(children: [textArea])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidateCount, 1)
        XCTAssertEqual(scanResult.candidates.first?.role, AccessibilityRole.textArea)
    }

    func test_scan_AXSearchField는_action이_없어도_candidate로_수집() {
        // given
        let searchField = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.searchField,
                title: "Search",
                frame: CGRect(x: 10, y: 20, width: 160, height: 24)
            )
        )
        let root = FakeElement(children: [searchField])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidateCount, 1)
        XCTAssertEqual(scanResult.candidates.first?.role, AccessibilityRole.searchField)
    }

    func test_scan_additionalRootElement의_textArea도_candidate로_수집() {
        // given
        let root = FakeElement()
        let focusedTextArea = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.textArea,
                title: "Focused input",
                frame: CGRect(x: 120, y: 520, width: 320, height: 44)
            )
        )
        let sut = AccessibilityScanner(
            client: FakeAccessibilityElementClient(
                root: .success(root),
                additionalRootElements: [focusedTextArea]
            )
        )

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidates.map(\.role), [AccessibilityRole.textArea])
    }

    func test_scan_AXSetValue_action이_있는_customInput도_candidate로_수집() {
        // given
        let customInput = FakeElement(
            snapshot: snapshot(
                role: "AXGroup",
                title: "Message editor",
                frame: CGRect(x: 10, y: 20, width: 300, height: 44),
                actions: [AccessibilityAction.setValue]
            )
        )
        let root = FakeElement(children: [customInput])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidateCount, 1)
        XCTAssertEqual(scanResult.candidates.first?.role, "AXGroup")
        XCTAssertEqual(scanResult.candidates.first?.actions, [AccessibilityAction.setValue])
    }

    func test_scan_textInput_subrole이_있는_customInput도_candidate로_수집() {
        // given
        let customInput = FakeElement(
            snapshot: snapshot(
                role: "AXGroup",
                subrole: "AXTextInput",
                title: "Chat input",
                frame: CGRect(x: 10, y: 20, width: 300, height: 44)
            )
        )
        let root = FakeElement(children: [customInput])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidateCount, 1)
        XCTAssertEqual(scanResult.candidates.first?.subrole, "AXTextInput")
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

    func test_scan_의미텍스트없는_image는_action이_없으면_제외() {
        // given
        let decorativeImage = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.image,
                title: nil,
                frame: CGRect(x: 10, y: 20, width: 128, height: 128)
            )
        )
        let namedImage = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.image,
                title: "Workspace",
                frame: CGRect(x: 160, y: 20, width: 32, height: 32)
            )
        )
        let actionableImage = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.image,
                title: nil,
                frame: CGRect(x: 210, y: 20, width: 32, height: 32),
                actions: [AccessibilityAction.press]
            )
        )
        let root = FakeElement(children: [decorativeImage, namedImage, actionableImage])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidates.map(\.frame), [namedImage.snapshot.frame, actionableImage.snapshot.frame])
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

    func test_scan_defaultDepth는_webArea_깊은_textArea도_candidate로_수집() {
        // given
        let chatInput = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.textArea,
                title: nil,
                frame: CGRect(x: 750, y: 1143, width: 713, height: 44)
            )
        )
        let root = nestedElement(depth: 28, leaf: chatInput)
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(
            context: targetContext(
                windowFrame: CGRect(x: 0, y: 0, width: 1_600, height: 1_300)
            )
        )

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidates.map(\.role), [AccessibilityRole.textArea])
        XCTAssertFalse(scanResult.didHitDepthLimit)
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

    func test_scan_대상창밖_candidate는_제외한다() {
        // given
        let outsideButton = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "Outside",
                frame: CGRect(x: 900, y: 700, width: 80, height: 24),
                actions: [AccessibilityAction.press]
            )
        )
        let root = FakeElement(children: [outsideButton])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertTrue(scanResult.candidates.isEmpty)
        XCTAssertEqual(scanResult.nodesVisited, 2)
    }

    func test_scan_대상창경계와_일부교차하는_candidate는_수집한다() {
        // given
        let partiallyVisibleButton = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "Partially visible",
                frame: CGRect(x: 780, y: 580, width: 80, height: 40),
                actions: [AccessibilityAction.press]
            )
        )
        let root = FakeElement(children: [partiallyVisibleButton])
        let sut = AccessibilityScanner(client: FakeAccessibilityElementClient(root: .success(root)))

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidates.map(\.title), ["Partially visible"])
    }

    func test_scan_크기가_0인_candidate는_창안에있어도_제외한다() {
        // given
        let emptyButton = FakeElement(
            snapshot: snapshot(
                role: AccessibilityRole.button,
                title: "Empty",
                frame: CGRect(x: 100, y: 100, width: 0, height: 24),
                actions: [AccessibilityAction.press]
            )
        )
        let root = FakeElement(children: [emptyButton])
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

    func test_scan_각node는_inspection으로_snapshot과_children을_한번에_읽음() {
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
        let client = CountingAccessibilityElementClient(root: .success(root))
        let sut = AccessibilityScanner(client: client)

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidateCount, 1)
        XCTAssertEqual(client.inspectionCount, 2)
        XCTAssertEqual(client.snapshotCount, 0)
        XCTAssertEqual(client.childrenCount, 0)
        XCTAssertEqual(client.roleCount, 0)
        XCTAssertEqual(client.actionsCount, 0)
        XCTAssertEqual(client.titleCount, 0)
        XCTAssertEqual(client.frameCount, 0)
        XCTAssertEqual(client.subroleCount, 0)
        XCTAssertEqual(client.valueCount, 0)
        XCTAssertEqual(client.helpCount, 0)
    }

    func test_scan_image의_의미텍스트는_snapshot값으로_판정() {
        // given
        let decorativeImage = FakeElement(
            snapshot: AccessibilityElementSnapshot(
                role: AccessibilityRole.image,
                subrole: nil,
                title: nil,
                value: nil,
                help: nil,
                frame: CGRect(x: 10, y: 20, width: 32, height: 32),
                actions: []
            )
        )
        let namedImage = FakeElement(
            snapshot: AccessibilityElementSnapshot(
                role: AccessibilityRole.image,
                subrole: nil,
                title: "Explorer",
                value: nil,
                help: nil,
                frame: CGRect(x: 50, y: 20, width: 32, height: 32),
                actions: []
            )
        )
        let root = FakeElement(children: [decorativeImage, namedImage])
        let client = CountingAccessibilityElementClient(root: .success(root))
        let sut = AccessibilityScanner(client: client)

        // when
        let result = sut.scan(context: targetContext)

        // then
        guard case .success(let scanResult) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(scanResult.candidates.map(\.title), ["Explorer"])
        XCTAssertEqual(client.inspectionCount, 3)
        XCTAssertEqual(client.snapshotCount, 0)
        XCTAssertEqual(client.childrenCount, 0)
        XCTAssertEqual(client.titleCount, 0)
        XCTAssertEqual(client.valueCount, 0)
        XCTAssertEqual(client.helpCount, 0)
        XCTAssertEqual(client.frameCount, 0)
    }

    private var targetContext: TargetContext {
        targetContext(windowFrame: CGRect(x: 0, y: 0, width: 800, height: 600))
    }

    private func targetContext(windowFrame: CGRect) -> TargetContext {
        TargetContext(
            application: TargetApplication(
                localizedName: "Finder",
                bundleIdentifier: "com.apple.finder",
                processIdentifier: 100
            ),
            window: TargetWindow(
                frame: windowFrame,
                title: "Finder"
            ),
            resolvedAt: Date(timeIntervalSince1970: 1_788_748_400)
        )
    }

    private func snapshot(
        role: String?,
        subrole: String? = nil,
        title: String? = nil,
        frame: CGRect,
        actions: [String] = []
    ) -> AccessibilityElementSnapshot {
        AccessibilityElementSnapshot(
            role: role,
            subrole: subrole,
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
    var additionalRootElements: [FakeElement] = []

    func rootElement(for context: TargetContext) -> Result<FakeElement, AccessibilityScanFailure> {
        root
    }

    func additionalRootElements(for context: TargetContext) -> [FakeElement] {
        additionalRootElements
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

@MainActor
private final class CountingAccessibilityElementClient: AccessibilityElementClient {
    let root: Result<FakeElement, AccessibilityScanFailure>
    private(set) var inspectionCount = 0
    private(set) var snapshotCount = 0
    private(set) var childrenCount = 0
    private(set) var roleCount = 0
    private(set) var subroleCount = 0
    private(set) var titleCount = 0
    private(set) var valueCount = 0
    private(set) var helpCount = 0
    private(set) var frameCount = 0
    private(set) var actionsCount = 0

    init(root: Result<FakeElement, AccessibilityScanFailure>) {
        self.root = root
    }

    func rootElement(for context: TargetContext) -> Result<FakeElement, AccessibilityScanFailure> {
        root
    }

    func inspect(_ element: FakeElement) -> AccessibilityElementInspection<FakeElement> {
        inspectionCount += 1
        let children: Result<[FakeElement], AccessibilityScanFailure>
        if let childrenFailure = element.childrenFailure {
            children = .failure(childrenFailure)
        } else {
            children = .success(element.children)
        }
        return AccessibilityElementInspection(snapshot: element.snapshot, children: children)
    }

    func snapshot(of element: FakeElement) -> AccessibilityElementSnapshot {
        snapshotCount += 1
        return element.snapshot
    }

    func role(of element: FakeElement) -> String? {
        roleCount += 1
        return element.snapshot.role
    }

    func subrole(of element: FakeElement) -> String? {
        subroleCount += 1
        return element.snapshot.subrole
    }

    func title(of element: FakeElement) -> String? {
        titleCount += 1
        return element.snapshot.title
    }

    func value(of element: FakeElement) -> String? {
        valueCount += 1
        return element.snapshot.value
    }

    func help(of element: FakeElement) -> String? {
        helpCount += 1
        return element.snapshot.help
    }

    func frame(of element: FakeElement) -> CGRect? {
        frameCount += 1
        return element.snapshot.frame
    }

    func actions(of element: FakeElement) -> [String] {
        actionsCount += 1
        return element.snapshot.actions
    }

    func children(of element: FakeElement) -> Result<[FakeElement], AccessibilityScanFailure> {
        childrenCount += 1
        if let childrenFailure = element.childrenFailure {
            return .failure(childrenFailure)
        }

        return .success(element.children)
    }
}
