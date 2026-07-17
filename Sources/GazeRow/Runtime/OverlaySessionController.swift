import CoreGraphics
import Foundation

/// overlay session activation 흐름을 연결한다.
///
/// target resolve, AX scan, overlay 표시를 한 진입점에서 실행한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class OverlaySessionController {
    private static let secondConfirmTimeout: TimeInterval = 3
    private static let maxWindowMatchPreviewCount = 6
    /// gaze focus 흔들림 완화용 히스테리시스 margin(pt).
    /// 새 후보가 현재 focus보다 이 값 이상 더 가까워야 focus를 옮긴다.
    private static let gazeHysteresisMargin: CGFloat = 16

    private let targetResolver: any OverlaySessionTargetResolving
    private let scanner: any OverlaySessionScanning
    private let overlayPresenter: any OverlaySessionPresenting
    private let interactionRecorder: any OverlaySessionInteractionRecording
    private let clickExecutor: any OverlaySessionClickExecuting
    private let searchableNodeCollector: (any SearchableNodeCollecting)?
    private let intentRouter: IntentRouter
    private let windowSearchIndexProvider: () -> WindowSearchIndex
    private let windowActivator: any WindowActivating
    private let windowTitleHasher: WindowTitleHasher
    private let dateProvider: () -> Date
    private let isSessionEnabled: @MainActor () -> Bool
    private let languageProvider: () -> AppLanguage
    private let activationTracer: any OverlayActivationTracing
    private let clickResultObserver: @MainActor (Result<ClickExecutionSuccess, OverlaySessionClickFailure>) -> Void
    private(set) var activeSession: OverlaySessionState?
    private(set) var lastClickResult: Result<ClickExecutionSuccess, OverlaySessionClickFailure>?
    private var activeActivationID: UUID?
    private var windowActivationTask: Task<Void, Never>?
    private var windowActivationRequestID: UUID?

    private var content: AppContent.Localized {
        AppContent.localized(for: languageProvider())
    }

    init(
        targetResolver: (any OverlaySessionTargetResolving)? = nil,
        scanner: (any OverlaySessionScanning)? = nil,
        overlayPresenter: (any OverlaySessionPresenting)? = nil,
        interactionRecorder: (any OverlaySessionInteractionRecording)? = nil,
        clickExecutor: (any OverlaySessionClickExecuting)? = nil,
        searchableNodeCollector: (any SearchableNodeCollecting)? = DefaultSearchableNodeCollector(),
        intentRouter: IntentRouter = IntentRouter(),
        windowSearchIndexProvider: @escaping () -> WindowSearchIndex = { WindowSearchIndex.build() },
        windowActivator: (any WindowActivating)? = nil,
        windowTitleHasher: WindowTitleHasher = WindowTitleHasher(salt: SessionSalt()),
        dateProvider: @escaping () -> Date = Date.init,
        isSessionEnabled: @escaping @MainActor () -> Bool = { SessionController.shared.isEnabled },
        languageProvider: @escaping () -> AppLanguage = { AppLanguageSettings().selectedLanguage },
        activationTracer: (any OverlayActivationTracing)? = nil,
        clickResultObserver: @escaping @MainActor (Result<ClickExecutionSuccess, OverlaySessionClickFailure>) -> Void = { _ in }
    ) {
        self.targetResolver = targetResolver ?? TargetResolver()
        self.scanner = scanner ?? CachingScanner(
            wrapped: AccessibilityScanner(client: AXAccessibilityElementClient()),
            changeMonitor: AXAccessibilityChangeMonitor()
        )
        self.overlayPresenter = overlayPresenter ?? OverlayWindowController()
        self.interactionRecorder = interactionRecorder ?? InteractionLogStore()
        self.clickExecutor = clickExecutor ?? AXOverlaySessionClickExecutor()
        self.searchableNodeCollector = searchableNodeCollector
        self.intentRouter = intentRouter
        self.windowSearchIndexProvider = windowSearchIndexProvider
        self.windowActivator = windowActivator ?? WindowActivator()
        self.windowTitleHasher = windowTitleHasher
        self.dateProvider = dateProvider
        self.isSessionEnabled = isSessionEnabled
        self.languageProvider = languageProvider
        self.activationTracer = activationTracer ?? OverlayActivationTracer()
        self.clickResultObserver = clickResultObserver
    }

    func start() -> OverlaySessionStartResult {
        lastClickResult = nil
        cancelWindowActivation()
        let startedAt = dateProvider()
        if let activeActivationID {
            activationTracer.end(activationID: activeActivationID)
        }
        let activationID = activationTracer.begin(at: startedAt)
        activeActivationID = activationID
        trace(.shortcutReceived, activationID: activationID, at: startedAt)

        guard isSessionEnabled() else {
            close()
            return .failure(.sessionDisabled)
        }

        let context: TargetContext
        switch targetResolver.resolve() {
        case .success(let resolvedContext):
            context = resolvedContext
        case .failure(let failure):
            close()
            return .failure(.targetResolutionFailed(failure))
        }
        let targetResolvedAt = dateProvider()
        trace(.targetResolved, activationID: activationID, at: targetResolvedAt)

        let scanResult: AccessibilityScanResult
        switch scanner.scan(context: context) {
        case .success(let result):
            scanResult = result
        case .failure(let failure):
            close()
            return .failure(.scanFailed(failure))
        }
        let scannedAt = dateProvider()
        trace(
            .scanCompleted,
            activationID: activationID,
            at: scannedAt,
            metadata: OverlayActivationTraceMetadata(
                nodesVisited: scanResult.nodesVisited,
                candidateCount: scanResult.candidateCount,
                didTimeout: scanResult.didTimeout,
                didHitNodeLimit: scanResult.didHitNodeLimit,
                didHitDepthLimit: scanResult.didHitDepthLimit,
                failedChildReadCount: scanResult.failedChildReadCount
            )
        )

        guard !scanResult.candidates.isEmpty else {
            close()
            return .failure(.noCandidates(context: context, scanResult: scanResult))
        }

        let layout = overlayPresenter.makeLayout(
            targetFrame: context.window.frame,
            candidates: scanResult.candidates,
            labels: []
        )
        let layoutCompletedAt = dateProvider()
        trace(
            .layoutCompleted,
            activationID: activationID,
            at: layoutCompletedAt,
            metadata: OverlayActivationTraceMetadata(candidateCount: layout.labels.count)
        )

        let snapshot = OverlaySessionSnapshot(
            context: context,
            scanResult: scanResult,
            layout: layout
        )
        let session = OverlaySessionState(
            snapshot: snapshot,
            focusEngine: FocusEngine(layout: layout),
            elementIndex: makeFallbackElementIndex(scanResult: scanResult)
        )
        activeSession = session
        trace(
            .sessionReady,
            activationID: activationID,
            at: dateProvider(),
            metadata: OverlayActivationTraceMetadata(hasActiveSession: true)
        )
        _ = overlayPresenter.show(
            layout: layout,
            initialStatus: status(
                for: session,
                resolution: nil,
                message: content.overlayReadyText,
                tone: .neutral
            ),
            onEscape: { [weak self] in
                self?.close()
            },
            onKeyboardCommand: { [weak self] capturedCommand in
                _ = self?.handleCapturedKeyboardCommand(capturedCommand)
            },
            onPresentationEvent: { [weak self] event in
                self?.tracePresentationEvent(event, activationID: activationID)
            }
        )
        let shownAt = dateProvider()
        let labelMap = zip(layout.labels, scanResult.candidates).prefix(14).map { label, candidate in
            "\(label.id):\(label.text)@(\(Int(candidate.frame.minX)),\(Int(candidate.frame.minY)) \(Int(candidate.frame.width))x\(Int(candidate.frame.height)))"
        }.joined(separator: " ")
        AppLogger.interaction.info(
            "overlay candidates count=\(layout.labels.count, privacy: .public) map=\(labelMap, privacy: .public)"
        )
        AppLogger.overlay.info(
            "overlay start timing targetMs=\(Self.milliseconds(from: startedAt, to: targetResolvedAt), privacy: .public) scanMs=\(Self.milliseconds(from: targetResolvedAt, to: scannedAt), privacy: .public) showMs=\(Self.milliseconds(from: scannedAt, to: shownAt), privacy: .public) totalMs=\(Self.milliseconds(from: startedAt, to: shownAt), privacy: .public) nodes=\(scanResult.nodesVisited, privacy: .public) candidates=\(scanResult.candidateCount, privacy: .public) timeout=\(scanResult.didTimeout, privacy: .public)"
        )
        return .success(snapshot)
    }

    func handleKeyboardCommand(_ command: FocusKeyboardCommand) -> FocusEngineEvent? {
        handleKeyboardCommand(command, captureMode: nil)
    }

    private func handleCapturedKeyboardCommand(_ capturedCommand: OverlayCapturedKeyboardCommand) -> FocusEngineEvent? {
        handleKeyboardCommand(capturedCommand.command, captureMode: capturedCommand.captureMode)
    }

    private func handleKeyboardCommand(
        _ command: FocusKeyboardCommand,
        captureMode: OverlayKeyboardCaptureMode?
    ) -> FocusEngineEvent? {
        traceKeyboardCommand(.keyCaptured, command: command, captureMode: captureMode)
        guard var session = activeSession else {
            return nil
        }
        guard !session.isScanInProgress else {
            return nil
        }
        traceKeyboardCommand(
            .commandHandled,
            command: command,
            captureMode: captureMode,
            hasActiveSession: true
        )

        let event: FocusEngineEvent?
        var statusMessage: String?
        var statusTone = OverlayInteractionStatus.Tone.neutral
        switch command {
        case .move(let moveCommand):
            session.pendingSecondConfirm = nil
            event = session.focusEngine.move(moveCommand)
            session.focusOrigin = .keyboard
            session.queryInput.lastScope = .labels
            statusMessage = focusedMessage(for: session)
        case .typeLabel(let character):
            session.pendingSecondConfirm = nil
            let typingResult = session.focusEngine.typeLabelCharacter(character)
            if typingResult.isExactMatch {
                session.focusOrigin = .label
            }
            session.queryInput.lastScope = .labels
            event = typingResult.event
            let feedback = feedback(for: typingResult, typedCharacter: character, session: session)
            statusMessage = feedback.message
            statusTone = feedback.tone
        case .appendQuery(let grapheme):
            session.pendingSecondConfirm = nil
            appendQuery(grapheme, to: &session)
            session.queryInput.lastScope = session.queryInput.pinnedScope ?? .elements
            prepareIndex(for: session.queryInput.lastScope, session: &session)
            resolveQueryAndPresent(&session)
            return nil
        case .deleteQueryCharacter:
            session.pendingSecondConfirm = nil
            if !session.queryInput.buffer.isEmpty {
                session.queryInput.buffer.removeLast()
            } else {
                session.focusEngine.clearLabelBuffer()
            }
            if !session.queryInput.buffer.isEmpty {
                prepareIndex(for: session.queryInput.lastScope, session: &session)
                resolveQueryAndPresent(&session)
                return nil
            }
            event = nil
            statusMessage = content.overlayInputClearedText
        case .clearQueryBuffer:
            session.pendingSecondConfirm = nil
            session.queryInput = QueryInputState(lastScope: session.queryInput.lastScope)
            session.focusEngine.clearLabelBuffer()
            session.elementMatches = []
            session.elementMatchIndex = 0
            event = nil
            statusMessage = content.overlayInputClearedText
        case .clearLabelBuffer:
            session.pendingSecondConfirm = nil
            session.focusEngine.clearLabelBuffer()
            session.queryInput.buffer = ""
            session.queryInput.pinnedScope = nil
            event = nil
            statusMessage = content.overlayInputClearedText
        case .pinScope(let scope):
            session.pendingSecondConfirm = nil
            session.queryInput.pinnedScope = scope
            session.queryInput.lastScope = scope
            prepareIndex(for: scope, session: &session)
            event = nil
            statusMessage = content.overlayPinnedText(scope)
        case .selectScope(let scope):
            session.pendingSecondConfirm = nil
            selectScope(scope, session: &session)
            if session.queryInput.buffer.isEmpty {
                event = nil
                statusMessage = scope == .labels ? content.overlayLabelsSelectedText : content.overlayPinnedText(scope)
            } else {
                resolveQueryAndPresent(&session)
                return nil
            }
        case .cycleMatch(let forward):
            session.pendingSecondConfirm = nil
            if shouldCycleQueryMatches(session, scope: .elements) {
                ensureSearchableElementIndexIfNeeded(session: &session)
                cycleElementMatch(forward: forward, session: &session)
                resolveQueryAndPresent(&session)
                return nil
            } else if shouldCycleQueryMatches(session, scope: .windows) {
                ensureWindowIndexIfNeeded(session: &session)
                cycleWindowMatch(forward: forward, session: &session)
                resolveQueryAndPresent(&session)
                return nil
            } else {
                event = session.focusEngine.move(forward ? .next : .previous)
                session.queryInput.lastScope = .labels
                statusMessage = focusedMessage(for: session)
            }
        case .dryRunConfirm:
            if session.queryInput.lastScope == .windows || session.queryInput.pinnedScope == .windows {
                activateFocusedWindow(session: &session)
                return nil
            }
            let confirmResult = session.focusEngine.dryRunConfirm()
            executeClickIfPossible(confirmResult: confirmResult, session: &session)
            return confirmResult.event
        case .closeOverlay:
            close()
            return nil
        }

        activeSession = session
        updateOverlayStatus(for: session, message: statusMessage, tone: statusTone)
        record(event, context: session.snapshot.context)
        if event != nil {
            traceKeyboardCommand(.focusStateChanged, command: command, hasActiveSession: true)
        }
        return event
    }

    @discardableResult
    func clickLabel(_ label: String) -> Result<ClickExecutionSuccess, OverlaySessionClickFailure>? {
        let normalizedLabel = label.uppercased()
        guard let session = activeSession else {
            return nil
        }

        guard session.snapshot.layout.labels.contains(where: { $0.text == normalizedLabel }) else {
            let result: Result<ClickExecutionSuccess, OverlaySessionClickFailure> = .failure(
                .missingFocusedTarget(index: -1)
            )
            lastClickResult = result
            clickResultObserver(result)
            return result
        }

        for character in normalizedLabel {
            _ = handleKeyboardCommand(.typeLabel(character))
        }
        _ = handleKeyboardCommand(.dryRunConfirm)
        return lastClickResult
    }

    func focusNearestLabel(to gazePoint: CGPoint) -> FocusEngineEvent? {
        guard var session = activeSession else {
            return nil
        }

        // gaze는 공간 겨냥 scope(labels·elements)에서만 focus를 옮긴다.
        // windows처럼 공간 대상이 없는 scope에서는 gaze가 label focus를 가로채
        // 상태바(windows)와 어긋나는 모달리티 불일치(원인 4)를 만들지 않도록 무시한다.
        guard activeScope(for: session).isSpatial else {
            return nil
        }

        let event = session.focusEngine.focusNearest(
            to: gazePoint,
            hysteresisMargin: Self.gazeHysteresisMargin
        )
        if event != nil {
            session.focusOrigin = .gaze
        }
        activeSession = session
        updateOverlayStatus(for: session, message: focusedMessage(for: session), tone: .neutral)
        record(event, context: session.snapshot.context)
        return event
    }

    private func executeClickIfPossible(
        confirmResult: DryRunConfirmResult,
        session: inout OverlaySessionState
    ) {
        guard let focusedItemID = confirmResult.focusedItemID else {
            AppLogger.interaction.info("confirm click skipped (no focused target)")
            let result: Result<ClickExecutionSuccess, OverlaySessionClickFailure> = .failure(
                .missingFocusedTarget(index: -1)
            )
            lastClickResult = result
            clickResultObserver(result)
            activeSession = session
            overlayPresenter.updateStatus(
                status(
                    for: session,
                    resolution: nil,
                    message: content.clickResultText(result),
                    tone: .failure
                )
            )
            return
        }

        let isSecondConfirmProvided = isPendingSecondConfirmValid(
            for: focusedItemID,
            session: &session
        )
        guard session.snapshot.scanResult.candidates.indices.contains(focusedItemID) else {
            let result: Result<ClickExecutionSuccess, OverlaySessionClickFailure> = .failure(
                .missingFocusedTarget(index: focusedItemID)
            )
            lastClickResult = result
            clickResultObserver(result)
            recordClick(result: result, context: session.snapshot.context)
            activeSession = session
            overlayPresenter.updateStatus(
                status(
                    for: session,
                    resolution: nil,
                    message: content.clickResultText(result),
                    tone: .failure
                )
            )
            return
        }
        let selection = OverlayClickSelection(
            labelID: focusedItemID,
            candidate: session.snapshot.scanResult.candidates[focusedItemID],
            sourceCandidateCount: session.snapshot.scanResult.candidateCount
        )
        let diagnostic = OverlayClickTargetDiagnostic.source(
            index: selection.labelID,
            candidateCount: selection.sourceCandidateCount,
            candidate: selection.candidate
        )
        AppLogger.interaction.info(
            "\(diagnostic, privacy: .public)"
        )
        let result = clickExecutor.execute(
            selection: selection,
            context: session.snapshot.context,
            isSecondConfirmProvided: isSecondConfirmProvided
        )
        AppLogger.interaction.info(
            "confirm click executed index=\(focusedItemID, privacy: .public) result=\(String(describing: result), privacy: .public)"
        )
        lastClickResult = result
        clickResultObserver(result)
        recordClick(result: result, context: session.snapshot.context)

        switch result {
        case .success:
            overlayPresenter.updateStatus(
                status(
                    for: session,
                    resolution: nil,
                    message: content.overlayClickedText,
                    tone: .success,
                    phase: .success
                )
            )
            // 클릭 성공은 target UI를 바꿀 수 있어 다음 activation에서 stale
            // candidate가 재사용되지 않도록 scan cache를 무효화한다.
            scanner.invalidate()
            close()
        case .failure(let failure) where failure.isTargetMismatch:
            refreshAfterTargetMismatch(failure, session: &session)
        case .failure(.executionFailed(.secondConfirmRequired(let riskClass))):
            session.pendingSecondConfirm = PendingSecondConfirm(
                focusedItemID: focusedItemID,
                riskClass: riskClass,
                createdAt: dateProvider()
            )
            activeSession = session
            overlayPresenter.updateStatus(
                status(
                    for: session,
                    resolution: nil,
                    message: content.overlaySecondConfirmText(riskClass),
                    tone: .warning,
                    phase: .awaitingRiskConfirmation,
                    requiresSecondConfirm: true
                )
            )
        case .failure:
            session.pendingSecondConfirm = nil
            activeSession = session
            overlayPresenter.updateStatus(
                status(
                    for: session,
                    resolution: nil,
                    message: content.clickResultText(result),
                    tone: .failure
                )
            )
        }
    }

    private func refreshAfterTargetMismatch(
        _ failure: OverlaySessionClickFailure,
        session: inout OverlaySessionState
    ) {
        session.pendingSecondConfirm = nil
        scanner.invalidate()

        let scanResult: AccessibilityScanResult
        switch scanner.scan(context: session.snapshot.context) {
        case .success(let result) where !result.candidates.isEmpty:
            scanResult = result
        case .success, .failure:
            activeSession = session
            overlayPresenter.updateStatus(
                status(
                    for: session,
                    resolution: nil,
                    message: OverlayClickFailureGuidance.rescanFailureMessage(language: languageProvider()),
                    tone: .failure
                )
            )
            return
        }

        let layout = overlayPresenter.makeLayout(
            targetFrame: session.snapshot.context.window.frame,
            candidates: scanResult.candidates,
            labels: []
        )
        let refreshedSession = OverlaySessionState(
            snapshot: OverlaySessionSnapshot(
                context: session.snapshot.context,
                scanResult: scanResult,
                layout: layout
            ),
            focusEngine: FocusEngine(layout: layout),
            elementIndex: makeFallbackElementIndex(scanResult: scanResult)
        )
        activeSession = refreshedSession
        _ = overlayPresenter.show(
            layout: layout,
            initialStatus: status(
                for: refreshedSession,
                resolution: nil,
                message: OverlayClickFailureGuidance(failure: failure, language: languageProvider()).message,
                tone: .failure
            ),
            onEscape: { [weak self] in
                self?.close()
            },
            onKeyboardCommand: { [weak self] capturedCommand in
                _ = self?.handleCapturedKeyboardCommand(capturedCommand)
            },
            onPresentationEvent: { _ in }
        )
    }

    private func isPendingSecondConfirmValid(
        for focusedItemID: Int,
        session: inout OverlaySessionState
    ) -> Bool {
        guard let pendingSecondConfirm = session.pendingSecondConfirm else {
            return false
        }

        if pendingSecondConfirm.isValid(
            for: focusedItemID,
            at: dateProvider(),
            timeout: Self.secondConfirmTimeout
        ) {
            return true
        }

        session.pendingSecondConfirm = nil
        return false
    }

    func close() {
        cancelWindowActivation()
        overlayPresenter.close()
        activeSession = nil
        if let activeActivationID {
            activationTracer.end(activationID: activeActivationID)
        }
        activeActivationID = nil
    }

    private func record(_ event: FocusEngineEvent?, context: TargetContext) {
        guard let event, let kind = interactionKind(for: event) else {
            return
        }

        interactionRecorder.record(
            InteractionEvent(
                timestamp: dateProvider(),
                kind: kind,
                windowTitleHash: windowTitleHasher.hash(context.window.title)
            )
        )
    }

    private func interactionKind(for event: FocusEngineEvent) -> InteractionEventKind? {
        switch event {
        case .focusChanged(_, _, let method):
            .focusChanged(method: method.logCode)
        case .labelJump(_, let matched, _):
            .labelJump(matched: matched)
        case .dryRunConfirm:
            nil
        }
    }

    private func recordClick(
        result: Result<ClickExecutionSuccess, OverlaySessionClickFailure>,
        context: TargetContext
    ) {
        let risk = clickRisk(for: result)
        record(kind: .clickAttempt(risk: risk.logCode), context: context)

        if shouldRecordClickCompleted(for: result) {
            let metadata = clickInteractionMetadata(for: result)
            record(
                kind: .clickCompleted(
                    risk: risk.logCode,
                    success: result.isSuccess
                ),
                context: context,
                clickMethod: metadata.method,
                targetMatchResult: metadata.targetMatchResult
            )
        }
    }

    private func clickInteractionMetadata(
        for result: Result<ClickExecutionSuccess, OverlaySessionClickFailure>
    ) -> (method: String?, targetMatchResult: String?) {
        switch result {
        case .success(let success):
            return (success.method.logCode, "matched")
        case .failure(.executionFailed):
            return (nil, "matched")
        case .failure(.selectedTargetUnavailable):
            return (nil, "unavailable")
        case .failure(.selectedTargetChanged):
            return (nil, "changed")
        case .failure(.selectedTargetAmbiguous):
            return (nil, "ambiguous")
        case .failure:
            return (nil, nil)
        }
    }

    private func record(
        kind: InteractionEventKind,
        context: TargetContext,
        clickMethod: String? = nil,
        targetMatchResult: String? = nil
    ) {
        interactionRecorder.record(
            InteractionEvent(
                timestamp: dateProvider(),
                kind: kind,
                windowTitleHash: windowTitleHasher.hash(context.window.title),
                clickMethod: clickMethod,
                targetMatchResult: targetMatchResult
            )
        )
    }

    private func updateOverlayStatus(
        for session: OverlaySessionState,
        message: String?,
        tone: OverlayInteractionStatus.Tone
    ) {
        overlayPresenter.updateStatus(
            status(for: session, resolution: nil, message: message, tone: tone)
        )
    }

    private func makeFallbackElementIndex(
        scanResult: AccessibilityScanResult
    ) -> ElementSearchIndex {
        ElementSearchIndex(
            nodes: scanResult.candidates.enumerated().map { index, candidate in
                SearchableNode(
                    id: index,
                    role: candidate.role,
                    subrole: candidate.subrole,
                    title: candidate.title,
                    frame: candidate.frame
                )
            }
        )
    }

    private func ensureSearchableElementIndexIfNeeded(session: inout OverlaySessionState) {
        guard !session.didAttemptSearchableIndexBuild else {
            return
        }

        session.didAttemptSearchableIndexBuild = true
        guard let searchableNodeCollector else {
            return
        }

        let collectedIndex = searchableNodeCollector.buildIndex(context: session.snapshot.context)
        if !collectedIndex.nodes.isEmpty {
            session.elementIndex = collectedIndex
        }
    }

    private func ensureWindowIndexIfNeeded(session: inout OverlaySessionState) {
        guard session.windowIndex == nil || session.windowIndex?.isStale() == true else {
            return
        }

        session.windowIndex = windowSearchIndexProvider()
    }

    private func appendQuery(_ grapheme: String, to session: inout OverlaySessionState) {
        if session.queryInput.buffer.isEmpty || grapheme.count > 1 {
            session.queryInput.buffer = grapheme
        } else {
            session.queryInput.buffer.append(grapheme)
        }
    }

    /// query buffer 재해석 결과를 세션에 반영하고 overlay 상태를 즉시 갱신한다.
    ///
    /// appendQuery/delete/selectScope/cycleMatch 경로가 공유하던 동일 패턴을 한곳으로 모은다.
    private func resolveQueryAndPresent(_ session: inout OverlaySessionState) {
        let resolution = applyQueryResolution(to: &session)
        activeSession = session
        overlayPresenter.updateStatus(
            status(for: session, resolution: resolution, message: nil, tone: .neutral)
        )
    }

    @discardableResult
    private func applyQueryResolution(to session: inout OverlaySessionState) -> QueryResolution {
        session.elementMatches = session.elementIndex.search(session.queryInput.buffer)
        let windowIndex = session.windowIndex ?? WindowSearchIndex(entries: [])
        session.windowMatches = windowIndex.search(session.queryInput.buffer)
        if session.elementMatches.isEmpty {
            session.elementMatchIndex = 0
        } else {
            session.elementMatchIndex = session.elementMatchIndex % session.elementMatches.count
        }
        if session.windowMatches.isEmpty {
            session.windowMatchIndex = 0
        } else {
            session.windowMatchIndex = session.windowMatchIndex % session.windowMatches.count
        }

        let resolution = intentRouter.resolve(
            queryInput: session.queryInput,
            focusEngine: session.focusEngine,
            elementIndex: session.elementIndex,
            elementMatchIndex: session.elementMatchIndex,
            actionableCandidates: session.snapshot.scanResult.candidates,
            windowIndex: windowIndex,
            windowMatchIndex: session.windowMatchIndex
        )
        session.queryInput.lastScope = resolution.scope
        if let focusTargetCandidateIndex = resolution.focusTargetCandidateIndex {
            _ = session.focusEngine.focusItem(id: focusTargetCandidateIndex)
            session.focusOrigin = .query
        } else if resolution.scope == .elements || resolution.scope == .windows {
            _ = session.focusEngine.focusItem(id: -1)
        }
        return resolution
    }

    private func cycleElementMatch(forward: Bool, session: inout OverlaySessionState) {
        guard !session.elementMatches.isEmpty else {
            return
        }

        let delta = forward ? 1 : -1
        session.elementMatchIndex = (
            session.elementMatchIndex + delta + session.elementMatches.count
        ) % session.elementMatches.count
    }

    private func cycleWindowMatch(forward: Bool, session: inout OverlaySessionState) {
        guard !session.windowMatches.isEmpty else {
            return
        }

        let delta = forward ? 1 : -1
        session.windowMatchIndex = (
            session.windowMatchIndex + delta + session.windowMatches.count
        ) % session.windowMatches.count
    }

    private func shouldCycleQueryMatches(_ session: OverlaySessionState, scope: QueryScope) -> Bool {
        !session.queryInput.buffer.isEmpty
            && (session.queryInput.pinnedScope ?? session.queryInput.lastScope) == scope
    }

    private func prepareIndex(for scope: QueryScope, session: inout OverlaySessionState) {
        switch scope {
        case .labels:
            return
        case .elements:
            ensureSearchableElementIndexIfNeeded(session: &session)
        case .windows:
            ensureWindowIndexIfNeeded(session: &session)
        }
    }

    private func selectScope(_ scope: QueryScope, session: inout OverlaySessionState) {
        switch scope {
        case .labels:
            session.queryInput = QueryInputState(lastScope: .labels)
            session.elementMatches = []
            session.elementMatchIndex = 0
            session.windowMatches = []
            session.windowMatchIndex = 0
            session.focusEngine.clearLabelBuffer()
        case .elements, .windows:
            session.queryInput.pinnedScope = scope
            session.queryInput.lastScope = scope
            prepareIndex(for: scope, session: &session)
        }
    }

    private func activateFocusedWindow(session: inout OverlaySessionState) {
        ensureWindowIndexIfNeeded(session: &session)
        let resolution = applyQueryResolution(to: &session)
        guard let entryID = resolution.windowEntryID,
              let entry = session.windowIndex?.entry(id: entryID) else {
            activeSession = session
            overlayPresenter.updateStatus(
                status(for: session, resolution: resolution, message: content.overlayWindowNotFoundText, tone: .failure)
            )
            return
        }

        activeSession = session
        cancelWindowActivation()
        let requestID = UUID()
        let activationID = activeActivationID
        windowActivationRequestID = requestID
        windowActivationTask = Task { [weak self] in
            guard let self else {
                return
            }

            let result = await self.windowActivator.activate(entry)
            guard !Task.isCancelled,
                  self.windowActivationRequestID == requestID,
                  self.activeActivationID == activationID,
                  self.activeSession != nil else {
                return
            }

            self.windowActivationTask = nil
            self.windowActivationRequestID = nil
            self.handleWindowActivation(result, entry: entry)
        }
    }

    private func cancelWindowActivation() {
        windowActivationTask?.cancel()
        windowActivationTask = nil
        windowActivationRequestID = nil
    }

    private func handleWindowActivation(
        _ result: Result<Void, WindowActivateFailure>,
        entry: WindowEntry
    ) {
        switch result {
        case .success:
            rescanFrontmost(message: content.overlayWindowActivatedText(appName: entry.appName))
        case .failure:
            guard var session = activeSession else {
                return
            }
            let resolution = applyQueryResolution(to: &session)
            activeSession = session
            overlayPresenter.updateStatus(
                status(for: session, resolution: resolution, message: content.overlayWindowActivationFailedText, tone: .failure)
            )
        }
    }

    private func rescanFrontmost(message: String) {
        scanner.invalidate()

        let context: TargetContext
        switch targetResolver.resolve() {
        case .success(let resolvedContext):
            context = resolvedContext
        case .failure:
            failRescanAndCloseStaleOverlay(reason: "target resolution failed")
            return
        }

        let scanResult: AccessibilityScanResult
        switch scanner.scan(context: context) {
        case .success(let result):
            scanResult = result
        case .failure:
            failRescanAndCloseStaleOverlay(reason: "accessibility scan failed")
            return
        }

        guard !scanResult.candidates.isEmpty else {
            failRescanAndCloseStaleOverlay(reason: "no clickable candidates")
            return
        }

        let layout = overlayPresenter.makeLayout(
            targetFrame: context.window.frame,
            candidates: scanResult.candidates,
            labels: []
        )
        let snapshot = OverlaySessionSnapshot(context: context, scanResult: scanResult, layout: layout)
        let session = OverlaySessionState(
            snapshot: snapshot,
            focusEngine: FocusEngine(layout: layout),
            queryInput: QueryInputState(lastScope: .elements),
            elementIndex: makeFallbackElementIndex(scanResult: scanResult)
        )
        activeSession = session
        _ = overlayPresenter.show(
            layout: layout,
            initialStatus: status(for: session, resolution: nil, message: message, tone: .success),
            onEscape: { [weak self] in
                self?.close()
            },
            onKeyboardCommand: { [weak self] capturedCommand in
                _ = self?.handleCapturedKeyboardCommand(capturedCommand)
            },
            onPresentationEvent: { _ in }
        )
    }

    /// 창은 전환됐지만 새 대상 snapshot을 만들지 못한 경우 이전 라벨을 즉시 제거한다.
    private func failRescanAndCloseStaleOverlay(reason: String) {
        AppLogger.overlay.info("window switch rescan failed reason=\(reason, privacy: .public)")
        overlayPresenter.updateStatus(
            OverlayInteractionStatus(message: content.overlayRescanFailedText, tone: .failure)
        )
        close()
    }

    private func status(
        for session: OverlaySessionState,
        resolution: QueryResolution?,
        message: String?,
        tone: OverlayInteractionStatus.Tone,
        phase: OverlayInteractionPhase? = nil,
        requiresSecondConfirm: Bool = false
    ) -> OverlayInteractionStatus {
        let activeScope = resolution?.scope ?? activeScope(for: session)
        let enterHint = activeScope == .windows
            ? content.enterActionSwitchWindow
            : content.enterActionClick

        // elements scope에서 gaze로 focus를 옮긴 경우(resolution == nil)만
        // 겨냥한 candidate의 element 이름을 status 요약에 주입한다.
        // labels/windows scope와 검색(resolution != nil) 경로는 영향받지 않는다.
        // 겨냥은 검색 매칭이 아니므로 matchCount를 올리지 않고
        // isGazeTargeting 플래그로 요약 문구를 분기한다.
        let gazeDisplayName = (resolution == nil && activeScope == .elements)
            ? gazeElementDisplayName(for: session)
            : nil

        return OverlayInteractionStatus(
            focusedLabel: labelText(for: session.focusEngine.focusedItemID, in: session),
            typedLabelBuffer: session.focusEngine.labelBuffer,
            queryBuffer: session.queryInput.buffer,
            activeScope: activeScope,
            pinnedScope: session.queryInput.pinnedScope,
            matchCount: resolution?.matchCount ?? 0,
            matchIndex: resolution.map { $0.matchIndex + 1 } ?? 0,
            focusedDisplayName: resolution?.focusedDisplayName ?? gazeDisplayName,
            isGazeTargeting: gazeDisplayName != nil,
            highlightFrame: resolution?.highlightFrame,
            enterActionHint: enterHint,
            windowMatchPreviews: windowMatchPreviews(for: session, activeScope: activeScope),
            message: message,
            tone: tone,
            phase: phase ?? interactionPhase(
                for: session,
                resolution: resolution,
                tone: tone,
                message: message
            ),
            requiresSecondConfirm: requiresSecondConfirm,
            hasExplicitFocus: session.focusOrigin.isExplicit
        )
    }

    private func interactionPhase(
        for session: OverlaySessionState,
        resolution: QueryResolution?,
        tone: OverlayInteractionStatus.Tone,
        message: String?
    ) -> OverlayInteractionPhase {
        if tone == .failure {
            return .failure
        }

        if let resolution {
            guard !session.queryInput.buffer.isEmpty else {
                return .idle
            }

            return resolution.matchCount > 0 ? .matching : .noMatches
        }

        if !session.focusEngine.labelBuffer.isEmpty {
            return session.focusEngine.focusedItemID == nil ? .typing : .matching
        }

        if message == content.overlayFocusedText {
            return .matching
        }

        return .idle
    }

    private func windowMatchPreviews(
        for session: OverlaySessionState,
        activeScope: QueryScope
    ) -> [OverlayWindowMatchPreview] {
        guard activeScope == .windows, !session.windowMatches.isEmpty else {
            return []
        }

        let indices = windowMatchPreviewIndices(
            selectedIndex: session.windowMatchIndex,
            matchCount: session.windowMatches.count
        )
        return indices.compactMap { index in
            guard session.windowMatches.indices.contains(index),
                  let entry = session.windowIndex?.entry(id: session.windowMatches[index].entryID) else {
                return nil
            }

            return OverlayWindowMatchPreview(
                id: entry.id,
                appName: entry.appName,
                displayName: session.windowMatches[index].displayLine,
                ordinal: index + 1,
                isFocused: index == session.windowMatchIndex,
                appIcon: entry.appIcon
            )
        }
    }

    private func windowMatchPreviewIndices(selectedIndex: Int, matchCount: Int) -> Range<Int> {
        guard matchCount > Self.maxWindowMatchPreviewCount else {
            return 0..<matchCount
        }

        let halfWindow = Self.maxWindowMatchPreviewCount / 2
        let clampedSelectedIndex = min(max(0, selectedIndex), matchCount - 1)
        let lowerBound = min(
            max(0, clampedSelectedIndex - halfWindow),
            matchCount - Self.maxWindowMatchPreviewCount
        )
        return lowerBound..<(lowerBound + Self.maxWindowMatchPreviewCount)
    }

    /// elements scope gaze 겨냥 시 focus된 candidate의 element 이름.
    ///
    /// gaze 겨냥 대상은 `layout.labels`(= `scanResult.candidates`, 1:1)이며
    /// `label.id == candidate index`이므로 `focusedItemID`로 직접 조회한다.
    private func gazeElementDisplayName(for session: OverlaySessionState) -> String? {
        guard let focusedItemID = session.focusEngine.focusedItemID,
              focusedItemID >= 0,
              session.snapshot.scanResult.candidates.indices.contains(focusedItemID) else {
            return nil
        }

        let candidate = session.snapshot.scanResult.candidates[focusedItemID]
        return candidate.displayName(index: focusedItemID)
    }

    /// 새 resolution이 없을 때(예: gaze)의 현재 활성 scope.
    /// pin이 있으면 pin을, 없으면 마지막으로 해석된 scope를 쓴다.
    private func activeScope(for session: OverlaySessionState) -> QueryScope {
        session.queryInput.pinnedScope ?? session.queryInput.lastScope
    }

    private func focusedMessage(for session: OverlaySessionState) -> String? {
        guard labelText(for: session.focusEngine.focusedItemID, in: session) != nil else {
            return nil
        }

        return content.overlayFocusedText
    }

    private func feedback(
        for typingResult: LabelTypingResult,
        typedCharacter: Character,
        session: OverlaySessionState
    ) -> (message: String?, tone: OverlayInteractionStatus.Tone) {
        if typingResult.isExactMatch,
           labelText(for: typingResult.matchedItemID, in: session) != nil {
            return (content.overlayFocusedText, .success)
        }

        if !typingResult.buffer.isEmpty {
            return (content.overlayTypingText(typingResult.buffer), .neutral)
        }

        let typedLabel = String(typedCharacter).uppercased()
        return (content.overlayNoLabelText(typedLabel), .failure)
    }

    private func labelText(for focusedItemID: Int?, in session: OverlaySessionState) -> String? {
        guard let focusedItemID else {
            return nil
        }

        return session.snapshot.layout.labels.first { $0.id == focusedItemID }?.text
    }

    private func clickRisk(
        for result: Result<ClickExecutionSuccess, OverlaySessionClickFailure>
    ) -> ClickRiskClass {
        switch result {
        case .success(let success):
            success.riskClass
        case .failure(.executionFailed(.secondConfirmRequired(let riskClass))):
            riskClass
        case .failure:
            .unknownRisk
        }
    }

    private func shouldRecordClickCompleted(
        for result: Result<ClickExecutionSuccess, OverlaySessionClickFailure>
    ) -> Bool {
        switch result {
        case .success:
            true
        case .failure(.executionFailed(.secondConfirmRequired)):
            false
        case .failure:
            true
        }
    }

    private static func milliseconds(from start: Date, to end: Date) -> Int {
        max(0, Int((end.timeIntervalSince(start) * 1_000).rounded()))
    }

    private func trace(
        _ phase: OverlayActivationPhase,
        activationID: UUID,
        at date: Date,
        metadata: OverlayActivationTraceMetadata = OverlayActivationTraceMetadata()
    ) {
        activationTracer.mark(
            phase,
            activationID: activationID,
            at: date,
            metadata: metadata
        )
    }

    private func traceKeyboardCommand(
        _ phase: OverlayActivationPhase,
        command: FocusKeyboardCommand,
        captureMode: OverlayKeyboardCaptureMode? = nil,
        hasActiveSession: Bool? = nil
    ) {
        guard let activeActivationID else {
            return
        }

        trace(
            phase,
            activationID: activeActivationID,
            at: dateProvider(),
            metadata: OverlayActivationTraceMetadata(
                commandKind: commandKind(for: command),
                captureMode: captureMode?.rawValue,
                hasActiveSession: hasActiveSession ?? (activeSession != nil)
            )
        )
    }

    private func tracePresentationEvent(
        _ event: OverlayPresentationEvent,
        activationID: UUID
    ) {
        let phase: OverlayActivationPhase
        let metadata: OverlayActivationTraceMetadata
        switch event {
        case .captureReady(let captureMode):
            phase = .captureReady
            metadata = OverlayActivationTraceMetadata(captureMode: captureMode.rawValue)
        case .panelsOrdered:
            phase = .panelsOrdered
            metadata = OverlayActivationTraceMetadata()
        case .firstDisplayPass:
            phase = .firstDisplayPass
            metadata = OverlayActivationTraceMetadata()
        }

        trace(phase, activationID: activationID, at: dateProvider(), metadata: metadata)
    }

    private func commandKind(for command: FocusKeyboardCommand) -> String {
        switch command {
        case .move:
            "move"
        case .typeLabel:
            "type_label"
        case .appendQuery:
            "append_query"
        case .deleteQueryCharacter:
            "delete_query_character"
        case .clearQueryBuffer:
            "clear_query_buffer"
        case .clearLabelBuffer:
            "clear_label_buffer"
        case .pinScope:
            "pin_scope"
        case .selectScope:
            "select_scope"
        case .cycleMatch:
            "cycle_match"
        case .dryRunConfirm:
            "confirm"
        case .closeOverlay:
            "close_overlay"
        }
    }
}

