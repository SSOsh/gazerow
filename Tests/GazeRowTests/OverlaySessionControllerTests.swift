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
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 0)
        XCTAssertEqual(presenter.focusUpdates, [0])

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

    func test_handleKeyboardCommand_moveNext는_focusEngine상태를_갱신() {
        // given
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(presenter: presenter)

        // when
        let event = sut.handleKeyboardCommand(.move(.next))

        // then
        XCTAssertEqual(event, .focusChanged(from: 0, to: 1, method: .tab))
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 1)
        XCTAssertEqual(presenter.focusUpdates, [0, 1])
    }

    func test_handleKeyboardCommand_typeLabel은_labelJump로_focus를_갱신() {
        // given
        let sut = makeStartedSessionController()

        // when
        let event = sut.handleKeyboardCommand(.typeLabel("B"))

        // then
        XCTAssertEqual(event, .labelJump(typedLabel: "B", matched: true, to: 1))
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 1)
    }

    func test_handleKeyboardCommand_clearLabelBuffer는_buffer만_초기화() {
        // given
        let sut = makeStartedSessionController()
        _ = sut.handleKeyboardCommand(.typeLabel("A"))

        // when
        let event = sut.handleKeyboardCommand(.clearLabelBuffer)

        // then
        XCTAssertNil(event)
        XCTAssertEqual(sut.activeSession?.focusEngine.labelBuffer, "")
    }

    func test_handleKeyboardCommand_dryRunConfirm은_현재_focus_event를_반환() {
        // given
        let clickExecutor = StubOverlayClickExecutor(result: .failure(.missingFocusedTarget(index: 1)))
        let sut = makeStartedSessionController(clickExecutor: clickExecutor)
        _ = sut.handleKeyboardCommand(.move(.next))

        // when
        let event = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(event, .dryRunConfirm(index: 1))
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 1)
    }

    func test_handleKeyboardCommand_dryRunConfirm은_focusedIndex를_clickExecutor에_전달() {
        // given
        let clickExecutor = StubOverlayClickExecutor(
            result: .success(
                ClickExecutionSuccess(
                    method: .axPress,
                    riskClass: .safeNavigation,
                    fallbackUsed: false
                )
            )
        )
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            clickExecutor: clickExecutor
        )
        _ = sut.handleKeyboardCommand(.move(.next))

        // when
        let event = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(event, .dryRunConfirm(index: 1))
        XCTAssertEqual(clickExecutor.requests.map(\.focusedIndex), [1])
        XCTAssertEqual(clickExecutor.requests.first?.isSecondConfirmProvided, false)
        XCTAssertEqual(sut.lastClickResult, clickExecutor.result)
        XCTAssertNil(sut.activeSession)
        XCTAssertEqual(presenter.closeCallCount, 1)
    }

    func test_handleKeyboardCommand_click실패면_overlaySession을_유지() {
        // given
        let clickExecutor = StubOverlayClickExecutor(
            result: .failure(.executionFailed(.missingPressAction))
        )
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            clickExecutor: clickExecutor
        )

        // when
        let event = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(event, .dryRunConfirm(index: 0))
        XCTAssertEqual(sut.lastClickResult, clickExecutor.result)
        XCTAssertNotNil(sut.activeSession)
        XCTAssertEqual(presenter.closeCallCount, 0)
    }

    func test_handleKeyboardCommand_위험click은_secondConfirm을_대기하고_두번째_confirm에서_실행() {
        // given
        let clickExecutor = StubOverlayClickExecutor(
            results: [
                .failure(.executionFailed(.secondConfirmRequired(riskClass: .destructive))),
                .success(
                    ClickExecutionSuccess(
                        method: .axPress,
                        riskClass: .destructive,
                        fallbackUsed: false
                    )
                )
            ]
        )
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            clickExecutor: clickExecutor
        )

        // when
        let firstEvent = sut.handleKeyboardCommand(.dryRunConfirm)
        let secondEvent = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(firstEvent, .dryRunConfirm(index: 0))
        XCTAssertEqual(secondEvent, .dryRunConfirm(index: 0))
        XCTAssertEqual(clickExecutor.requests.map(\.isSecondConfirmProvided), [false, true])
        XCTAssertEqual(sut.activeSession, nil)
        XCTAssertEqual(presenter.closeCallCount, 1)
    }

    func test_handleKeyboardCommand_focus가_바뀌면_secondConfirm대기를_초기화() {
        // given
        let clickExecutor = StubOverlayClickExecutor(
            results: [
                .failure(.executionFailed(.secondConfirmRequired(riskClass: .destructive))),
                .failure(.executionFailed(.secondConfirmRequired(riskClass: .destructive)))
            ]
        )
        let sut = makeStartedSessionController(clickExecutor: clickExecutor)
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // when
        _ = sut.handleKeyboardCommand(.move(.next))
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(clickExecutor.requests.map(\.focusedIndex), [0, 1])
        XCTAssertEqual(clickExecutor.requests.map(\.isSecondConfirmProvided), [false, false])
        XCTAssertEqual(
            sut.activeSession?.pendingSecondConfirm,
            PendingSecondConfirm(focusedItemID: 1, riskClass: .destructive)
        )
    }

    func test_handleKeyboardCommand_focusChanged를_interactionLog에_기록() {
        // given
        let recorder = StubInteractionRecorder()
        let timestamp = Date(timeIntervalSince1970: 10)
        let hasher = WindowTitleHasher(salt: SessionSalt(value: "test-salt"))
        let sut = makeStartedSessionController(
            recorder: recorder,
            windowTitleHasher: hasher,
            dateProvider: { timestamp }
        )

        // when
        _ = sut.handleKeyboardCommand(.move(.next))

        // then
        XCTAssertEqual(
            recorder.events,
            [
                InteractionEvent(
                    timestamp: timestamp,
                    kind: .focusChanged(method: "tab"),
                    windowTitleHash: hasher.hash("Finder")
                )
            ]
        )
    }

    func test_handleKeyboardCommand_labelJump를_interactionLog에_기록() {
        // given
        let recorder = StubInteractionRecorder()
        let timestamp = Date(timeIntervalSince1970: 20)
        let hasher = WindowTitleHasher(salt: SessionSalt(value: "test-salt"))
        let sut = makeStartedSessionController(
            recorder: recorder,
            windowTitleHasher: hasher,
            dateProvider: { timestamp }
        )

        // when
        _ = sut.handleKeyboardCommand(.typeLabel("B"))

        // then
        XCTAssertEqual(
            recorder.events,
            [
                InteractionEvent(
                    timestamp: timestamp,
                    kind: .labelJump(matched: true),
                    windowTitleHash: hasher.hash("Finder")
                )
            ]
        )
    }

    func test_handleKeyboardCommand_dryRunConfirm은_interactionLog에_기록하지_않음() {
        // given
        let recorder = StubInteractionRecorder()
        let sut = makeStartedSessionController(recorder: recorder)

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertTrue(recorder.events.isEmpty)
    }

    func test_overlayKeyboardCallback은_controller_focus상태를_갱신() throws {
        // given
        let context = makeContext()
        let resolver = StubOverlayTargetResolver(result: .success(context))
        let scanner = StubOverlayScanner(
            result: .success(
                makeScanResult(
                    candidates: [
                        makeCandidate(frame: CGRect(x: 120, y: 140, width: 40, height: 20)),
                        makeCandidate(frame: CGRect(x: 220, y: 180, width: 44, height: 24))
                    ]
                )
            )
        )
        let presenter = StubOverlayPresenter()
        let sut = OverlaySessionController(
            targetResolver: resolver,
            scanner: scanner,
            overlayPresenter: presenter
        )
        _ = sut.start()

        // when
        try XCTUnwrap(presenter.keyboardCommandHandler)(.move(.next))

        // then
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 1)
    }

    func test_handleKeyboardCommand_closeOverlay는_session을_정리() {
        // given
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(presenter: presenter)

        // when
        let event = sut.handleKeyboardCommand(.closeOverlay)

        // then
        XCTAssertNil(event)
        XCTAssertNil(sut.activeSession)
        XCTAssertEqual(presenter.closeCallCount, 1)
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

    private func makeStartedSessionController(
        presenter: StubOverlayPresenter = StubOverlayPresenter(),
        recorder: StubInteractionRecorder = StubInteractionRecorder(),
        clickExecutor: StubOverlayClickExecutor = StubOverlayClickExecutor(result: .failure(.missingFocusedTarget(index: 0))),
        windowTitleHasher: WindowTitleHasher = WindowTitleHasher(salt: SessionSalt(value: "default-test-salt")),
        dateProvider: @escaping () -> Date = Date.init
    ) -> OverlaySessionController {
        let context = makeContext()
        let resolver = StubOverlayTargetResolver(result: .success(context))
        let scanner = StubOverlayScanner(
            result: .success(
                makeScanResult(
                    candidates: [
                        makeCandidate(frame: CGRect(x: 120, y: 140, width: 40, height: 20)),
                        makeCandidate(frame: CGRect(x: 220, y: 180, width: 44, height: 24))
                    ]
                )
            )
        )
        let sut = OverlaySessionController(
            targetResolver: resolver,
            scanner: scanner,
            overlayPresenter: presenter,
            interactionRecorder: recorder,
            clickExecutor: clickExecutor,
            windowTitleHasher: windowTitleHasher,
            dateProvider: dateProvider
        )
        _ = sut.start()
        return sut
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
    private(set) var keyboardCommandHandler: ((FocusKeyboardCommand) -> Void)?
    private(set) var focusUpdates: [Int?] = []

    func show(
        targetFrame: CGRect,
        candidates: [ClickableCandidate],
        labels: [String],
        onEscape: @escaping () -> Void,
        onKeyboardCommand: @MainActor @escaping (FocusKeyboardCommand) -> Void
    ) -> OverlayLayout {
        showRequests.append(
            ShowRequest(
                targetFrame: targetFrame,
                candidates: candidates,
                labels: labels
            )
        )
        keyboardCommandHandler = onKeyboardCommand
        return OverlayLayoutEngine().makeLayout(
            targetFrame: targetFrame,
            candidates: candidates,
            labels: labels
        )
    }

    func close() {
        closeCallCount += 1
    }

    func updateFocus(focusedLabelID: Int?) {
        focusUpdates.append(focusedLabelID)
    }
}

private struct ShowRequest: Equatable {
    let targetFrame: CGRect
    let candidates: [ClickableCandidate]
    let labels: [String]
}

@MainActor
private final class StubInteractionRecorder: OverlaySessionInteractionRecording {
    private(set) var events: [InteractionEvent] = []

    func record(_ event: InteractionEvent) {
        events.append(event)
    }
}

@MainActor
private final class StubOverlayClickExecutor: OverlaySessionClickExecuting {
    private let results: [Result<ClickExecutionSuccess, OverlaySessionClickFailure>]
    private(set) var requests: [ClickRequest] = []
    private(set) var lastReturnedResult: Result<ClickExecutionSuccess, OverlaySessionClickFailure>?

    var result: Result<ClickExecutionSuccess, OverlaySessionClickFailure> {
        results[0]
    }

    init(result: Result<ClickExecutionSuccess, OverlaySessionClickFailure>) {
        self.results = [result]
    }

    init(results: [Result<ClickExecutionSuccess, OverlaySessionClickFailure>]) {
        self.results = results
    }

    func execute(
        focusedIndex: Int,
        context: TargetContext,
        isSecondConfirmProvided: Bool
    ) -> Result<ClickExecutionSuccess, OverlaySessionClickFailure> {
        requests.append(
            ClickRequest(
                focusedIndex: focusedIndex,
                context: context,
                isSecondConfirmProvided: isSecondConfirmProvided
            )
        )
        let index = min(requests.count - 1, results.count - 1)
        let result = results[index]
        lastReturnedResult = result
        return result
    }
}

private struct ClickRequest: Equatable {
    let focusedIndex: Int
    let context: TargetContext
    let isSecondConfirmProvided: Bool
}
