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

    func test_sessionState는_기본적으로_scan완료상태다() {
        // given
        let layout = StubOverlayPresenter().makeLayout(
            targetFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            candidates: [],
            labels: []
        )
        let snapshot = OverlaySessionSnapshot(
            context: makeContext(),
            scanResult: makeScanResult(candidates: []),
            layout: layout
        )

        // when
        let sut = OverlaySessionState(snapshot: snapshot, focusEngine: FocusEngine(layout: layout))

        // then
        XCTAssertFalse(sut.isScanInProgress)
    }

    func test_startProgressively는_부분후보를잠금상태로표시하고_완료후최종레이아웃으로교체한다() async {
        // given
        let context = makeContext()
        let firstCandidate = makeCandidate(title: "First")
        let finalCandidates = [firstCandidate, makeCandidate(title: "Second", frame: CGRect(x: 260, y: 180, width: 44, height: 24))]
        let scanner = SuspendingProgressiveOverlayScanner(
            progress: AccessibilityScanProgress(candidates: [firstCandidate], nodesVisited: 12)
        )
        let presenter = StubOverlayPresenter()
        let sut = OverlaySessionController(
            targetResolver: StubOverlayTargetResolver(result: .success(context)),
            scanner: scanner,
            overlayPresenter: presenter
        )
        var completedResult: OverlaySessionStartResult?

        // when
        sut.startProgressively { result in
            completedResult = result
        }
        await waitForProgressiveScan()

        // then - partial
        XCTAssertEqual(presenter.showRequests.map(\.candidates), [[firstCandidate]])
        XCTAssertTrue(sut.activeSession?.isScanInProgress == true)
        XCTAssertNil(sut.handleKeyboardCommand(.move(.next)))
        XCTAssertNil(sut.clickLabel("A"))
        XCTAssertNil(sut.focusNearestLabel(to: CGPoint(x: 100, y: 100)))
        XCTAssertNil(completedResult)

        // when - final
        scanner.complete(with: .success(makeScanResult(candidates: finalCandidates)))
        await waitForProgressiveScan()

        // then - final
        XCTAssertEqual(presenter.showRequests.map(\.candidates), [[firstCandidate], finalCandidates])
        XCTAssertFalse(sut.activeSession?.isScanInProgress == true)
        guard case .success(let snapshot) = completedResult else {
            XCTFail("Expected final success, got \(String(describing: completedResult)).")
            return
        }
        XCTAssertEqual(snapshot.scanResult.candidates, finalCandidates)
    }

    func test_startProgressively는_close후_늦은최종결과를무시한다() async {
        // given
        let firstCandidate = makeCandidate(title: "First")
        let scanner = SuspendingProgressiveOverlayScanner(
            progress: AccessibilityScanProgress(candidates: [firstCandidate], nodesVisited: 8)
        )
        let presenter = StubOverlayPresenter()
        let sut = OverlaySessionController(
            targetResolver: StubOverlayTargetResolver(result: .success(makeContext())),
            scanner: scanner,
            overlayPresenter: presenter
        )
        var didComplete = false
        sut.startProgressively { _ in
            didComplete = true
        }
        await waitForProgressiveScan()

        // when
        sut.close()
        scanner.complete(with: .success(makeScanResult(candidates: [firstCandidate, makeCandidate(title: "Late")])))
        await waitForProgressiveScan()

        // then
        XCTAssertEqual(presenter.showRequests.count, 1)
        XCTAssertNil(sut.activeSession)
        XCTAssertFalse(didComplete)
        XCTAssertTrue(scanner.wasCancelled)
    }

    func test_startProgressively는_scan중_sessionDisable후_close하면_늦은최종결과를무시한다() async {
        // given
        let firstCandidate = makeCandidate(title: "First")
        let scanner = SuspendingProgressiveOverlayScanner(
            progress: AccessibilityScanProgress(candidates: [firstCandidate], nodesVisited: 8)
        )
        let presenter = StubOverlayPresenter()
        let sessionController = SessionController()
        let sut = OverlaySessionController(
            targetResolver: StubOverlayTargetResolver(result: .success(makeContext())),
            scanner: scanner,
            overlayPresenter: presenter,
            isSessionEnabled: { sessionController.isEnabled }
        )
        var didComplete = false
        sut.startProgressively { _ in
            didComplete = true
        }
        await waitForProgressiveScan()
        XCTAssertEqual(presenter.showRequests.map(\.candidates), [[firstCandidate]])

        // when
        sessionController.disable()
        sut.close()
        scanner.complete(
            with: .success(
                makeScanResult(candidates: [firstCandidate, makeCandidate(title: "Late")])
            )
        )
        await waitForProgressiveScan()

        // then
        XCTAssertEqual(presenter.showRequests.map(\.candidates), [[firstCandidate]])
        XCTAssertEqual(presenter.closeCallCount, 1)
        XCTAssertNil(sut.activeSession)
        XCTAssertFalse(didComplete)
        XCTAssertTrue(scanner.wasCancelled)
    }

    func test_startProgressively는_새activation후_이전activation의늦은결과를무시한다() async {
        // given
        let firstPartialCandidate = makeCandidate(title: "First Partial")
        let secondPartialCandidate = makeCandidate(title: "Second Partial")
        let secondFinalCandidate = makeCandidate(title: "Second Final")
        let scanner = SequencedSuspendingProgressiveOverlayScanner(
            progresses: [
                AccessibilityScanProgress(candidates: [firstPartialCandidate], nodesVisited: 4),
                AccessibilityScanProgress(candidates: [secondPartialCandidate], nodesVisited: 6)
            ]
        )
        let presenter = StubOverlayPresenter()
        let sut = OverlaySessionController(
            targetResolver: StubOverlayTargetResolver(
                results: [.success(makeContext()), .success(makeContext())]
            ),
            scanner: scanner,
            overlayPresenter: presenter
        )
        var didCompleteFirstActivation = false
        var secondActivationResult: OverlaySessionStartResult?

        // when - first activation
        sut.startProgressively { _ in
            didCompleteFirstActivation = true
        }
        await waitForProgressiveScan()

        // when - second activation
        sut.startProgressively { result in
            secondActivationResult = result
        }
        await waitForProgressiveScan()
        scanner.complete(
            requestAt: 1,
            with: .success(makeScanResult(candidates: [secondFinalCandidate]))
        )
        await waitForProgressiveScan()

        // when - stale first activation
        scanner.complete(
            requestAt: 0,
            with: .success(makeScanResult(candidates: [makeCandidate(title: "Late First")]))
        )
        await waitForProgressiveScan()

        // then
        XCTAssertEqual(
            presenter.showRequests.map(\.candidates),
            [[firstPartialCandidate], [secondPartialCandidate], [secondFinalCandidate]]
        )
        XCTAssertEqual(sut.activeSession?.snapshot.scanResult.candidates, [secondFinalCandidate])
        XCTAssertFalse(didCompleteFirstActivation)
        guard case .success(let snapshot) = secondActivationResult else {
            XCTFail("Expected second activation success, got \(String(describing: secondActivationResult)).")
            return
        }
        XCTAssertEqual(snapshot.scanResult.candidates, [secondFinalCandidate])
        XCTAssertEqual(scanner.cancelledRequestIndices, [0])
    }

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
        XCTAssertEqual(presenter.statusUpdates.last?.hasExplicitFocus, false)

        let request = try XCTUnwrap(presenter.showRequests.first)
        XCTAssertEqual(request.targetFrame, context.window.frame)
        XCTAssertEqual(request.candidates, candidates)
    }

    func test_start_성공은_activationPhase를_순서대로_기록한다() {
        // given
        let tracer = SpyOverlayActivationTracer()
        let dates = [
            Date(timeIntervalSince1970: 1_000),
            Date(timeIntervalSince1970: 1_000.01),
            Date(timeIntervalSince1970: 1_000.03),
            Date(timeIntervalSince1970: 1_000.04),
            Date(timeIntervalSince1970: 1_000.05)
        ]
        var nextDateIndex = 0
        let sut = OverlaySessionController(
            targetResolver: StubOverlayTargetResolver(result: .success(makeContext())),
            scanner: StubOverlayScanner(result: .success(makeScanResult(candidates: [makeCandidate()]))),
            overlayPresenter: StubOverlayPresenter(),
            dateProvider: {
                defer { nextDateIndex += 1 }
                return dates[min(nextDateIndex, dates.count - 1)]
            },
            activationTracer: tracer
        )

        // when
        _ = sut.start()

        // then
        XCTAssertEqual(
            tracer.phases,
            [
                .shortcutReceived,
                .targetResolved,
                .scanCompleted,
                .layoutCompleted,
                .sessionReady,
                .captureReady,
                .panelsOrdered,
                .firstDisplayPass
            ]
        )
        XCTAssertEqual(tracer.metadata(for: .scanCompleted)?.nodesVisited, 2)
        XCTAssertEqual(tracer.metadata(for: .scanCompleted)?.candidateCount, 1)
        XCTAssertEqual(tracer.metadata(for: .sessionReady)?.hasActiveSession, true)
    }

    func test_start_성공은_session을_준비한뒤_presenterShow를_호출한다() {
        // given
        let presenter = StubOverlayPresenter()
        let sut = OverlaySessionController(
            targetResolver: StubOverlayTargetResolver(result: .success(makeContext())),
            scanner: StubOverlayScanner(result: .success(makeScanResult(candidates: [makeCandidate()]))),
            overlayPresenter: presenter
        )
        var sessionWasReadyWhenShown = false
        presenter.onShow = {
            sessionWasReadyWhenShown = sut.activeSession != nil
        }

        // when
        _ = sut.start()

        // then
        XCTAssertTrue(sessionWasReadyWhenShown)
    }

    func test_start_labelOnly경로는_searchable과_windowIndex를_생성하지않는다() {
        // given
        let searchableNodeCollector = SpySearchableNodeCollector(index: ElementSearchIndex(nodes: []))
        var windowIndexBuildCount = 0
        let sut = OverlaySessionController(
            targetResolver: StubOverlayTargetResolver(result: .success(makeContext())),
            scanner: StubOverlayScanner(result: .success(makeScanResult(candidates: [makeCandidate()]))),
            overlayPresenter: StubOverlayPresenter(),
            searchableNodeCollector: searchableNodeCollector,
            windowSearchIndexProvider: {
                windowIndexBuildCount += 1
                return WindowSearchIndex(entries: [])
            }
        )

        // when
        _ = sut.start()
        _ = sut.handleKeyboardCommand(.typeLabel("A"))

        // then
        XCTAssertEqual(searchableNodeCollector.buildCallCount, 0)
        XCTAssertEqual(windowIndexBuildCount, 0)
    }

    func test_queryScope최초진입에서_해당Index만_한번_생성한다() {
        // given
        let searchableNodeCollector = SpySearchableNodeCollector(index: ElementSearchIndex(nodes: []))
        var windowIndexBuildCount = 0
        let sut = makeStartedSessionController(
            searchableNodeCollector: searchableNodeCollector,
            windowSearchIndexProvider: {
                windowIndexBuildCount += 1
                return WindowSearchIndex(entries: [])
            }
        )

        // when
        _ = sut.handleKeyboardCommand(.pinScope(.elements))
        _ = sut.handleKeyboardCommand(.appendQuery("find"))
        _ = sut.handleKeyboardCommand(.pinScope(.windows))
        _ = sut.handleKeyboardCommand(.appendQuery("code"))

        // then
        XCTAssertEqual(searchableNodeCollector.buildCallCount, 1)
        XCTAssertEqual(windowIndexBuildCount, 1)
    }

    func test_startProgressively_bundleIndex를사용해_elementsQuery의_추가AXwalk를생략한다() async {
        // given
        let candidate = makeCandidate(title: "Open")
        let scanResult = makeScanResult(candidates: [candidate])
        let bundleIndex = ElementSearchIndex(
            nodes: [
                SearchableNode(
                    id: 7,
                    role: AccessibilityRole.button,
                    title: "Deep Setting",
                    frame: candidate.frame
                )
            ]
        )
        let scanner = StubBundleProgressiveOverlayScanner(
            bundle: AccessibilityScanBundle(
                scanResult: scanResult,
                elementIndex: bundleIndex,
                metrics: AccessibilityScanBundleMetrics(inspectionCount: 3, childReadCount: 3)
            )
        )
        let fallbackCollector = SpySearchableNodeCollector(index: ElementSearchIndex(nodes: []))
        let sut = OverlaySessionController(
            targetResolver: StubOverlayTargetResolver(result: .success(makeContext())),
            scanner: scanner,
            overlayPresenter: StubOverlayPresenter(),
            searchableNodeCollector: fallbackCollector
        )

        // when
        sut.startProgressively { _ in }
        await waitForProgressiveScan()
        _ = sut.handleKeyboardCommand(.appendQuery("deep"))

        // then
        XCTAssertEqual(sut.activeSession?.elementIndex, bundleIndex)
        XCTAssertEqual(sut.activeSession?.elementMatches.map(\.displayName), ["Deep Setting"])
        XCTAssertEqual(fallbackCollector.buildCallCount, 0)
    }

    func test_startProgressively_confirm은_bundle의_targetDescriptor와cacheMetadata를전달한다() async {
        // given
        let candidate = makeCandidate(title: "Open")
        let descriptor = AccessibilityTargetDescriptor(axPath: [0, 2])
        let scanner = StubBundleProgressiveOverlayScanner(
            bundle: AccessibilityScanBundle(
                scanResult: makeScanResult(candidates: [candidate]),
                elementIndex: ElementSearchIndex(nodes: []),
                metrics: AccessibilityScanBundleMetrics(inspectionCount: 3, childReadCount: 3),
                targetDescriptors: [descriptor],
                generation: AccessibilityTreeGeneration(value: 7),
                isChangeMonitoringActive: true
            )
        )
        let clickExecutor = StubOverlayClickExecutor(
            result: .failure(.executionFailed(.missingPressAction))
        )
        let sut = OverlaySessionController(
            targetResolver: StubOverlayTargetResolver(result: .success(makeContext())),
            scanner: scanner,
            overlayPresenter: StubOverlayPresenter(),
            clickExecutor: clickExecutor
        )

        // when
        sut.startProgressively { _ in }
        await waitForProgressiveScan()
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(clickExecutor.requests.first?.selection.targetDescriptor, descriptor)
        XCTAssertEqual(
            clickExecutor.requests.first?.selection.generation,
            AccessibilityTreeGeneration(value: 7)
        )
        XCTAssertEqual(clickExecutor.requests.first?.selection.isChangeMonitoringActive, true)
    }

    func test_queryIndex생성이_빈결과여도_labelFocus를_유지한다() {
        // given
        let sut = makeStartedSessionController(
            searchableNodeCollector: SpySearchableNodeCollector(index: ElementSearchIndex(nodes: []))
        )

        // when
        _ = sut.handleKeyboardCommand(.appendQuery("missing"))
        let event = sut.handleKeyboardCommand(.typeLabel("A"))

        // then
        XCTAssertEqual(event, .labelJump(typedLabel: "A", matched: true, to: 0))
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 0)
    }

    func test_overlayKeyboardCallback은_firstLabelInput을_한번만_처리하고_capture경로를_기록한다() throws {
        // given
        let presenter = StubOverlayPresenter()
        let tracer = SpyOverlayActivationTracer()
        let sut = makeStartedSessionController(presenter: presenter, activationTracer: tracer)

        // when
        try XCTUnwrap(presenter.keyboardCommandHandler)(
            OverlayCapturedKeyboardCommand(command: .typeLabel("A"), captureMode: .eventTap)
        )

        // then
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, 0)
        XCTAssertEqual(tracer.phases.filter { $0 == .keyCaptured }.count, 1)
        XCTAssertEqual(tracer.metadata(for: .keyCaptured)?.captureMode, "event_tap")
    }

    func test_start_scan실패는_scanCompleted이후_phase를_기록하지않는다() {
        // given
        let tracer = SpyOverlayActivationTracer()
        let sut = OverlaySessionController(
            targetResolver: StubOverlayTargetResolver(result: .success(makeContext())),
            scanner: StubOverlayScanner(result: .failure(.childrenUnavailable("temporary"))),
            overlayPresenter: StubOverlayPresenter(),
            activationTracer: tracer
        )

        // when
        _ = sut.start()

        // then
        XCTAssertEqual(tracer.phases, [.shortcutReceived, .targetResolved])
        XCTAssertEqual(tracer.endedActivationCount, 1)
    }

    func test_keyboardCommand은_raw문자없이_commandKind만_기록한다() {
        // given
        let tracer = SpyOverlayActivationTracer()
        let sut = makeStartedSessionController(activationTracer: tracer)

        // when
        _ = sut.handleKeyboardCommand(.appendQuery("private-query"))

        // then
        XCTAssertEqual(tracer.metadata(for: .keyCaptured)?.commandKind, "append_query")
        XCTAssertEqual(tracer.metadata(for: .commandHandled)?.commandKind, "append_query")
        XCTAssertFalse(tracer.serializedMetadata.contains("private-query"))
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
        XCTAssertEqual(presenter.statusUpdates.last?.hasExplicitFocus, true)
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
            OverlayInteractionStatus(
                focusedLabel: "S",
                message: "Focused",
                tone: .success,
                phase: .matching,
                hasExplicitFocus: true
            )
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
            OverlayInteractionStatus(
                focusedLabel: "A",
                message: "No label J",
                tone: .failure,
                phase: .failure
            )
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
                highlightFrame: candidate.frame,
                enterActionHint: AppContent.localized(for: .english).enterActionClick,
                tone: .neutral,
                phase: .matching,
                hasExplicitFocus: true
            )
        )
    }

    func test_handleKeyboardCommand_query결과가없으면_noMatches상태를표시한다() {
        // given
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            searchableNodeCollector: StubSearchableNodeCollector(index: ElementSearchIndex(nodes: []))
        )

        // when
        _ = sut.handleKeyboardCommand(.appendQuery("missing"))

        // then
        XCTAssertEqual(presenter.statusUpdates.last?.phase, .noMatches)
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

    func test_overlayKeyboardCallback은_selectScope_command로_session을_갱신한다() throws {
        // given
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(presenter: presenter)

        // when
        try XCTUnwrap(presenter.keyboardCommandHandler)(
            OverlayCapturedKeyboardCommand(command: .selectScope(.windows), captureMode: .eventTap)
        )

        // then
        XCTAssertEqual(sut.activeSession?.queryInput.pinnedScope, .windows)
        XCTAssertEqual(presenter.statusUpdates.last?.activeScope, .windows)
        XCTAssertEqual(presenter.statusUpdates.last?.pinnedScope, .windows)
    }

    func test_handleKeyboardCommand_selectScope_labels는_query와_pin을_초기화한다() {
        // given
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(presenter: presenter)
        _ = sut.handleKeyboardCommand(.pinScope(.windows))
        _ = sut.handleKeyboardCommand(.appendQuery("slack"))

        // when
        _ = sut.handleKeyboardCommand(.selectScope(.labels))

        // then
        XCTAssertEqual(sut.activeSession?.queryInput, QueryInputState(lastScope: .labels))
        XCTAssertEqual(presenter.statusUpdates.last?.activeScope, .labels)
        XCTAssertNil(presenter.statusUpdates.last?.pinnedScope)
        XCTAssertEqual(presenter.statusUpdates.last?.queryBuffer, "")
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

    func test_handleKeyboardCommand_windowsScope_return은_windowActivator를_호출하고_rescan한다() async {
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
        await waitForWindowActivation()

        // then
        XCTAssertEqual(windowActivator.activatedEntries, [entry])
        XCTAssertEqual(scanner.scanCallCount, 2)
        XCTAssertEqual(scanner.invalidateCallCount, 1)
        XCTAssertEqual(presenter.showRequests.count, 2)
        XCTAssertEqual(sut.activeSession?.queryInput.lastScope, .elements)
        XCTAssertEqual(presenter.statusUpdates.last?.tone, .success)
    }

    func test_handleKeyboardCommand_windowsScope_resolve실패는_이전overlay를_닫는다() async {
        // given
        let entry = makeWindowEntry(id: 0, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap")
        let resolver = StubOverlayTargetResolver(
            results: [
                .success(makeContext()),
                .failure(.noFrontmostApplication)
            ]
        )
        let presenter = StubOverlayPresenter()
        let sut = makeSessionController(
            scanner: StubOverlayScanner(result: .success(makeScanResult(candidates: [makeCandidate()]))),
            clickExecutor: StubOverlayClickExecutor(result: .failure(.missingFocusedTarget(index: 0))),
            presenter: presenter,
            targetResolver: resolver,
            windowSearchIndexProvider: { WindowSearchIndex(entries: [entry]) },
            windowActivator: StubWindowActivator(result: .success(()))
        )
        _ = sut.start()
        _ = sut.handleKeyboardCommand(.pinScope(.windows))
        _ = sut.handleKeyboardCommand(.appendQuery("slack"))

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)
        await waitForWindowActivation()

        // then
        XCTAssertEqual(resolver.resolveCallCount, 2)
        XCTAssertEqual(presenter.showRequests.count, 1)
        XCTAssertEqual(presenter.closeCallCount, 1)
        XCTAssertEqual(presenter.statusUpdates.last?.tone, .failure)
        XCTAssertNil(sut.activeSession)
    }

    func test_handleKeyboardCommand_windowsScope_scan실패는_이전overlay를_닫는다() async {
        // given
        let entry = makeWindowEntry(id: 0, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap")
        let scanner = StubOverlayScanner(
            results: [
                .success(makeScanResult(candidates: [makeCandidate()])),
                .failure(.childrenUnavailable("temporary"))
            ]
        )
        let presenter = StubOverlayPresenter()
        let sut = makeSessionController(
            scanner: scanner,
            clickExecutor: StubOverlayClickExecutor(result: .failure(.missingFocusedTarget(index: 0))),
            presenter: presenter,
            windowSearchIndexProvider: { WindowSearchIndex(entries: [entry]) },
            windowActivator: StubWindowActivator(result: .success(()))
        )
        _ = sut.start()
        _ = sut.handleKeyboardCommand(.pinScope(.windows))
        _ = sut.handleKeyboardCommand(.appendQuery("slack"))

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)
        await waitForWindowActivation()

        // then
        XCTAssertEqual(scanner.scanCallCount, 2)
        XCTAssertEqual(presenter.showRequests.count, 1)
        XCTAssertEqual(presenter.closeCallCount, 1)
        XCTAssertEqual(presenter.statusUpdates.last?.tone, .failure)
        XCTAssertNil(sut.activeSession)
    }

    func test_handleKeyboardCommand_windowsScope_재검색후보가비면_이전overlay를_닫는다() async {
        // given
        let entry = makeWindowEntry(id: 0, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap")
        let scanner = StubOverlayScanner(
            results: [
                .success(makeScanResult(candidates: [makeCandidate()])),
                .success(makeScanResult(candidates: []))
            ]
        )
        let presenter = StubOverlayPresenter()
        let sut = makeSessionController(
            scanner: scanner,
            clickExecutor: StubOverlayClickExecutor(result: .failure(.missingFocusedTarget(index: 0))),
            presenter: presenter,
            windowSearchIndexProvider: { WindowSearchIndex(entries: [entry]) },
            windowActivator: StubWindowActivator(result: .success(()))
        )
        _ = sut.start()
        _ = sut.handleKeyboardCommand(.pinScope(.windows))
        _ = sut.handleKeyboardCommand(.appendQuery("slack"))

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)
        await waitForWindowActivation()

        // then
        XCTAssertEqual(scanner.scanCallCount, 2)
        XCTAssertEqual(presenter.showRequests.count, 1)
        XCTAssertEqual(presenter.closeCallCount, 1)
        XCTAssertEqual(presenter.statusUpdates.last?.tone, .failure)
        XCTAssertNil(sut.activeSession)
    }

    func test_handleKeyboardCommand_windowsScope_activate실패는_failure_status를_표시한다() async {
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
        await waitForWindowActivation()

        // then
        XCTAssertEqual(windowActivator.activatedEntries, [entry])
        XCTAssertEqual(presenter.statusUpdates.last?.tone, .failure)
        XCTAssertEqual(presenter.statusUpdates.last?.activeScope, .windows)
    }

    func test_handleKeyboardCommand_windowsScope_close후늦은성공결과는_rescan하지않는다() async {
        // given
        let entry = makeWindowEntry(id: 0, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap")
        let windowActivator = SuspendingWindowActivator()
        let scanner = StubOverlayScanner(
            result: .success(makeScanResult(candidates: [makeCandidate(title: "Open")]))
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
        await waitForWindowActivation()
        sut.close()
        windowActivator.complete(with: .success(()))
        await waitForWindowActivation()

        // then
        XCTAssertEqual(windowActivator.activatedEntries, [entry])
        XCTAssertEqual(scanner.scanCallCount, 1)
        XCTAssertEqual(presenter.showRequests.count, 1)
        XCTAssertNil(sut.activeSession)
    }

    func test_handleKeyboardCommand_windowsScope_match가_없으면_기존_label_focus를_비운다() {
        // given
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            windowSearchIndexProvider: { WindowSearchIndex(entries: []) }
        )
        _ = sut.handleKeyboardCommand(.move(.next))
        _ = sut.handleKeyboardCommand(.pinScope(.windows))

        // when
        _ = sut.handleKeyboardCommand(.appendQuery("missing"))

        // then
        XCTAssertNil(sut.activeSession?.focusEngine.focusedItemID)
        XCTAssertNil(presenter.statusUpdates.last?.focusedLabel)
        XCTAssertEqual(presenter.statusUpdates.last?.activeScope, .windows)
        XCTAssertEqual(presenter.statusUpdates.last?.matchCount, 0)
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

    func test_handleKeyboardCommand_windowsScope_같은앱_창이_여러개면_windowMatchPreviews를_그룹핑한다() {
        // given
        let first = makeWindowEntry(id: 0, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap", title: "Alpha")
        let second = makeWindowEntry(id: 1, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap", title: "Beta")
        let third = makeWindowEntry(id: 2, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap", title: "Gamma")
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            windowSearchIndexProvider: { WindowSearchIndex(entries: [first, second, third]) }
        )
        _ = sut.handleKeyboardCommand(.pinScope(.windows))

        // when
        _ = sut.handleKeyboardCommand(.appendQuery("slack"))

        // then
        let previews = presenter.statusUpdates.last?.windowMatchPreviews
        XCTAssertEqual(previews?.count, 2)
        XCTAssertEqual(previews?[0].displayName, "Slack — Alpha")
        XCTAssertTrue(previews?[0].isFocused ?? false)
        XCTAssertEqual(previews?[1].displayName, "Slack — Beta 외 1개 창")
        XCTAssertEqual(previews?[1].additionalWindowCount, 1)
        XCTAssertFalse(previews?[1].isFocused ?? true)
    }

    func test_handleKeyboardCommand_windowsScope_그룹요약row는_recencyRank가_낮은_창을_대표로_고른다() {
        // given
        let first = makeWindowEntry(id: 0, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap", title: "Alpha")
        let second = makeWindowEntry(
            id: 1,
            appName: "Slack",
            bundleID: "com.tinyspeck.slackmacgap",
            title: "Beta",
            recencyRank: 3
        )
        let third = makeWindowEntry(
            id: 2,
            appName: "Slack",
            bundleID: "com.tinyspeck.slackmacgap",
            title: "Gamma",
            recencyRank: 0
        )
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            windowSearchIndexProvider: { WindowSearchIndex(entries: [first, second, third]) }
        )
        _ = sut.handleKeyboardCommand(.pinScope(.windows))

        // when
        _ = sut.handleKeyboardCommand(.appendQuery("slack"))

        // then
        let previews = presenter.statusUpdates.last?.windowMatchPreviews
        XCTAssertEqual(previews?.count, 2)
        XCTAssertEqual(previews?[1].displayName, "Slack — Gamma 외 1개 창")
    }

    func test_handleKeyboardCommand_windowsScope_그룹핑은_6개_slice_경계밖_창도_카운트에_포함한다() {
        // given: 같은 앱 창 8개 (maxWindowMatchPreviewCount(6)를 넘겨서 예전엔 slice 밖 창이 누락됐다)
        let entries = (0..<8).map { index in
            makeWindowEntry(
                id: index,
                appName: "Chrome",
                bundleID: "com.google.Chrome",
                title: "Tab\(index)"
            )
        }
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            windowSearchIndexProvider: { WindowSearchIndex(entries: entries) }
        )
        _ = sut.handleKeyboardCommand(.pinScope(.windows))
        _ = sut.handleKeyboardCommand(.appendQuery("chrome"))

        // when: 마지막 창(index 7)까지 focus를 이동한다
        for _ in 0..<7 {
            _ = sut.handleKeyboardCommand(.cycleMatch(forward: true))
        }

        // then: unfocused 7개(Tab0~Tab6) 중 1개는 대표로 표시되고 나머지 6개가 "외 N개"에 잡혀야 한다.
        // slice를 먼저 자르던 예전 로직이면 slice 밖(Tab0, Tab1)이 누락되어 4가 나왔을 것이다.
        let previews = presenter.statusUpdates.last?.windowMatchPreviews
        XCTAssertEqual(previews?.count, 2)
        XCTAssertTrue(previews?[0].isFocused ?? false)
        XCTAssertEqual(previews?[0].displayName, "Chrome — Tab7")
        XCTAssertEqual(previews?[1].additionalWindowCount, 6)
    }

    func test_handleKeyboardCommand_windowsScope_tabCount가_windowMatchPreviews로_전달된다() {
        // given
        let entry = makeWindowEntry(id: 0, appName: "Chrome", bundleID: "com.google.Chrome", title: "Gmail", tabCount: 5)
        let presenter = StubOverlayPresenter()
        let sut = makeStartedSessionController(
            presenter: presenter,
            windowSearchIndexProvider: { WindowSearchIndex(entries: [entry]) }
        )
        _ = sut.handleKeyboardCommand(.pinScope(.windows))

        // when
        _ = sut.handleKeyboardCommand(.appendQuery("chrome"))

        // then
        let previews = presenter.statusUpdates.last?.windowMatchPreviews
        XCTAssertEqual(previews?.first?.tabCount, 5)
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
                tone: .failure,
                phase: .failure
            )
        )
        XCTAssertNotNil(sut.activeSession)
    }

    func test_handleKeyboardCommand_dryRunConfirm은_선택snapshot을_clickExecutor에_전달() {
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
        XCTAssertEqual(clickExecutor.requests.map(\.selection.labelID), [1])
        XCTAssertEqual(clickExecutor.requests.first?.selection.sourceCandidateCount, 2)
        XCTAssertEqual(clickExecutor.requests.first?.selection.candidate, makeCandidate(frame: CGRect(x: 220, y: 180, width: 44, height: 24)))
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
                    windowTitleHash: hasher.hash("Finder"),
                    clickMethod: "axPress",
                    targetMatchResult: "matched"
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
        XCTAssertEqual(clickExecutor.requests.map(\.selection.labelID), [1])
        XCTAssertEqual(presenter.focusUpdates, [0, 1, 1])
        XCTAssertEqual(
            presenter.statusUpdates.last,
            OverlayInteractionStatus(
                focusedLabel: "S",
                message: "Clicked",
                tone: .success,
                phase: .success,
                hasExplicitFocus: true
            )
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
                tone: .failure,
                phase: .failure
            )
        )
    }

    func test_handleKeyboardCommand_targetMismatch는_cache를무효화하고_새라벨을표시한다() {
        // given
        let recorder = StubInteractionRecorder()
        let scanner = StubOverlayScanner(
            results: [
                .success(makeScanResult(candidates: [makeCandidate(title: "Open")])),
                .success(makeScanResult(candidates: [makeCandidate(title: "Reload")]))
            ]
        )
        let presenter = StubOverlayPresenter()
        let clickExecutor = StubOverlayClickExecutor(
            result: .failure(.selectedTargetChanged(labelID: 0))
        )
        let sut = makeSessionController(
            scanner: scanner,
            clickExecutor: clickExecutor,
            presenter: presenter,
            recorder: recorder
        )
        _ = sut.start()

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(sut.lastClickResult, .failure(.selectedTargetChanged(labelID: 0)))
        XCTAssertEqual(clickExecutor.requests.count, 1)
        XCTAssertEqual(scanner.invalidateCallCount, 1)
        XCTAssertEqual(scanner.scanCallCount, 2)
        XCTAssertEqual(presenter.showRequests.count, 2)
        XCTAssertEqual(presenter.showRequests.last?.candidates.map(\.title), ["Reload"])
        XCTAssertEqual(
            presenter.statusUpdates.last?.message,
            "The screen changed, so labels were refreshed. Select again."
        )
        XCTAssertEqual(recorder.events.last?.clickMethod, nil)
        XCTAssertEqual(recorder.events.last?.targetMatchResult, "changed")
    }

    func test_handleKeyboardCommand_targetMismatch재스캔실패는_기존overlay에_안내를표시한다() {
        // given
        let scanner = StubOverlayScanner(
            results: [
                .success(makeScanResult(candidates: [makeCandidate(title: "Open")])),
                .failure(.childrenUnavailable("test"))
            ]
        )
        let presenter = StubOverlayPresenter()
        let clickExecutor = StubOverlayClickExecutor(
            result: .failure(.selectedTargetUnavailable(labelID: 0))
        )
        let sut = makeSessionController(
            scanner: scanner,
            clickExecutor: clickExecutor,
            presenter: presenter
        )
        _ = sut.start()

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(clickExecutor.requests.count, 1)
        XCTAssertEqual(scanner.invalidateCallCount, 1)
        XCTAssertEqual(scanner.scanCallCount, 2)
        XCTAssertEqual(presenter.showRequests.count, 1)
        XCTAssertEqual(
            presenter.statusUpdates.last?.message,
            "The screen could not be rescanned. Try again shortly."
        )
        XCTAssertEqual(sut.activeSession?.snapshot.scanResult.candidates.map(\.title), ["Open"])
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

    func test_handleKeyboardCommand_위험click은_명시적인재확인상태를표시한다() {
        // given
        let presenter = StubOverlayPresenter()
        let clickExecutor = StubOverlayClickExecutor(
            result: .failure(.executionFailed(.secondConfirmRequired(riskClass: .destructive)))
        )
        let sut = makeStartedSessionController(
            presenter: presenter,
            clickExecutor: clickExecutor
        )

        // when
        _ = sut.handleKeyboardCommand(.dryRunConfirm)

        // then
        XCTAssertEqual(presenter.statusUpdates.last?.phase, .awaitingRiskConfirmation)
        XCTAssertEqual(presenter.statusUpdates.last?.requiresSecondConfirm, true)
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
        XCTAssertEqual(clickExecutor.requests.map(\.selection.labelID), [0, 1])
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
        try XCTUnwrap(presenter.keyboardCommandHandler)(
            OverlayCapturedKeyboardCommand(command: .move(.next), captureMode: .eventTap)
        )

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
        XCTAssertEqual(status?.isGazeTargeting, true)
        // 겨냥은 검색 매칭이 아니므로 matchCount를 올리지 않는다.
        XCTAssertEqual(status?.matchCount, 0)
        XCTAssertEqual(status?.matchIndex, 0)
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
        XCTAssertEqual(status?.isGazeTargeting, false)
        XCTAssertEqual(status?.matchCount, 0)
        XCTAssertNotNil(status?.focusedLabel)
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
        XCTAssertEqual(status?.isGazeTargeting, true)
    }

    func test_focusNearestLabel_windows_scope에서는_gaze를_무시한다() {
        // given: windows scope를 pin하면 공간 겨냥 대상이 없다.
        let presenter = StubOverlayPresenter()
        let recorder = StubInteractionRecorder()
        let sut = makeStartedSessionController(presenter: presenter, recorder: recorder)
        _ = sut.handleKeyboardCommand(.pinScope(.windows))
        let focusedItemIDBefore = sut.activeSession?.focusEngine.focusedItemID
        let focusUpdatesBefore = presenter.focusUpdates.count
        let eventsBefore = recorder.events.count

        // when
        let event = sut.focusNearestLabel(to: CGPoint(x: 225, y: 185))

        // then: gaze는 no-op — focus·기록을 바꾸지 않고 windows scope를 유지한다
        XCTAssertNil(event)
        XCTAssertEqual(sut.activeSession?.queryInput.pinnedScope, .windows)
        XCTAssertEqual(sut.activeSession?.focusEngine.focusedItemID, focusedItemIDBefore)
        XCTAssertEqual(presenter.focusUpdates.count, focusUpdatesBefore)
        XCTAssertEqual(recorder.events.count, eventsBefore)
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

    private func waitForWindowActivation() async {
        for _ in 0..<3 {
            await Task.yield()
        }
    }

    private func waitForProgressiveScan() async {
        for _ in 0..<6 {
            await Task.yield()
        }
    }

    private func makeStartedSessionController(
        presenter: StubOverlayPresenter? = nil,
        recorder: StubInteractionRecorder? = nil,
        clickExecutor: StubOverlayClickExecutor? = nil,
        candidates: [ClickableCandidate]? = nil,
        searchableNodeCollector: (any SearchableNodeCollecting)? = nil,
        windowSearchIndexProvider: @escaping () -> WindowSearchIndex = { WindowSearchIndex(entries: []) },
        windowActivator: (any WindowActivating)? = nil,
        windowTitleHasher: WindowTitleHasher = WindowTitleHasher(salt: SessionSalt(value: "default-test-salt")),
        dateProvider: @escaping () -> Date = Date.init,
        activationTracer: (any OverlayActivationTracing)? = nil,
        clickResultObserver: @escaping @MainActor (Result<ClickExecutionSuccess, OverlaySessionClickFailure>) -> Void = { _ in }
    ) -> OverlaySessionController {
        let presenter = presenter ?? StubOverlayPresenter()
        let recorder = recorder ?? StubInteractionRecorder()
        let clickExecutor = clickExecutor ?? StubOverlayClickExecutor(
            result: .failure(.missingFocusedTarget(index: 0))
        )
        let activationTracer = activationTracer ?? OverlayActivationTracer()
        let windowActivator = windowActivator ?? StubWindowActivator(result: .failure(.appNotRunning))
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
            activationTracer: activationTracer,
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
        presenter: StubOverlayPresenter? = nil,
        recorder: (any OverlaySessionInteractionRecording)? = nil,
        targetResolver: (any OverlaySessionTargetResolving)? = nil,
        windowSearchIndexProvider: @escaping () -> WindowSearchIndex = { WindowSearchIndex(entries: []) },
        windowActivator: (any WindowActivating)? = nil
    ) -> OverlaySessionController {
        let presenter = presenter ?? StubOverlayPresenter()
        let recorder = recorder ?? StubInteractionRecorder()
        let targetResolver = targetResolver ?? StubOverlayTargetResolver(result: .success(makeContext()))
        let windowActivator = windowActivator ?? StubWindowActivator(result: .failure(.appNotRunning))
        return OverlaySessionController(
            targetResolver: targetResolver,
            scanner: scanner,
            overlayPresenter: presenter,
            interactionRecorder: recorder,
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
        title: String? = nil,
        recencyRank: Int = Int.max,
        tabCount: Int? = nil
    ) -> WindowEntry {
        WindowEntry(
            id: id,
            appName: appName,
            bundleID: bundleID,
            windowTitle: title,
            windowTitleHash: title.map { "hash-\($0)" },
            pid: pid_t(id + 100),
            axWindow: nil,
            appIcon: nil,
            recencyRank: recencyRank,
            tabCount: tabCount
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
private final class SpySearchableNodeCollector: SearchableNodeCollecting {
    private let index: ElementSearchIndex
    private(set) var buildCallCount = 0

    init(index: ElementSearchIndex) {
        self.index = index
    }

    func buildIndex(context: TargetContext) -> ElementSearchIndex {
        buildCallCount += 1
        return index
    }
}

@MainActor
private final class StubOverlayTargetResolver: OverlaySessionTargetResolving {
    private let results: [Result<TargetContext, TargetResolutionFailure>]
    private(set) var resolveCallCount = 0

    init(result: Result<TargetContext, TargetResolutionFailure>) {
        self.results = [result]
    }

    init(results: [Result<TargetContext, TargetResolutionFailure>]) {
        self.results = results
    }

    func resolve() -> Result<TargetContext, TargetResolutionFailure> {
        resolveCallCount += 1
        return results[min(resolveCallCount - 1, results.count - 1)]
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
private final class SuspendingProgressiveOverlayScanner: OverlaySessionProgressiveScanning {
    private let progress: AccessibilityScanProgress
    private var continuation:
        CheckedContinuation<Result<AccessibilityScanResult, AccessibilityScanFailure>, Never>?
    private(set) var wasCancelled = false

    init(progress: AccessibilityScanProgress) {
        self.progress = progress
    }

    func scan(context: TargetContext) -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        .failure(.cancelled)
    }

    func scanProgressively(
        context: TargetContext,
        onProgress: @escaping (AccessibilityScanProgress) -> Void
    ) async -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        onProgress(progress)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancel()
            }
        }
    }

    func complete(with result: Result<AccessibilityScanResult, AccessibilityScanFailure>) {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(returning: result)
    }

    private func cancel() {
        wasCancelled = true
        complete(with: .failure(.cancelled))
    }
}

@MainActor
private final class StubBundleProgressiveOverlayScanner: OverlaySessionBundleProgressiveScanning {
    private let bundle: AccessibilityScanBundle

    init(bundle: AccessibilityScanBundle) {
        self.bundle = bundle
    }

    func scan(context: TargetContext) -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        .success(bundle.scanResult)
    }

    func scanProgressively(
        context: TargetContext,
        onProgress: @escaping (AccessibilityScanProgress) -> Void
    ) async -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        .success(bundle.scanResult)
    }

    func scanBundleProgressively(
        context: TargetContext,
        onProgress: @escaping (AccessibilityScanProgress) -> Void
    ) async -> Result<AccessibilityScanBundle, AccessibilityScanFailure> {
        .success(bundle)
    }
}

@MainActor
private final class SequencedSuspendingProgressiveOverlayScanner: OverlaySessionProgressiveScanning {
    private let progresses: [AccessibilityScanProgress]
    private var continuations:
        [Int: CheckedContinuation<Result<AccessibilityScanResult, AccessibilityScanFailure>, Never>] = [:]
    private(set) var cancelledRequestIndices: [Int] = []
    private var scanCallCount = 0

    init(progresses: [AccessibilityScanProgress]) {
        self.progresses = progresses
    }

    func scan(context: TargetContext) -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        .failure(.cancelled)
    }

    func scanProgressively(
        context: TargetContext,
        onProgress: @escaping (AccessibilityScanProgress) -> Void
    ) async -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        let requestIndex = scanCallCount
        scanCallCount += 1
        onProgress(progresses[min(requestIndex, progresses.count - 1)])
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                continuations[requestIndex] = continuation
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelledRequestIndices.append(requestIndex)
            }
        }
    }

    func complete(
        requestAt index: Int,
        with result: Result<AccessibilityScanResult, AccessibilityScanFailure>
    ) {
        continuations.removeValue(forKey: index)?.resume(returning: result)
    }
}