/// overlay session target resolve abstraction.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
protocol OverlaySessionTargetResolving {
    func resolve() -> Result<TargetContext, TargetResolutionFailure>
}

extension TargetResolver: OverlaySessionTargetResolving {}

/// overlay session scan abstraction.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
protocol OverlaySessionScanning {
    func scan(context: TargetContext) -> Result<AccessibilityScanResult, AccessibilityScanFailure>

    /// scan cache를 무효화한다. cache를 갖지 않는 scanner는 무효화할 상태가 없다.
    func invalidate()
}

extension OverlaySessionScanning {
    /// 기본 구현은 no-op이다. `CachingScanner`처럼 cache를 가진 scanner만 재정의한다.
    func invalidate() {}
}

/// 부분 scan 결과를 전달할 수 있는 overlay scanner abstraction.
@MainActor
protocol OverlaySessionProgressiveScanning: OverlaySessionScanning {
    func scanProgressively(
        context: TargetContext,
        onProgress: @escaping (AccessibilityScanProgress) -> Void
    ) async -> Result<AccessibilityScanResult, AccessibilityScanFailure>
}

extension AccessibilityScanner: OverlaySessionScanning {}
extension AccessibilityScanner: OverlaySessionProgressiveScanning {}

/// overlay 표시 abstraction.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
protocol OverlaySessionPresenting {
    func makeLayout(
        targetFrame: CGRect,
        candidates: [ClickableCandidate],
        labels: [String]
    ) -> OverlayLayout

