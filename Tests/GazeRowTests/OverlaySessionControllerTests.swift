import CoreGraphics
import Foundation
import XCTest
@testable import GazeRow

/// OverlaySessionController 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class OverlaySessionControllerTests: XCTestCase {

    func test_start_sessionDisabled이면_overlay를_닫고_resolve하지_않음() {
        // given
        let resolver = StubOverlayTargetResolver(result: .success(makeContext()))
        let scanner = StubOverlayScanner(result: .success(makeScanResult(candidates: [makeCandidate()])))
        let presenter = StubOverlayPresenter()
        let sut = OverlaySessionController(
            targetResolver: resolver,
            scanner: scanner,
            overlayPresenter: presenter,
            isSessionEnabled: { false }
        )

        // when
        let result = sut.start()

        // then
        XCTAssertEqual(result, .failure(.sessionDisabled))
        XCTAssertEqual(presenter.closeCallCount, 1)
        XCTAssertEqual(resolver.resolveCallCount, 0)
        XCTAssertEqual(scanner.scanCallCount, 0)
        XCTAssertTrue(presenter.showRequests.isEmpty)
    }

    func test_start_성공하면_resolve_scan_overlayShow를_순서대로_실행() throws {
        // given
        let context = makeContext()
        let candidates = [
            makeCandidate(frame: CGRect(x: 120, y: 140, width: 40, height: 20)),
            makeCandidate(frame: CGRect(x: 220, y: 180, width: 44, height: 24))
        ]
        let scanResult = makeScanResult(candidates: candidates)
        let resolver = StubOverlayTargetResolver(result: .success(context))
        let scanner = StubOverlayScanner(result: .success(scanResult))
        let presenter = StubOverlayPresenter()
        let sut = OverlaySessionController(
            targetResolver: resolver,
            scanner: scanner,
            overlayPresenter: presenter,
            isSessionEnabled: { true }
        )

        // when
        let result = sut.start()

        // then
        guard case .success(let snapshot) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(snapshot.context, context)
        XCTAssertEqual(snapshot.scanResult, scanResult)
        XCTAssertEqual(snapshot.layout.metrics.labelCount, 2)
        XCTAssertEqual(resolver.resolveCallCount, 1)
        XCTAssertEqual(scanner.scanCallCount, 1)
        XCTAssertEqual(scanner.receivedContext, context)
        XCTAssertEqual(presenter.closeCallCount, 0)

        let request = try XCTUnwrap(presenter.showRequests.first)
        XCTAssertEqual(request.targetFrame, context.window.frame)
        XCTAssertEqual(request.candidates, candidates)
    }

    func test_start_targetResolve실패면_overlay를_닫고_scan하지_않음() {
        // given
        let resolver = StubOverlayTargetResolver(result: .failure(.noFrontmostApplication))
        let scanner = StubOverlayScanner(result: .success(makeScanResult(candidates: [makeCandidate()])))
        let presenter = StubOverlayPresenter()
        let sut = OverlaySessionController(
            targetResolver: resolver,
            scanner: scanner,
            overlayPresenter: presenter
        )

        // when
        let result = sut.start()

        // then
        XCTAssertEqual(result, .failure(.targetResolutionFailed(.noFrontmostApplication)))
        XCTAssertEqual(presenter.closeCallCount, 1)
        XCTAssertEqual(resolver.resolveCallCount, 1)
        XCTAssertEqual(scanner.scanCallCount, 0)
        XCTAssertTrue(presenter.showRequests.isEmpty)
    }

    func test_start_scan실패면_overlay를_닫고_show하지_않음() {
        // given
        let context = makeContext()
        let resolver = StubOverlayTargetResolver(result: .success(context))
        let scanner = StubOverlayScanner(result: .failure(.accessibilityPermissionDenied))
        let presenter = StubOverlayPresenter()
        let sut = OverlaySessionController(
            targetResolver: resolver,
            scanner: scanner,
            overlayPresenter: presenter
        )

        // when
        let result = sut.start()

        // then
        XCTAssertEqual(result, .failure(.scanFailed(.accessibilityPermissionDenied)))
        XCTAssertEqual(presenter.closeCallCount, 1)
        XCTAssertEqual(scanner.receivedContext, context)
        XCTAssertTrue(presenter.showRequests.isEmpty)
    }

    func test_start_candidate가_없으면_overlay를_닫고_noCandidates를_반환() {
        // given
        let context = makeContext()
        let scanResult = makeScanResult(candidates: [])
        let resolver = StubOverlayTargetResolver(result: .success(context))
        let scanner = StubOverlayScanner(result: .success(scanResult))
        let presenter = StubOverlayPresenter()
        let sut = OverlaySessionController(
            targetResolver: resolver,
            scanner: scanner,
            overlayPresenter: presenter
        )

        // when
        let result = sut.start()

        // then
        XCTAssertEqual(result, .failure(.noCandidates(context: context, scanResult: scanResult)))
        XCTAssertEqual(presenter.closeCallCount, 1)
        XCTAssertTrue(presenter.showRequests.isEmpty)
    }

    func test_failureLogCode는_windowTitle과_상세reason을_포함하지_않음() {
        // given
        let context = makeContext()
        let scanResult = makeScanResult(candidates: [])
        let failures: [OverlaySessionStartFailure] = [
            .sessionDisabled,
            .targetResolutionFailed(.focusedWindowUnavailable(bundleIdentifier: "com.apple.finder", reason: "raw detail")),
            .scanFailed(.childrenUnavailable("raw child detail")),
            .noCandidates(context: context, scanResult: scanResult)
        ]

        // when
        let logCodes = failures.map(\.logCode)

        // then
        XCTAssertEqual(
            logCodes,
            [
                "session_disabled",
                "target_resolution_failed.focused_window_unavailable",
                "scan_failed.children_unavailable",
                "no_candidates"
            ]
        )
        XCTAssertFalse(logCodes.joined(separator: " ").contains("Finder"))
        XCTAssertFalse(logCodes.joined(separator: " ").contains("raw"))
    }

    private func makeContext() -> TargetContext {
        TargetContext(
            application: TargetApplication(
                localizedName: "Finder",
                bundleIdentifier: "com.apple.finder",
                processIdentifier: 100
            ),
            window: TargetWindow(
                frame: CGRect(x: 100, y: 100, width: 500, height: 320),
                title: "Finder"
            ),
            resolvedAt: Date(timeIntervalSince1970: 1_788_748_400)
        )
    }

    private func makeScanResult(candidates: [ClickableCandidate]) -> AccessibilityScanResult {
        AccessibilityScanResult(
            candidates: candidates,
            nodesVisited: candidates.count + 1,
            scanDuration: 0.01,
            didHitDepthLimit: false,
            didHitNodeLimit: false,
            didTimeout: false,
            failedChildReadCount: 0
        )
    }

    private func makeCandidate(
        frame: CGRect = CGRect(x: 120, y: 140, width: 40, height: 20)
    ) -> ClickableCandidate {
        ClickableCandidate(
            role: AccessibilityRole.button,
            subrole: nil,
            title: "Open",
            frame: frame,
            actions: [AccessibilityAction.press]
        )
    }
}