@MainActor
private final class StubOverlayPresenter: OverlaySessionPresenting {
    private let forcedLayout: OverlayLayout?
    private(set) var showRequests: [ShowRequest] = []
    private(set) var closeCallCount = 0
    private(set) var keyboardCommandHandler: ((OverlayCapturedKeyboardCommand) -> Void)?
    private(set) var focusUpdates: [Int?] = []
    private(set) var statusUpdates: [OverlayInteractionStatus] = []
    private(set) var presentationEvents: [OverlayPresentationEvent] = []
    private var lastLayout: OverlayLayout?
    private var candidatesForNextShow: [ClickableCandidate] = []
    var onShow: (() -> Void)?

    init(forcedLayout: OverlayLayout? = nil) {
        self.forcedLayout = forcedLayout
    }

    func makeLayout(
        targetFrame: CGRect,
        candidates: [ClickableCandidate],
        labels: [String]
    ) -> OverlayLayout {
        candidatesForNextShow = candidates
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

    func show(
        layout: OverlayLayout,
        initialStatus: OverlayInteractionStatus,
        onEscape: @escaping () -> Void,
        onKeyboardCommand: @MainActor @escaping (OverlayCapturedKeyboardCommand) -> Void,
        onPresentationEvent: @MainActor @escaping (OverlayPresentationEvent) -> Void
    ) -> OverlayKeyboardCaptureMode {
        showRequests.append(
            ShowRequest(
                targetFrame: layout.targetFrame,
                candidates: candidatesForNextShow,
                labels: layout.labels.map(\.text)
            )
        )
        keyboardCommandHandler = onKeyboardCommand
        lastLayout = layout
        statusUpdates.append(initialStatus)
        focusUpdates.append(focusedLabelID(for: initialStatus.focusedLabel))
        onShow?()
        onPresentationEvent(.captureReady(.eventTap))
        onPresentationEvent(.panelsOrdered)
        onPresentationEvent(.firstDisplayPass)
        presentationEvents = [.captureReady(.eventTap), .panelsOrdered, .firstDisplayPass]
        return .eventTap
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

@MainActor
private final class SpyOverlayActivationTracer: OverlayActivationTracing {
    private(set) var phases: [OverlayActivationPhase] = []
    private(set) var metadataByPhase: [OverlayActivationPhase: OverlayActivationTraceMetadata] = [:]
    private(set) var endedActivationCount = 0

    func begin(at date: Date) -> UUID {
        UUID()
    }

    func end(activationID: UUID) {
        endedActivationCount += 1
    }

    func mark(
        _ phase: OverlayActivationPhase,
        activationID: UUID,
        at date: Date,
        metadata: OverlayActivationTraceMetadata
    ) {
        phases.append(phase)
        metadataByPhase[phase] = metadata
    }

    func metadata(for phase: OverlayActivationPhase) -> OverlayActivationTraceMetadata? {
        metadataByPhase[phase]
    }

    var serializedMetadata: String {
        metadataByPhase.values.map { metadata in
            "\(metadata.nodesVisited ?? -1)|\(metadata.candidateCount ?? -1)|\(metadata.commandKind ?? "-")|\(metadata.hasActiveSession.map(String.init) ?? "-")"
        }
        .joined(separator: " ")
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
        selection: OverlayClickSelection,
        context: TargetContext,
        isSecondConfirmProvided: Bool
    ) -> Result<ClickExecutionSuccess, OverlaySessionClickFailure> {
        requests.append(
            ClickRequest(
                selection: selection,
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
    let selection: OverlayClickSelection
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

    func activate(_ entry: WindowEntry) async -> Result<Void, WindowActivateFailure> {
        activatedEntries.append(entry)
        return result
    }
}

@MainActor
private final class SuspendingWindowActivator: WindowActivating {
    private var continuation: CheckedContinuation<Result<Void, WindowActivateFailure>, Never>?
    private(set) var activatedEntries: [WindowEntry] = []

    func activate(_ entry: WindowEntry) async -> Result<Void, WindowActivateFailure> {
        activatedEntries.append(entry)
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func complete(with result: Result<Void, WindowActivateFailure>) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}