    @discardableResult
    func show(
        layout: OverlayLayout,
        initialStatus: OverlayInteractionStatus,
        onEscape: @escaping () -> Void,
        onKeyboardCommand: @MainActor @escaping (OverlayCapturedKeyboardCommand) -> Void,
        onPresentationEvent: @MainActor @escaping (OverlayPresentationEvent) -> Void
    ) -> OverlayKeyboardCaptureMode

    func close()

    func updateFocus(focusedLabelID: Int?)

    func updateStatus(_ status: OverlayInteractionStatus)
}

/// overlay keyboard capture 경로.
///
/// @author suho.do
/// @since 2026-07-13
enum OverlayKeyboardCaptureMode: String, Equatable {
    case eventTap = "event_tap"
    case panelFallback = "panel_fallback"
}

/// capture 경로를 보존한 overlay keyboard command.
///
/// @author suho.do
/// @since 2026-07-13
struct OverlayCapturedKeyboardCommand: Equatable {
    let command: FocusKeyboardCommand
    let captureMode: OverlayKeyboardCaptureMode
}

/// overlay panel 공개 lifecycle event.
///
/// @author suho.do
/// @since 2026-07-13
enum OverlayPresentationEvent: Equatable {
    case captureReady(OverlayKeyboardCaptureMode)
    case panelsOrdered
    case firstDisplayPass
}