@MainActor
private final class StubOverlayTargetResolver: OverlaySessionTargetResolving {
    private let result: Result<TargetContext, TargetResolutionFailure>
    private(set) var resolveCallCount = 0

    init(result: Result<TargetContext, TargetResolutionFailure>) {
        self.result = result
    }

    func resolve() -> Result<TargetContext, TargetResolutionFailure> {
        resolveCallCount += 1
        return result
    }
}

@MainActor
private final class StubOverlayScanner: OverlaySessionScanning {
    private let result: Result<AccessibilityScanResult, AccessibilityScanFailure>
    private(set) var scanCallCount = 0
    private(set) var receivedContext: TargetContext?

    init(result: Result<AccessibilityScanResult, AccessibilityScanFailure>) {
        self.result = result
    }

    func scan(context: TargetContext) -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        scanCallCount += 1
        receivedContext = context
        return result
    }
}

@MainActor
private final class StubOverlayPresenter: OverlaySessionPresenting {
    private(set) var showRequests: [ShowRequest] = []
    private(set) var closeCallCount = 0

    func show(
        targetFrame: CGRect,
        candidates: [ClickableCandidate],
        labels: [String],
        onEscape: @escaping () -> Void,
        onKeyboardCommand: @escaping (FocusKeyboardCommand) -> Void
    ) -> OverlayLayout {
        showRequests.append(
            ShowRequest(
                targetFrame: targetFrame,
                candidates: candidates,
                labels: labels
            )
        )
        return OverlayLayoutEngine().makeLayout(
            targetFrame: targetFrame,
            candidates: candidates,
            labels: labels
        )
    }

    func close() {
        closeCallCount += 1
    }
}

private struct ShowRequest: Equatable {
    let targetFrame: CGRect
    let candidates: [ClickableCandidate]
    let labels: [String]
}
