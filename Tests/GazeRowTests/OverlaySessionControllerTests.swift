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
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(presenter: presenter)

        // when
        let event = sut.handleKeyboardCommand(.typeLabel("S"))

        // then
        XCTAssertEqual(event, .labelJump(typedLabel: "S", matched: true, to: 1))
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 1)
        XCTAssertEqual(
            presenter.statusUpdates.last,
            OverlayInteractionStatus(focusedLabel: "S", message: "Focused", tone: .success)
        )
    }

    func test_handleKeyboardCommand_없는_label은_실패피드백을_표시() {
        // given
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(presenter: presenter)

        // when
        let event = sut.handleKeyboardCommand(.typeLabel("J"))

        // then
        XCTAssertEqual(event, .labelJump(typedLabel: "J", matched: false, to: nil))
        XCTAssertEqual(
            presenter.statusUpdates.last,
            OverlayInteractionStatus(focusedLabel: "A", message: "No label J", tone: .failure)
        )
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

    func test_handleKeyboardCommand_appendQuery는_queryInput과_status를_갱신한다() {
        // given
        let presenter = StubOverlayPresenter()
        let candidate = makeCandidate(
            title: "Delete",
            frame: CGRect(x: 120, y: 140, width: 40, height: 20)
        )
        let sut = makeStartedSessionController(
            presenter: presenter,
            candidates: [candidate],
            searchableNodeCollector: StubSearchableNodeCollector(
                index: ElementSearchIndex(nodes: [
                    SearchableNode(
                        id: 0,
                        role: AccessibilityRole.button,
                        title: "Delete",
                        frame: candidate.frame
                    )
                ])
            )
        )

        // when
        _ = sut.handleKeyboardCommand(.appendQuery("delete"))

        // then
        XCTAssertEqual(sut.activeSession?.queryInput.buffer, "delete")
        XCTAssertEqual(
            presenter.statusUpdates.last,
            OverlayInteractionStatus(
                focusedLabel: "A",
                queryBuffer: "delete",
                activeScope: .elements,
                matchCount: 1,
                matchIndex: 1,
                focusedDisplayName: "Delete",
                enterActionHint: AppContent.localized(for: .english).enterActionClick,
                tone: .neutral
            )
        )
    }

    func test_handleKeyboardCommand_deleteQueryCharacter는_queryBuffer_마지막글자를_삭제한다() {
        // given
        let sut = makeStartedSessionController()
        _ = sut.handleKeyboardCommand(.appendQuery("d"))
        _ = sut.handleKeyboardCommand(.appendQuery("e"))

        // when
        _ = sut.handleKeyboardCommand(.deleteQueryCharacter)

        // then
        XCTAssertEqual(sut.activeSession?.queryInput.buffer, "d")
    }

    func test_handleKeyboardCommand_clearQueryBuffer는_pin까지_초기화한다() {
        // given
        let sut = makeStartedSessionController()
        _ = sut.handleKeyboardCommand(.pinScope(.windows))
        _ = sut.handleKeyboardCommand(.appendQuery("s"))

        // when
        _ = sut.handleKeyboardCommand(.clearQueryBuffer)

        // then
        XCTAssertEqual(sut.activeSession?.queryInput.buffer, "")
        XCTAssertNil(sut.activeSession?.queryInput.pinnedScope)
    }

    func test_handleKeyboardCommand_pinScope는_buffer없이_scope만_고정한다() {
        // given
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(presenter: presenter)

        // when
        _ = sut.handleKeyboardCommand(.pinScope(.windows))

        // then
        XCTAssertEqual(sut.activeSession?.queryInput.pinnedScope, .windows)
        XCTAssertEqual(presenter.statusUpdates.last?.pinnedScope, .windows)
    }

    func test_handleKeyboardCommand_appendQuery는_promotion된_candidate로_focus를_동기화한다() {
        // given
        let deleteCandidate = makeCandidate(
            title: "Delete",
            frame: CGRect(x: 120, y: 140, width: 40, height: 20)
        )
        let openCandidate = makeCandidate(
            title: "Open",
            frame: CGRect(x: 220, y: 180, width: 44, height: 24)
        )
        let sut = makeStartedSessionController(
            candidates: [openCandidate, deleteCandidate],
            searchableNodeCollector: StubSearchableNodeCollector(
                index: ElementSearchIndex(nodes: [
                    SearchableNode(
                        id: 10,
                        role: AccessibilityRole.button,
                        title: "Delete",
                        frame: deleteCandidate.frame
                    )
                ])
            )
        )

        // when
        _ = sut.handleKeyboardCommand(.appendQuery("delete"))

        // then
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 1)
    }

    func test_handleKeyboardCommand_cycleMatch는_elementMatch를_순환한다() {
        // given
        let first = makeCandidate(title: "Delete", frame: CGRect(x: 120, y: 140, width: 40, height: 20))
        let second = makeCandidate(title: "Delete Row", frame: CGRect(x: 220, y: 180, width: 44, height: 24))
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            candidates: [first, second],
            searchableNodeCollector: StubSearchableNodeCollector(
                index: ElementSearchIndex(nodes: [
                    SearchableNode(id: 0, role: AccessibilityRole.button, title: "Delete", frame: first.frame),
                    SearchableNode(id: 1, role: AccessibilityRole.button, title: "Delete Row", frame: second.frame)
                ])
            )
        )
        _ = sut.handleKeyboardCommand(.appendQuery("delete"))

        // when
        _ = sut.handleKeyboardCommand(.cycleMatch(forward: true))

        // then
        XCTAssertEqual(sut.activeSession?.elementMatchIndex, 1)
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 1)
        XCTAssertEqual(presenter.statusUpdates.last?.matchIndex, 2)
    }

    func test_handleKeyboardCommand_queryMatch가_없으면_return은_noFocusedTarget_failure를_표시한다() {
        // given
        let presenter = StubOverlayPresenter()
        let clickExecutor = StubOverlayClickExecutor(
            result: .success(
                ClickExecutionSuccess(method: .axPress, riskClass: .safeNavigation, fallbackUsed: false)
            )
        )
        let sut = makeStartedSessionController(
            presenter: presenter,
            clickExecutor: clickExecutor,
            searchableNodeCollector: StubSearchableNodeCollector(index: ElementSearchIndex(nodes: []))
        )
        _ = sut.handleKeyboardCommand(.appendQuery("missing"))

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(sut.lastClickResult, .failure(.missingFocusedTarget(index: -1)))
        XCTAssertTrue(clickExecutor.requests.isEmpty)
        XCTAssertEqual(presenter.statusUpdates.last?.tone, .failure)
    }

    func test_handleKeyboardCommand_windowsScope_return은_windowActivator를_호출하고_rescan한다() {
        // given
        let entry = makeWindowEntry(id: 0, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap")
        let windowActivator = StubWindowActivator(result: .success(()))
        let scanner = StubOverlayScanner(
            results: [
                .success(makeScanResult(candidates: [makeCandidate(title: "Open")])),
                .success(makeScanResult(candidates: [makeCandidate(title: "Reload")]))
            ]
        )
        let presenter = StubOverlayPresenter()
        let sut = makeSessionController(
            scanner: scanner,
            clickExecutor: StubOverlayClickExecutor(result: .failure(.missingFocusedTarget(index: 0))),
            presenter: presenter,
            windowSearchIndexProvider: { WindowSearchIndex(entries: [entry]) },
            windowActivator: windowActivator
        )
        _ = sut.start()
        _ = sut.handleKeyboardCommand(.pinScope(.windows))
        _ = sut.handleKeyboardCommand(.appendQuery("slack"))

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(windowActivator.activatedEntries, [entry])
        XCTAssertEqual(scanner.scanCallCount, 2)
        XCTAssertEqual(scanner.invalidateCallCount, 1)
        XCTAssertEqual(presenter.showRequests.count, 2)
        XCTAssertEqual(sut.activeSession?.queryInput.lastScope, .elements)
        XCTAssertEqual(presenter.statusUpdates.last?.tone, .success)
    }

    func test_handleKeyboardCommand_windowsScope_activate실패는_failure_status를_표시한다() {
        // given
        let entry = makeWindowEntry(id: 0, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap")
        let windowActivator = StubWindowActivator(result: .failure(.frontmostTimeout))
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            windowSearchIndexProvider: { WindowSearchIndex(entries: [entry]) },
            windowActivator: windowActivator
        )
        _ = sut.handleKeyboardCommand(.pinScope(.windows))
        _ = sut.handleKeyboardCommand(.appendQuery("slack"))

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(windowActivator.activatedEntries, [entry])
        XCTAssertEqual(presenter.statusUpdates.last?.tone, .failure)
        XCTAssertEqual(presenter.statusUpdates.last?.activeScope, .windows)
    }

    func test_handleKeyboardCommand_windowsScope_cycleMatch는_windowMatchIndex를_순환한다() {
        // given
        let first = makeWindowEntry(id: 0, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap", title: "Alpha")
        let second = makeWindowEntry(id: 1, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap", title: "Beta")
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            windowSearchIndexProvider: { WindowSearchIndex(entries: [first, second]) }
        )
        _ = sut.handleKeyboardCommand(.pinScope(.windows))
        _ = sut.handleKeyboardCommand(.appendQuery("slack"))

        // when
        _ = sut.handleKeyboardCommand(.cycleMatch(forward: true))

        // then
        XCTAssertEqual(sut.activeSession?.windowMatchIndex, 1)
        XCTAssertEqual(presenter.statusUpdates.last?.matchIndex, 2)
        XCTAssertEqual(presenter.statusUpdates.last?.focusedDisplayName, "Slack — Beta")
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

    func test_handleKeyboardCommand_dryRunConfirm_focus가없으면_failure_status를_표시한다() {
        // given
        let emptyLayout = OverlayLayout(
            targetFrame: CGRect(x: 100, y: 100, width: 400, height: 300),
            localBounds: CGRect(x: 0, y: 0, width: 400, height: 300),
            labels: [],
            metrics: OverlayLayoutMetrics(
                labelCount: 0,
                collisionCount: 0,
                occlusionCount: 0,
                displayScaleFactor: 1
            ),
            displayInfo: OverlayDisplayInfo(scaleFactor: 1, visibleFrame: nil)
        )
        let presenter = StubOverlayPresenter(forcedLayout: emptyLayout)
        let clickExecutor = StubOverlayClickExecutor(
            result: .success(
                ClickExecutionSuccess(
                    method: .axPress,
                    riskClass: .safeNavigation,
                    fallbackUsed: false
                )
            )
        )
        var observedResults: [Result<ClickExecutionSuccess, OverlaySessionClickFailure>] = []
        let sut = makeStartedSessionController(
            presenter: presenter,
            clickExecutor: clickExecutor,
            clickResultObserver: { result in
                observedResults.append(result)
            }
        )

        // when
        let event = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(event, .dryRunConfirm(index: nil))
        XCTAssertEqual(sut.lastClickResult, .failure(.missingFocusedTarget(index: -1)))
        XCTAssertTrue(clickExecutor.requests.isEmpty)
        XCTAssertEqual(observedResults, [.failure(.missingFocusedTarget(index: -1))])
        XCTAssertEqual(
            presenter.statusUpdates.last,
            OverlayInteractionStatus(
                message: "Click failed: no focused target. Type a label or press Tab first.",
                tone: .failure
            )
        )
        XCTAssertNotNil(sut.activeSession)
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

    func test_handleKeyboardCommand_click성공은_attempt와_completed를_기록() {
        // given
        let recorder = StubInteractionRecorder()
        let timestamp = Date(timeIntervalSince1970: 30)
        let hasher = WindowTitleHasher(salt: SessionSalt(value: "test-salt"))
        let clickExecutor = StubOverlayClickExecutor(
            result: .success(
                ClickExecutionSuccess(
                    method: .axPress,
                    riskClass: .safeNavigation,
                    fallbackUsed: false
                )
            )
        )
        let sut = makeStartedSessionController(
            recorder: recorder,
            clickExecutor: clickExecutor,
            windowTitleHasher: hasher,
            dateProvider: { timestamp }
        )

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(
            recorder.events,
            [
                InteractionEvent(
                    timestamp: timestamp,
                    kind: .clickAttempt(risk: "safeNavigation"),
                    windowTitleHash: hasher.hash("Finder")
                ),
                InteractionEvent(
                    timestamp: timestamp,
                    kind: .clickCompleted(risk: "safeNavigation", success: true),
                    windowTitleHash: hasher.hash("Finder")
                )
            ]
        )
    }

    func test_handleKeyboardCommand_click결과를_observer에_전달한다() {
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
        var observedResults: [Result<ClickExecutionSuccess, OverlaySessionClickFailure>] = []
        let sut = makeStartedSessionController(
            clickExecutor: clickExecutor,
            clickResultObserver: { result in
                observedResults.append(result)
            }
        )

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(observedResults, [clickExecutor.result])
    }

    func test_clickLabel_label로_focus후_confirm을_실행한다() {
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

        // when
        let result = sut.clickLabel("S")

        // then
        XCTAssertEqual(result, .some(clickExecutor.result))
        XCTAssertEqual(clickExecutor.requests.map(\.focusedIndex), [1])
        XCTAssertEqual(presenter.focusUpdates, [0, 1, 1])
        XCTAssertEqual(
            presenter.statusUpdates.last,
            OverlayInteractionStatus(focusedLabel: "S", message: "Clicked", tone: .success)
        )
        XCTAssertNil(sut.activeSession)
    }

    func test_clickLabel_label이없으면_clickExecutor를_호출하지_않고_failure를_반환한다() {
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
        var observedResults: [Result<ClickExecutionSuccess, OverlaySessionClickFailure>] = []
        let sut = makeStartedSessionController(
            clickExecutor: clickExecutor,
            clickResultObserver: { result in
                observedResults.append(result)
            }
        )

        // when
        let result = sut.clickLabel("Z")

        // then
        XCTAssertEqual(result, .some(.failure(.missingFocusedTarget(index: -1))))
        XCTAssertTrue(clickExecutor.requests.isEmpty)
        XCTAssertEqual(observedResults, [.failure(.missingFocusedTarget(index: -1))])
        XCTAssertNotNil(sut.activeSession)
    }

    func test_clickLabel_클릭성공시_scanner_cache를_무효화한다() {
        // given
        let scanner = makeTwoCandidateScanner()
        let clickExecutor = StubOverlayClickExecutor(
            result: .success(
                ClickExecutionSuccess(
                    method: .axPress,
                    riskClass: .safeNavigation,
                    fallbackUsed: false
                )
            )
        )
        let sut = makeSessionController(scanner: scanner, clickExecutor: clickExecutor)
        _ = sut.start()

        // when
        _ = sut.clickLabel("S")

        // then
        XCTAssertEqual(scanner.invalidateCallCount, 1)
    }

    func test_clickLabel_클릭실패시_scanner_cache를_무효화하지_않는다() {
        // given
        let scanner = makeTwoCandidateScanner()
        let clickExecutor = StubOverlayClickExecutor(
            result: .failure(.executionFailed(.axPressFailed(reason: "test")))
        )
        let sut = makeSessionController(scanner: scanner, clickExecutor: clickExecutor)
        _ = sut.start()

        // when
        _ = sut.clickLabel("S")

        // then
        XCTAssertEqual(scanner.invalidateCallCount, 0)
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
        XCTAssertEqual(
            presenter.statusUpdates.last,
            OverlayInteractionStatus(
                focusedLabel: "A",
                message: "Click failed: no supported action. Try another label.",
                tone: .failure
            )
        )
    }

    func test_handleKeyboardCommand_click실패는_attempt와_completed_false를_기록() {
        // given
        let recorder = StubInteractionRecorder()
        let clickExecutor = StubOverlayClickExecutor(
            result: .failure(.executionFailed(.missingPressAction))
        )
        let sut = makeStartedSessionController(
            recorder: recorder,
            clickExecutor: clickExecutor
        )

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(
            recorder.events.map(\.kind),
            [
                .clickAttempt(risk: "unknownRisk"),
                .clickCompleted(risk: "unknownRisk", success: false)
            ]
        )
    }

    func test_handleKeyboardCommand_위험click은_secondConfirm을_대기하고_두번째_confirm에서_실행() {
        // given
        let recorder = StubInteractionRecorder()
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
            recorder: recorder,
            clickExecutor: clickExecutor
        )

        // when
        let firstEvent = sut.handleKeyboardCommand(.dryRunConfirm)
        let secondEvent = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(firstEvent, .dryRunConfirm(index: 0))
        XCTAssertEqual(secondEvent, .dryRunConfirm(index: 0))
        XCTAssertEqual(clickExecutor.requests.map(\.isSecondConfirmProvided), [false, true])
        XCTAssertEqual(
            recorder.events.map(\.kind),
            [
                .clickAttempt(risk: "destructive"),
                .clickAttempt(risk: "destructive"),
                .clickCompleted(risk: "destructive", success: true)
            ]
        )
        XCTAssertEqual(sut.activeSession, nil)
        XCTAssertEqual(presenter.closeCallCount, 1)
    }

    func test_handleKeyboardCommand_focus가_바뀌면_secondConfirm대기를_초기화() {
        // given
        let timestamp = Date(timeIntervalSince1970: 100)
        let clickExecutor = StubOverlayClickExecutor(
            results: [
                .failure(.executionFailed(.secondConfirmRequired(riskClass: .destructive))),
                .failure(.executionFailed(.secondConfirmRequired(riskClass: .destructive)))
            ]
        )
        let sut = makeStartedSessionController(
            clickExecutor: clickExecutor,
            dateProvider: { timestamp }
        )
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // when
        _ = sut.handleKeyboardCommand(.move(.next))
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(clickExecutor.requests.map(\.focusedIndex), [0, 1])
        XCTAssertEqual(clickExecutor.requests.map(\.isSecondConfirmProvided), [false, false])
        XCTAssertEqual(
            sut.activeSession?.pendingSecondConfirm,
            PendingSecondConfirm(focusedItemID: 1, riskClass: .destructive, createdAt: timestamp)
        )
    }

    func test_handleKeyboardCommand_secondConfirm이_만료되면_다시_확인을_요구한다() {
        // given
        var currentDate = Date(timeIntervalSince1970: 200)
        let clickExecutor = StubOverlayClickExecutor(
            results: [
                .failure(.executionFailed(.secondConfirmRequired(riskClass: .destructive))),
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
        let sut = makeStartedSessionController(
            clickExecutor: clickExecutor,
            dateProvider: { currentDate }
        )
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // when
        currentDate = Date(timeIntervalSince1970: 204)
        _ = sut.handleKeyboardCommand(.dryRunConfirm)
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(clickExecutor.requests.map(\.isSecondConfirmProvided), [false, false, true])
        XCTAssertEqual(sut.activeSession, nil)
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
        _ = sut.handleKeyboardCommand(.typeLabel("S"))

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

    func test_focusNearestLabel_gazePoint로_overlayFocus를_갱신하고_기록() {
        // given
        let presenter = StubOverlayPresenter()
        let recorder = StubInteractionRecorder()
        let timestamp = Date(timeIntervalSince1970: 40)
        let hasher = WindowTitleHasher(salt: SessionSalt(value: "test-salt"))
        let sut = makeStartedSessionController(
            presenter: presenter,
            recorder: recorder,
            windowTitleHasher: hasher,
            dateProvider: { timestamp }
        )

        // when
        let event = sut.focusNearestLabel(to: CGPoint(x: 225, y: 185))

        // then
        XCTAssertEqual(event, .focusChanged(from: 0, to: 1, method: .gaze))
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 1)
        XCTAssertEqual(presenter.focusUpdates, [0, 1])
        XCTAssertEqual(
            recorder.events,
            [
                InteractionEvent(
                    timestamp: timestamp,
                    kind: .focusChanged(method: "gaze"),
                    windowTitleHash: hasher.hash("Finder")
                )
            ]
        )
    }

    func test_focusNearestLabel_elements_scope에서_겨냥한_요소이름과_index를_status에_반영한다() {
        // given
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            candidates: [
                makeCandidate(title: "Open", frame: CGRect(x: 120, y: 140, width: 40, height: 20)),
                makeCandidate(title: "Save Draft", frame: CGRect(x: 220, y: 180, width: 44, height: 24))
            ]
        )
        _ = sut.handleKeyboardCommand(.pinScope(.elements))

        // when
        let event = sut.focusNearestLabel(to: CGPoint(x: 225, y: 185))

        // then
        XCTAssertEqual(event, .focusChanged(from: 0, to: 1, method: .gaze))
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 1)
        let status = presenter.statusUpdates.last
        XCTAssertEqual(status?.activeScope, .elements)
        XCTAssertEqual(status?.focusedDisplayName, "Save Draft")
        XCTAssertEqual(status?.matchCount, 1)
        XCTAssertEqual(status?.matchIndex, 1)
    }

    func test_focusNearestLabel_labels_scope에서는_element맥락을_주입하지_않는다() {
        // given
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            candidates: [
                makeCandidate(title: "Open", frame: CGRect(x: 120, y: 140, width: 40, height: 20)),
                makeCandidate(title: "Save Draft", frame: CGRect(x: 220, y: 180, width: 44, height: 24))
            ]
        )

        // when
        _ = sut.focusNearestLabel(to: CGPoint(x: 225, y: 185))

        // then
        let status = presenter.statusUpdates.last
        XCTAssertEqual(status?.activeScope, .labels)
        XCTAssertNil(status?.focusedDisplayName)
        XCTAssertEqual(status?.matchCount, 0)
        XCTAssertNotNil(status?.focusedLabel)
    }

    func test_focusNearestLabel_windows_scope에서는_element맥락을_주입하지_않는다() {
        // given
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            candidates: [
                makeCandidate(title: "Open", frame: CGRect(x: 120, y: 140, width: 40, height: 20)),
                makeCandidate(title: "Save Draft", frame: CGRect(x: 220, y: 180, width: 44, height: 24))
            ]
        )
        _ = sut.handleKeyboardCommand(.pinScope(.windows))

        // when
        _ = sut.focusNearestLabel(to: CGPoint(x: 225, y: 185))

        // then
        let status = presenter.statusUpdates.last
        XCTAssertEqual(status?.activeScope, .windows)
        XCTAssertNil(status?.focusedDisplayName)
        XCTAssertEqual(status?.matchCount, 0)
    }

    func test_focusNearestLabel_elements_scope에서_title이_없으면_role을_이름으로_쓴다() {
        // given
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            candidates: [
                makeCandidate(title: "Open", frame: CGRect(x: 120, y: 140, width: 40, height: 20)),
                ClickableCandidate(
                    role: AccessibilityRole.link,
                    subrole: nil,
                    title: nil,
                    frame: CGRect(x: 220, y: 180, width: 44, height: 24),
                    actions: [AccessibilityAction.press]
                )
            ]
        )
        _ = sut.handleKeyboardCommand(.pinScope(.elements))

        // when
        _ = sut.focusNearestLabel(to: CGPoint(x: 225, y: 185))

        // then
        let status = presenter.statusUpdates.last
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 1)
        XCTAssertEqual(status?.focusedDisplayName, AccessibilityRole.link)
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
        candidates: [ClickableCandidate]? = nil,
        searchableNodeCollector: (any SearchableNodeCollecting)? = nil,
        windowSearchIndexProvider: @escaping () -> WindowSearchIndex = { WindowSearchIndex(entries: []) },
        windowActivator: any WindowActivating = StubWindowActivator(result: .failure(.appNotRunning)),
        windowTitleHasher: WindowTitleHasher = WindowTitleHasher(salt: SessionSalt(value: "default-test-salt")),
        dateProvider: @escaping () -> Date = Date.init,
        clickResultObserver: @escaping @MainActor (Result<ClickExecutionSuccess, OverlaySessionClickFailure>) -> Void = { _ in }
    ) -> OverlaySessionController {
        let context = makeContext()
        let resolver = StubOverlayTargetResolver(result: .success(context))
        let scanner = StubOverlayScanner(
            result: .success(
                makeScanResult(
                    candidates: candidates ?? [
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
            searchableNodeCollector: searchableNodeCollector,
            windowSearchIndexProvider: windowSearchIndexProvider,
            windowActivator: windowActivator,
            windowTitleHasher: windowTitleHasher,
            dateProvider: dateProvider,
            clickResultObserver: clickResultObserver
        )
        _ = sut.start()
        return sut
    }

    private func makeTwoCandidateScanner() -> StubOverlayScanner {
        StubOverlayScanner(
            result: .success(
                makeScanResult(
                    candidates: [
                        makeCandidate(frame: CGRect(x: 120, y: 140, width: 40, height: 20)),
                        makeCandidate(frame: CGRect(x: 220, y: 180, width: 44, height: 24))
                    ]
                )
            )
        )
    }

    private func makeSessionController(
        scanner: StubOverlayScanner,
        clickExecutor: StubOverlayClickExecutor,
        presenter: StubOverlayPresenter = StubOverlayPresenter(),
        windowSearchIndexProvider: @escaping () -> WindowSearchIndex = { WindowSearchIndex(entries: []) },
        windowActivator: any WindowActivating = StubWindowActivator(result: .failure(.appNotRunning))
    ) -> OverlaySessionController {
        OverlaySessionController(
            targetResolver: StubOverlayTargetResolver(result: .success(makeContext())),
            scanner: scanner,
            overlayPresenter: presenter,
            interactionRecorder: StubInteractionRecorder(),
            clickExecutor: clickExecutor,
            searchableNodeCollector: nil,
            windowSearchIndexProvider: windowSearchIndexProvider,
            windowActivator: windowActivator,
            windowTitleHasher: WindowTitleHasher(salt: SessionSalt(value: "default-test-salt"))
        )
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
        title: String = "Open",
        frame: CGRect = CGRect(x: 120, y: 140, width: 40, height: 20)
    ) -> ClickableCandidate {
        ClickableCandidate(
            role: AccessibilityRole.button,
            subrole: nil,
            title: title,
            frame: frame,
            actions: [AccessibilityAction.press]
        )
    }

    private func makeWindowEntry(
        id: Int,
        appName: String,
        bundleID: String,
        title: String? = nil
    ) -> WindowEntry {
        WindowEntry(
            id: id,
            appName: appName,
            bundleID: bundleID,
            windowTitle: title,
            windowTitleHash: title.map { "hash-\($0)" },
            pid: pid_t(id + 100),
            axWindow: nil,
            appIcon: nil
        )
    }
}

@MainActor
private struct StubSearchableNodeCollector: SearchableNodeCollecting {
    let index: ElementSearchIndex

    func buildIndex(context: TargetContext) -> ElementSearchIndex {
        index
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
    private let results: [Result<AccessibilityScanResult, AccessibilityScanFailure>]
    private(set) var scanCallCount = 0
    private(set) var invalidateCallCount = 0
    private(set) var receivedContext: TargetContext?

    init(result: Result<AccessibilityScanResult, AccessibilityScanFailure>) {
        self.results = [result]
    }

    init(results: [Result<AccessibilityScanResult, AccessibilityScanFailure>]) {
        self.results = results
    }

    func scan(context: TargetContext) -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        scanCallCount += 1
        receivedContext = context
        return results[min(scanCallCount - 1, results.count - 1)]
    }

    func invalidate() {
        invalidateCallCount += 1
    }
}

@MainActor
private final class StubOverlayPresenter: OverlaySessionPresenting {
    private let forcedLayout: OverlayLayout?
    private(set) var showRequests: [ShowRequest] = []
    private(set) var closeCallCount = 0
    private(set) var keyboardCommandHandler: ((FocusKeyboardCommand) -> Void)?
    private(set) var focusUpdates: [Int?] = []
    private(set) var statusUpdates: [OverlayInteractionStatus] = []
    private var lastLayout: OverlayLayout?

    init(forcedLayout: OverlayLayout? = nil) {
        self.forcedLayout = forcedLayout
    }

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

        if let forcedLayout {
            lastLayout = forcedLayout
            return forcedLayout
        }

        let layout = OverlayLayoutEngine().makeLayout(
            targetFrame: targetFrame,
            candidates: candidates,
            labels: labels
        )
        lastLayout = layout
        return layout
    }

    func close() {
        closeCallCount += 1
    }

    func updateFocus(focusedLabelID: Int?) {
        focusUpdates.append(focusedLabelID)
    }

    func updateStatus(_ status: OverlayInteractionStatus) {
        statusUpdates.append(status)
        focusUpdates.append(focusedLabelID(for: status.focusedLabel))
    }

    private func focusedLabelID(for label: String?) -> Int? {
        guard let label else {
            return nil
        }

        return lastLayout?.labels.first { $0.text == label }?.id
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

@MainActor
private final class StubWindowActivator: WindowActivating {
    private let result: Result<Void, WindowActivateFailure>
    private(set) var activatedEntries: [WindowEntry] = []

    init(result: Result<Void, WindowActivateFailure>) {
        self.result = result
    }

    func activate(_ entry: WindowEntry) -> Result<Void, WindowActivateFailure> {
        activatedEntries.append(entry)
        return result
    }
}