extension OverlayWindowController: OverlaySessionPresenting {}

/// overlay session interaction event recording abstraction.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
protocol OverlaySessionInteractionRecording {
    func record(_ event: InteractionEvent)
}

extension InteractionLogStore: OverlaySessionInteractionRecording {}

/// overlay session activation 성공 snapshot.
///
/// @author suho.do
/// @since 2026-07-02
struct OverlaySessionSnapshot: Equatable {
    let context: TargetContext
    let scanResult: AccessibilityScanResult
    let layout: OverlayLayout
}

/// overlay session의 runtime 상태.
///
/// @author suho.do
/// @since 2026-07-02
struct OverlaySessionState: Equatable {
    let snapshot: OverlaySessionSnapshot
    var focusEngine: FocusEngine
    var queryInput: QueryInputState = QueryInputState()
    var elementIndex: ElementSearchIndex = ElementSearchIndex(nodes: [])
    var didAttemptSearchableIndexBuild = false
    var elementMatches: [SearchMatch] = []
    var elementMatchIndex: Int = 0
    var windowIndex: WindowSearchIndex?
    var windowMatches: [WindowMatch] = []
    var windowMatchIndex: Int = 0
    var pendingSecondConfirm: PendingSecondConfirm?
    var focusOrigin: OverlayFocusOrigin = .initial
    /// 부분 후보 overlay가 최종 scan 결과를 기다리는 동안 입력과 click을 막는다.
    var isScanInProgress = false
}

