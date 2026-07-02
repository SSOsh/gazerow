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
        frame: CGRect?,
        actions: [String] = [AccessibilityAction.press]
    ) -> AccessibilityElementSnapshot {
        AccessibilityElementSnapshot(
            role: role,
            subrole: nil,
            title: "Open",
            value: nil,
            help: nil,
            frame: frame,
            actions: actions
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

@MainActor
private struct FakeClickTargetClient: AccessibilityElementClient {
    let root: Result<FakeClickElement, AccessibilityScanFailure>

    func rootElement(for context: TargetContext) -> Result<FakeClickElement, AccessibilityScanFailure> {
        root
    }

    func snapshot(of element: FakeClickElement) -> AccessibilityElementSnapshot {
        element.snapshot
    }

    func children(of element: FakeClickElement) -> Result<[FakeClickElement], AccessibilityScanFailure> {
        .success(element.children)
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
