import CoreGraphics
import XCTest
@testable import GazeRow

/// OverlaySessionClickTargetResolver 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class OverlaySessionClickTargetResolverTests: XCTestCase {

    func test_resolveTargets_clickableElement를_scan순서대로_수집() throws {
        // given
        let first = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        )
        let second = FakeClickElement(
            id: 2,
            snapshot: makeSnapshot(frame: CGRect(x: 40, y: 10, width: 20, height: 20))
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(role: "AXGroup", frame: CGRect(x: 0, y: 0, width: 100, height: 100), actions: []),
            children: [first, second]
        )
        let sut = OverlaySessionClickTargetResolver(
            client: FakeClickTargetClient(root: .success(root))
        )

        // when
        let result = sut.resolveTargets(context: makeContext())

        // then
        let targets = try unwrapSuccess(result)
        XCTAssertEqual(targets.map(\.element.id), [1, 2])
        XCTAssertEqual(targets.map(\.frame), [first.snapshot.frame, second.snapshot.frame])
    }

    func test_resolveTargets_additionalRootElement를_scanner와_같은_순서로_수집() throws {
        // given
        let primary = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        )
        let additional = FakeClickElement(
            id: 2,
            snapshot: makeSnapshot(frame: CGRect(x: 40, y: 10, width: 20, height: 20))
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(role: "AXGroup", frame: CGRect(x: 0, y: 0, width: 100, height: 100), actions: []),
            children: [primary]
        )
        let sut = OverlaySessionClickTargetResolver(
            client: FakeClickTargetClient(root: .success(root), extraRoots: [additional])
        )

        // when
        let result = sut.resolveTargets(context: makeContext())

        // then
        let targets = try unwrapSuccess(result)
        XCTAssertEqual(targets.map(\.element.id), [2, 1])
    }

    func test_resolveTargets_selectableContainerRole은_action이_없어도_수집() throws {
        // given
        let row = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(
                role: AccessibilityRole.row,
                frame: CGRect(x: 10, y: 10, width: 80, height: 24),
                actions: []
            )
        )
        let cell = FakeClickElement(
            id: 2,
            snapshot: makeSnapshot(
                role: AccessibilityRole.cell,
                frame: CGRect(x: 10, y: 42, width: 80, height: 24),
                actions: []
            )
        )
        let image = FakeClickElement(
            id: 3,
            snapshot: makeSnapshot(
                role: AccessibilityRole.image,
                frame: CGRect(x: 10, y: 74, width: 32, height: 32),
                actions: []
            )
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(role: "AXGroup", frame: CGRect(x: 0, y: 0, width: 100, height: 120), actions: []),
            children: [row, cell, image]
        )
        let sut = OverlaySessionClickTargetResolver(
            client: FakeClickTargetClient(root: .success(root))
        )

        // when
        let result = sut.resolveTargets(context: makeContext())

        // then
        let targets = try unwrapSuccess(result)
        XCTAssertEqual(targets.map(\.element.id), [1, 2, 3])
        XCTAssertEqual(
            targets.map(\.role),
            [
                AccessibilityRole.row,
                AccessibilityRole.cell,
                AccessibilityRole.image
            ]
        )
    }

    func test_resolveTargets_defaultDepth는_VSCode_activityBar처럼_깊은_target을_수집() throws {
        // given
        let activityBarItem = FakeClickElement(
            id: 17,
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
        let sut = OverlaySessionClickTargetResolver(
            client: FakeClickTargetClient(root: .success(root))
        )

        // when
        let result = sut.resolveTargets(context: makeContext())

        // then
        let targets = try unwrapSuccess(result)
        XCTAssertEqual(targets.first?.element.id, 17)
        XCTAssertEqual(targets.first?.role, AccessibilityRole.radioButton)
        XCTAssertEqual(targets.first?.subrole, "AXTabButton")
    }

    func test_resolveTargets_textArea는_target으로_resolve되고_secureField처럼_필터되지않음() throws {
        // given
        let textArea = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(
                role: AccessibilityRole.textArea,
                frame: CGRect(x: 10, y: 10, width: 200, height: 80),
                actions: []
            )
        )
        let secure = FakeClickElement(
            id: 2,
            snapshot: makeSnapshot(
                role: AccessibilityRole.secureTextField,
                frame: CGRect(x: 10, y: 100, width: 200, height: 24),
                actions: []
            )
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(role: "AXGroup", frame: CGRect(x: 0, y: 0, width: 220, height: 200), actions: []),
            children: [textArea, secure]
        )
        let sut = OverlaySessionClickTargetResolver(
            client: FakeClickTargetClient(root: .success(root))
        )

        // when
        let result = sut.resolveTargets(context: makeContext())

        // then
        let targets = try unwrapSuccess(result)
        XCTAssertEqual(targets.map(\.element.id), [1])
        XCTAssertEqual(targets.first?.role, AccessibilityRole.textArea)
    }

    func test_resolveTargets_AXSetValue_action이_있는_customInput도_target으로_resolve한다() throws {
        // given
        let customInput = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(
                role: "AXGroup",
                title: "Message editor",
                frame: CGRect(x: 10, y: 10, width: 240, height: 44),
                actions: [AccessibilityAction.setValue]
            )
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(role: "AXGroup", frame: CGRect(x: 0, y: 0, width: 260, height: 80), actions: []),
            children: [customInput]
        )
        let sut = OverlaySessionClickTargetResolver(
            client: FakeClickTargetClient(root: .success(root))
        )

        // when
        let result = sut.resolveTargets(context: makeContext())

        // then
        let targets = try unwrapSuccess(result)
        XCTAssertEqual(targets.map(\.element.id), [1])
        XCTAssertEqual(targets.first?.actions, [AccessibilityAction.setValue])
    }

    func test_resolveTargets_textInput_subrole이_있는_customInput도_target으로_resolve한다() throws {
        // given
        let customInput = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(
                role: "AXGroup",
                subrole: "AXTextInput",
                title: "Chat input",
                frame: CGRect(x: 10, y: 10, width: 240, height: 44),
                actions: []
            )
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(role: "AXGroup", frame: CGRect(x: 0, y: 0, width: 260, height: 80), actions: []),
            children: [customInput]
        )
        let sut = OverlaySessionClickTargetResolver(
            client: FakeClickTargetClient(root: .success(root))
        )

        // when
        let result = sut.resolveTargets(context: makeContext())

        // then
        let targets = try unwrapSuccess(result)
        XCTAssertEqual(targets.map(\.element.id), [1])
        XCTAssertEqual(targets.first?.subrole, "AXTextInput")
    }

    func test_resolveTargets_defaultDepth는_webArea_깊은_textArea도_target으로_resolve한다() throws {
        // given
        let textArea = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(
                role: AccessibilityRole.textArea,
                frame: CGRect(x: 750, y: 1143, width: 713, height: 44),
                actions: []
            )
        )
        let root = nestedElement(depth: 28, leaf: textArea)
        let sut = OverlaySessionClickTargetResolver(
            client: FakeClickTargetClient(root: .success(root))
        )

        // when
        let result = sut.resolveTargets(context: makeContext())

        // then
        let targets = try unwrapSuccess(result)
        XCTAssertEqual(targets.map(\.element.id), [1])
        XCTAssertEqual(targets.first?.role, AccessibilityRole.textArea)
    }

    func test_resolveTargets_secureField와_frame없는_element는_제외() throws {
        // given
        let secure = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(
                role: AccessibilityRole.secureTextField,
                frame: CGRect(x: 10, y: 10, width: 20, height: 20)
            )
        )
        let noFrame = FakeClickElement(id: 2, snapshot: makeSnapshot(frame: nil))
        let valid = FakeClickElement(
            id: 3,
            snapshot: makeSnapshot(frame: CGRect(x: 40, y: 10, width: 20, height: 20))
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(role: "AXGroup", frame: CGRect(x: 0, y: 0, width: 100, height: 100), actions: []),
            children: [secure, noFrame, valid]
        )
        let sut = OverlaySessionClickTargetResolver(
            client: FakeClickTargetClient(root: .success(root))
        )

        // when
        let result = sut.resolveTargets(context: makeContext())

        // then
        let targets = try unwrapSuccess(result)
        XCTAssertEqual(targets.map(\.element.id), [3])
    }

    func test_resolveTargets_중복_target은_하나만_남김() throws {
        // given
        let frame = CGRect(x: 10, y: 10, width: 20, height: 20)
        let first = FakeClickElement(id: 1, snapshot: makeSnapshot(frame: frame))
        let duplicate = FakeClickElement(id: 2, snapshot: makeSnapshot(frame: frame))
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(role: "AXGroup", frame: CGRect(x: 0, y: 0, width: 100, height: 100), actions: []),
            children: [first, duplicate]
        )
        let sut = OverlaySessionClickTargetResolver(
            client: FakeClickTargetClient(root: .success(root))
        )

        // when
        let result = sut.resolveTargets(context: makeContext())

        // then
        let targets = try unwrapSuccess(result)
        XCTAssertEqual(targets.map(\.element.id), [1])
    }

    func test_resolveTargets_rootFailure를_전달() {
        // given
        let sut = OverlaySessionClickTargetResolver(
            client: FakeClickTargetClient(root: .failure(.accessibilityPermissionDenied))
        )

        // when
        let result = sut.resolveTargets(context: makeContext())

        // then
        XCTAssertEqual(result.failureValue, .accessibilityPermissionDenied)
    }

    func test_resolveTarget은_descriptor경로의_children만읽는다() throws {
        // given
        let target = FakeClickElement(
            id: 3,
            snapshot: makeSnapshot(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        )
        let branch = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(
                role: "AXGroup",
                frame: CGRect(x: 0, y: 0, width: 50, height: 50),
                actions: []
            ),
            children: [target]
        )
        let unrelated = nestedElement(
            depth: 8,
            leaf: FakeClickElement(
                id: 99,
                snapshot: makeSnapshot(frame: CGRect(x: 70, y: 70, width: 20, height: 20))
            )
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(
                role: "AXGroup",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                actions: []
            ),
            children: [branch, unrelated]
        )
        let client = CountingClickTargetClient(root: .success(root))
        let sut = OverlaySessionClickTargetResolver(client: client)

        // when
        let result = sut.resolveTarget(
            context: makeContext(),
            descriptor: AccessibilityTargetDescriptor(axPath: [0, 0])
        )

        // then
        XCTAssertEqual(try unwrapTarget(result)?.element.id, 3)
        XCTAssertEqual(client.childrenCount, 2)
        XCTAssertEqual(client.roleCount, 1)
    }

    func test_resolveTarget은_additionalRoot경로를해석한다() throws {
        // given
        let target = FakeClickElement(
            id: 7,
            snapshot: makeSnapshot(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        )
        let additionalRoot = FakeClickElement(
            id: 6,
            snapshot: makeSnapshot(
                role: "AXGroup",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                actions: []
            ),
            children: [target]
        )
        let client = CountingClickTargetClient(
            root: .success(
                FakeClickElement(
                    id: 0,
                    snapshot: makeSnapshot(
                        role: "AXGroup",
                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                        actions: []
                    )
                )
            ),
            extraRoots: [additionalRoot]
        )
        let sut = OverlaySessionClickTargetResolver(client: client)

        // when
        let result = sut.resolveTarget(
            context: makeContext(),
            descriptor: AccessibilityTargetDescriptor(axPath: [-1, 0])
        )

        // then
        XCTAssertEqual(try unwrapTarget(result)?.element.id, 7)
        XCTAssertEqual(client.childrenCount, 1)
    }

    func test_revalidate_generation동일이면_selectivePath로검증한다() {
        // given
        let target = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(
                role: "AXGroup",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                actions: []
            ),
            children: [target]
        )
        let client = CountingClickTargetClient(root: .success(root))
        let store = AccessibilityTreeGenerationStore()
        store.setMonitoringActive(true, for: 100)
        let sut = OverlayClickTargetRevalidator(
            targetResolver: OverlaySessionClickTargetResolver(client: client),
            generationStore: store
        )

        // when
        let result = sut.revalidate(
            selection: makeSelection(
                candidate: makeCandidate(from: target.snapshot),
                descriptor: AccessibilityTargetDescriptor(axPath: [0]),
                isChangeMonitoringActive: true
            ),
            context: makeContext()
        )

        // then
        guard case .matched(let matched, _, let path, _) = result else {
            return XCTFail("selective match가 필요합니다.")
        }
        XCTAssertEqual(matched.element.id, 1)
        XCTAssertEqual(path, .selective)
        XCTAssertEqual(client.childrenCount, 1)
    }

    func test_revalidate_generation변경이면_fullRescan한다() {
        // given
        let target = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(
                role: "AXGroup",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                actions: []
            ),
            children: [target]
        )
        let client = CountingClickTargetClient(root: .success(root))
        let store = AccessibilityTreeGenerationStore()
        _ = store.recordChange(AccessibilityChangeMetadata(kind: .layout), for: 100)
        store.setMonitoringActive(true, for: 100)
        let sut = OverlayClickTargetRevalidator(
            targetResolver: OverlaySessionClickTargetResolver(client: client),
            generationStore: store
        )

        // when
        let result = sut.revalidate(
            selection: makeSelection(
                candidate: makeCandidate(from: target.snapshot),
                descriptor: AccessibilityTargetDescriptor(axPath: [0]),
                isChangeMonitoringActive: true
            ),
            context: makeContext()
        )

        // then
        guard case .matched(_, _, let path, _) = result else {
            return XCTFail("full-rescan match가 필요합니다.")
        }
        XCTAssertEqual(path, .fullRescan)
        XCTAssertEqual(client.childrenCount, 2)
    }

    func test_revalidate_path가사라지면_fullRescan후_unavailable이다() {
        // given
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(
                role: "AXGroup",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                actions: []
            )
        )
        let store = AccessibilityTreeGenerationStore()
        store.setMonitoringActive(true, for: 100)
        let sut = OverlayClickTargetRevalidator(
            targetResolver: OverlaySessionClickTargetResolver(
                client: FakeClickTargetClient(root: .success(root))
            ),
            generationStore: store
        )

        // when
        let result = sut.revalidate(
            selection: makeSelection(
                candidate: makeCandidate(
                    from: makeSnapshot(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
                ),
                descriptor: AccessibilityTargetDescriptor(axPath: [4]),
                isChangeMonitoringActive: true
            ),
            context: makeContext()
        )

        // then
        guard case .unavailable(let path) = result else {
            return XCTFail("unavailable 결과가 필요합니다.")
        }
        XCTAssertEqual(path, .fullRescan)
    }

    func test_revalidate_frame변경은_fullRescan후_changed이다() {
        // given
        let original = makeSnapshot(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        let moved = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(frame: CGRect(x: 70, y: 70, width: 20, height: 20))
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(
                role: "AXGroup",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                actions: []
            ),
            children: [moved]
        )
        let store = AccessibilityTreeGenerationStore()
        store.setMonitoringActive(true, for: 100)
        let sut = OverlayClickTargetRevalidator(
            targetResolver: OverlaySessionClickTargetResolver(
                client: FakeClickTargetClient(root: .success(root))
            ),
            generationStore: store
        )

        // when
        let result = sut.revalidate(
            selection: makeSelection(
                candidate: makeCandidate(from: original),
                descriptor: AccessibilityTargetDescriptor(axPath: [0]),
                isChangeMonitoringActive: true
            ),
            context: makeContext()
        )

        // then
        guard case .changed(let path) = result else {
            return XCTFail("changed 결과가 필요합니다.")
        }
        XCTAssertEqual(path, .fullRescan)
    }

    func test_revalidate_observer비활성화면_fullRescan하고_중복은ambiguous이다() {
        // given
        let firstSnapshot = makeSnapshot(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(
                role: "AXGroup",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                actions: []
            ),
            children: [
                FakeClickElement(id: 1, snapshot: firstSnapshot),
                FakeClickElement(
                    id: 2,
                    snapshot: makeSnapshot(frame: CGRect(x: 18, y: 10, width: 20, height: 20))
                )
            ]
        )
        let sut = OverlayClickTargetRevalidator(
            targetResolver: OverlaySessionClickTargetResolver(
                client: FakeClickTargetClient(root: .success(root))
            ),
            generationStore: AccessibilityTreeGenerationStore()
        )

        // when
        let result = sut.revalidate(
            selection: makeSelection(
                candidate: makeCandidate(from: firstSnapshot),
                descriptor: AccessibilityTargetDescriptor(axPath: [0]),
                isChangeMonitoringActive: false
            ),
            context: makeContext()
        )

        // then
        guard case .ambiguous(let path) = result else {
            return XCTFail("ambiguous 결과가 필요합니다.")
        }
        XCTAssertEqual(path, .fullRescan)
    }

    func test_revalidate_secureField는_fullRescan후_unavailable이다() {
        // given
        let secure = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(
                role: AccessibilityRole.secureTextField,
                frame: CGRect(x: 10, y: 10, width: 20, height: 20)
            )
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(
                role: "AXGroup",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                actions: []
            ),
            children: [secure]
        )
        let store = AccessibilityTreeGenerationStore()
        store.setMonitoringActive(true, for: 100)
        let sut = OverlayClickTargetRevalidator(
            targetResolver: OverlaySessionClickTargetResolver(
                client: FakeClickTargetClient(root: .success(root))
            ),
            generationStore: store
        )

        // when
        let result = sut.revalidate(
            selection: makeSelection(
                candidate: makeCandidate(from: secure.snapshot),
                descriptor: AccessibilityTargetDescriptor(axPath: [0]),
                isChangeMonitoringActive: true
            ),
            context: makeContext()
        )

        // then
        guard case .unavailable(let path) = result else {
            return XCTFail("secure field는 unavailable이어야 합니다.")
        }
        XCTAssertEqual(path, .fullRescan)
    }

    func test_resolveTargets_후보가_아닌_node는_비싼속성을_읽지_않음() throws {
        // given
        let button = FakeClickElement(
            id: 1,
            snapshot: makeSnapshot(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        )
        let root = FakeClickElement(
            id: 0,
            snapshot: makeSnapshot(role: "AXGroup", frame: CGRect(x: 0, y: 0, width: 100, height: 100), actions: []),
            children: [button]
        )
        let client = CountingClickTargetClient(root: .success(root))
        let sut = OverlaySessionClickTargetResolver(client: client)

        // when
        let result = sut.resolveTargets(context: makeContext())

        // then
        let targets = try unwrapSuccess(result)
        XCTAssertEqual(targets.map(\.element.id), [1])
        XCTAssertEqual(client.snapshotCount, 0)
        XCTAssertEqual(client.roleCount, 2)
        XCTAssertEqual(client.actionsCount, 2)
        XCTAssertEqual(client.titleCount, 1)
        XCTAssertEqual(client.frameCount, 1)
        XCTAssertEqual(client.subroleCount, 1)
        XCTAssertEqual(client.valueCount, 0)
        XCTAssertEqual(client.helpCount, 0)
    }

    private func makeContext() -> TargetContext {
        TargetContext(
            application: TargetApplication(
                localizedName: "Finder",
                bundleIdentifier: "com.apple.finder",
                processIdentifier: 100
            ),
            window: TargetWindow(
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                title: "Finder"
            ),
            resolvedAt: Date(timeIntervalSince1970: 1)
        )
    }

    private func makeSnapshot(
        role: String = AccessibilityRole.button,
        subrole: String? = nil,
        title: String? = "Open",
        frame: CGRect?,
        actions: [String] = [AccessibilityAction.press]
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

    private func nestedElement(depth: Int, leaf: FakeClickElement) -> FakeClickElement {
        guard depth > 0 else {
            return leaf
        }

        return FakeClickElement(
            id: -depth,
            snapshot: makeSnapshot(role: "AXGroup", frame: CGRect(x: 0, y: 0, width: 100, height: 100), actions: []),
            children: [nestedElement(depth: depth - 1, leaf: leaf)]
        )
    }

    private func unwrapSuccess(
        _ result: Result<[ClickTarget<FakeClickElement>], AccessibilityScanFailure>
    ) throws -> [ClickTarget<FakeClickElement>] {
        switch result {
        case .success(let targets):
            targets
        case .failure(let failure):
            throw failure
        }
    }

    private func unwrapTarget(
        _ result: Result<ClickTarget<FakeClickElement>?, AccessibilityScanFailure>
    ) throws -> ClickTarget<FakeClickElement>? {
        switch result {
        case .success(let target):
            target
        case .failure(let failure):
            throw failure
        }
    }

    private func makeCandidate(
        from snapshot: AccessibilityElementSnapshot
    ) -> ClickableCandidate {
        ClickableCandidate(
            role: snapshot.role ?? "",
            subrole: snapshot.subrole,
            title: snapshot.title,
            frame: snapshot.frame ?? .zero,
            actions: snapshot.actions
        )
    }

    private func makeSelection(
        candidate: ClickableCandidate,
        descriptor: AccessibilityTargetDescriptor?,
        isChangeMonitoringActive: Bool
    ) -> OverlayClickSelection {
        OverlayClickSelection(
            labelID: 0,
            candidate: candidate,
            sourceCandidateCount: 1,
            targetDescriptor: descriptor,
            generation: .initial,
            isChangeMonitoringActive: isChangeMonitoringActive
        )
    }
}

private struct FakeClickElement: Equatable {
    let id: Int
    let snapshot: AccessibilityElementSnapshot
    let children: [FakeClickElement]

    init(
        id: Int,
        snapshot: AccessibilityElementSnapshot,
        children: [FakeClickElement] = []
    ) {
        self.id = id
        self.snapshot = snapshot
        self.children = children
    }
}

private struct FakeClickTargetClient: AccessibilityElementClient {
    let root: Result<FakeClickElement, AccessibilityScanFailure>
    var extraRoots: [FakeClickElement] = []

    func rootElement(for context: TargetContext) -> Result<FakeClickElement, AccessibilityScanFailure> {
        root
    }

    func additionalRootElements(for context: TargetContext) -> [FakeClickElement] {
        extraRoots
    }

    func snapshot(of element: FakeClickElement) -> AccessibilityElementSnapshot {
        element.snapshot
    }

    func children(of element: FakeClickElement) -> Result<[FakeClickElement], AccessibilityScanFailure> {
        .success(element.children)
    }
}

private final class CountingClickTargetClient: AccessibilityElementClient {
    let root: Result<FakeClickElement, AccessibilityScanFailure>
    let extraRoots: [FakeClickElement]
    private(set) var snapshotCount = 0
    private(set) var roleCount = 0
    private(set) var subroleCount = 0
    private(set) var titleCount = 0
    private(set) var valueCount = 0
    private(set) var helpCount = 0
    private(set) var frameCount = 0
    private(set) var actionsCount = 0
    private(set) var childrenCount = 0

    init(
        root: Result<FakeClickElement, AccessibilityScanFailure>,
        extraRoots: [FakeClickElement] = []
    ) {
        self.root = root
        self.extraRoots = extraRoots
    }

    func rootElement(for context: TargetContext) -> Result<FakeClickElement, AccessibilityScanFailure> {
        root
    }

    func additionalRootElements(for context: TargetContext) -> [FakeClickElement] {
        extraRoots
    }

    func snapshot(of element: FakeClickElement) -> AccessibilityElementSnapshot {
        snapshotCount += 1
        return element.snapshot
    }

    func role(of element: FakeClickElement) -> String? {
        roleCount += 1
        return element.snapshot.role
    }

    func subrole(of element: FakeClickElement) -> String? {
        subroleCount += 1
        return element.snapshot.subrole
    }

    func title(of element: FakeClickElement) -> String? {
        titleCount += 1
        return element.snapshot.title
    }

    func value(of element: FakeClickElement) -> String? {
        valueCount += 1
        return element.snapshot.value
    }

    func help(of element: FakeClickElement) -> String? {
        helpCount += 1
        return element.snapshot.help
    }

    func frame(of element: FakeClickElement) -> CGRect? {
        frameCount += 1
        return element.snapshot.frame
    }

    func actions(of element: FakeClickElement) -> [String] {
        actionsCount += 1
        return element.snapshot.actions
    }

    func children(of element: FakeClickElement) -> Result<[FakeClickElement], AccessibilityScanFailure> {
        childrenCount += 1
        return .success(element.children)
    }
}

private extension Result where Failure == AccessibilityScanFailure {
    var failureValue: AccessibilityScanFailure? {
        if case .failure(let failure) = self {
            return failure
        }
        return nil
    }
}