/// 위험 click second confirm 대기 상태.
///
/// @author suho.do
/// @since 2026-07-02
struct PendingSecondConfirm: Equatable {
    let focusedItemID: Int
    let riskClass: ClickRiskClass
    let createdAt: Date

    init(
        focusedItemID: Int,
        riskClass: ClickRiskClass,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.focusedItemID = focusedItemID
        self.riskClass = riskClass
        self.createdAt = createdAt
    }

    func isValid(
        for focusedItemID: Int,
        at date: Date,
        timeout: TimeInterval
    ) -> Bool {
        self.focusedItemID == focusedItemID
            && date.timeIntervalSince(createdAt) <= timeout
    }
}

/// overlay session activation 결과.
///
/// @author suho.do
/// @since 2026-07-02
enum OverlaySessionStartResult: Equatable {
    case success(OverlaySessionSnapshot)
    case failure(OverlaySessionStartFailure)
}

/// overlay session activation 실패 사유.
///
/// @author suho.do
/// @since 2026-07-02
enum OverlaySessionStartFailure: Equatable {
    case sessionDisabled
    case targetResolutionFailed(TargetResolutionFailure)
    case scanFailed(AccessibilityScanFailure)
    case noCandidates(context: TargetContext, scanResult: AccessibilityScanResult)

    var requiresAccessibilityPermission: Bool {
        switch self {
        case .targetResolutionFailed(.accessibilityPermissionDenied),
             .scanFailed(.accessibilityPermissionDenied):
            true
        case .sessionDisabled,
             .targetResolutionFailed,
             .scanFailed,
             .noCandidates:
            false
        }
    }

    var logCode: String {
        switch self {
        case .sessionDisabled:
            "session_disabled"
        case .targetResolutionFailed(let failure):
            "target_resolution_failed.\(failure.logCode)"
        case .scanFailed(let failure):
            "scan_failed.\(failure.logCode)"
        case .noCandidates:
            "no_candidates"
        }
    }
}

private extension FocusChangeMethod {
    var logCode: String {
        switch self {
        case .initial:
            "initial"
        case .tab:
            "tab"
        case .shiftTab:
            "shiftTab"
        case .arrowUp:
            "arrowUp"
        case .arrowDown:
            "arrowDown"
        case .labelJump:
            "labelJump"
        case .gaze:
            "gaze"
        }
    }
}

private extension ClickRiskClass {
    var logCode: String {
        switch self {
        case .safeNavigation:
            "safeNavigation"
        case .stateChange:
            "stateChange"
        case .destructive:
            "destructive"
        case .externalEffect:
            "externalEffect"
        case .unknownRisk:
            "unknownRisk"
        }
    }
}

private extension ClickExecutionMethod {
    var logCode: String {
        switch self {
        case .axPress:
            "axPress"
        case .accessibilityAction(let action):
            "accessibilityAction.\(action)"
        case .axFocus:
            "axFocus"
        case .coordinateFallback:
            "coordinateFallback"
        }
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}

private extension OverlaySessionClickFailure {
    var isTargetMismatch: Bool {
        switch self {
        case .selectedTargetUnavailable, .selectedTargetChanged, .selectedTargetAmbiguous:
            true
        case .scanFailed, .missingFocusedTarget, .executionFailed:
            false
        }
    }
}

private extension TargetResolutionFailure {
    var logCode: String {
        switch self {
        case .noFrontmostApplication:
            "no_frontmost_application"
        case .invalidProcessIdentifier:
            "invalid_process_identifier"
        case .accessibilityPermissionDenied:
            "accessibility_permission_denied"
        case .focusedWindowUnavailable:
            "focused_window_unavailable"
        case .windowFrameUnavailable:
            "window_frame_unavailable"
        case .invalidWindowFrame:
            "invalid_window_frame"
        }
    }
}

private extension AccessibilityScanFailure {
    var logCode: String {
        switch self {
        case .accessibilityPermissionDenied:
            "accessibility_permission_denied"
        case .focusedWindowUnavailable:
            "focused_window_unavailable"
        case .childrenUnavailable:
            "children_unavailable"
        case .cancelled:
            "cancelled"
        }
    }
}
