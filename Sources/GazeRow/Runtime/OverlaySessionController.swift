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
    private let isSessionEnabled: () -> Bool
    private let clickResultObserver: @MainActor (Result<ClickExecutionSuccess, OverlaySessionClickFailure>) -> Void
    private(set) var activeSession: OverlaySessionState?
    private(set) var lastClickResult: Result<ClickExecutionSuccess, OverlaySessionClickFailure>?

    init(
        targetResolver: any OverlaySessionTargetResolving = TargetResolver(),
        scanner: any OverlaySessionScanning = CachingScanner(
            wrapped: AccessibilityScanner(client: AXAccessibilityElementClient())
        ),
        overlayPresenter: any OverlaySessionPresenting = OverlayWindowController(),
        interactionRecorder: any OverlaySessionInteractionRecording = InteractionLogStore(),
        clickExecutor: any OverlaySessionClickExecuting = AXOverlaySessionClickExecutor(),
        searchableNodeCollector: (any SearchableNodeCollecting)? = AccessibilitySearchableNodeCollector(client: AXAccessibilityElementClient()),
        intentRouter: IntentRouter = IntentRouter(),
        windowSearchIndexProvider: @escaping () -> WindowSearchIndex = { WindowSearchIndex.build() },
        windowActivator: any WindowActivating = WindowActivator(),
        windowTitleHasher: WindowTitleHasher = WindowTitleHasher(salt: SessionSalt()),
        dateProvider: @escaping () -> Date = Date.init,
        isSessionEnabled: @escaping () -> Bool = { SessionController.shared.isEnabled },
        clickResultObserver: @escaping @MainActor (Result<ClickExecutionSuccess, OverlaySessionClickFailure>) -> Void = { _ in }
    ) {
        self.targetResolver = targetResolver
        self.scanner = scanner
        self.overlayPresenter = overlayPresenter
        self.interactionRecorder = interactionRecorder
        self.clickExecutor = clickExecutor
        self.searchableNodeCollector = searchableNodeCollector
        self.intentRouter = intentRouter
        self.windowSearchIndexProvider = windowSearchIndexProvider
        self.windowActivator = windowActivator
        self.windowTitleHasher = windowTitleHasher
        self.dateProvider = dateProvider
        self.isSessionEnabled = isSessionEnabled
        self.clickResultObserver = clickResultObserver
    }

    func start() -> OverlaySessionStartResult {
        lastClickResult = nil

        guard isSessionEnabled() else {
            close()
            return .failure(.sessionDisabled)
        }

        let startedAt = dateProvider()
        let context: TargetContext
        switch targetResolver.resolve() {
        case .success(let resolvedContext):
            context = resolvedContext
        case .failure(let failure):
            close()
            return .failure(.targetResolutionFailed(failure))
        }
        let targetResolvedAt = dateProvider()

        let scanResult: AccessibilityScanResult
        switch scanner.scan(context: context) {
        case .success(let result):
            scanResult = result
        case .failure(let failure):
            close()
            return .failure(.scanFailed(failure))
        }
        let scannedAt = dateProvider()

        guard !scanResult.candidates.isEmpty else {
            close()
            return .failure(.noCandidates(context: context, scanResult: scanResult))
        }

        let layout = overlayPresenter.show(
            targetFrame: context.window.frame,
            candidates: scanResult.candidates,
            labels: [],
            onEscape: { [weak self] in
                self?.close()
            },
            onKeyboardCommand: { [weak self] command in
                _ = self?.handleKeyboardCommand(command)
            },
            onScopeSelection: { [weak self] scope in
                _ = self?.handleKeyboardCommand(.selectScope(scope))
            }
        )
        let shownAt = dateProvider()

        let snapshot = OverlaySessionSnapshot(
            context: context,
            scanResult: scanResult,
            layout: layout
        )
        let elementIndex = buildElementIndex(context: context, scanResult: scanResult)
        let windowIndex = windowSearchIndexProvider()
        activeSession = OverlaySessionState(
            snapshot: snapshot,
            focusEngine: FocusEngine(layout: layout),
            elementIndex: elementIndex,
            windowIndex: windowIndex
        )
        let labelMap = zip(layout.labels, scanResult.candidates).prefix(14).map { label, candidate in
            "\(label.id):\(label.text)@(\(Int(candidate.frame.minX)),\(Int(candidate.frame.minY)) \(Int(candidate.frame.width))x\(Int(candidate.frame.height)))"
        }.joined(separator: " ")
        AppLogger.interaction.info(
            "overlay candidates count=\(layout.labels.count, privacy: .public) map=\(labelMap, privacy: .public)"
        )
        AppLogger.overlay.info(
            "overlay start timing targetMs=\(Self.milliseconds(from: startedAt, to: targetResolvedAt), privacy: .public) scanMs=\(Self.milliseconds(from: targetResolvedAt, to: scannedAt), privacy: .public) showMs=\(Self.milliseconds(from: scannedAt, to: shownAt), privacy: .public) totalMs=\(Self.milliseconds(from: startedAt, to: shownAt), privacy: .public) nodes=\(scanResult.nodesVisited, privacy: .public) candidates=\(scanResult.candidateCount, privacy: .public) timeout=\(scanResult.didTimeout, privacy: .public)"
        )
        if let activeSession {
            updateOverlayStatus(for: activeSession, message: "Ready", tone: .neutral)
        }

        return .success(snapshot)
    }

    func handleKeyboardCommand(_ command: FocusKeyboardCommand) -> FocusEngineEvent? {
        guard var session = activeSession else {
            return nil
        }

        let event: FocusEngineEvent?
        var statusMessage: String?
        var statusTone = OverlayInteractionStatus.Tone.neutral
        switch command {
        case .move(let moveCommand):
            session.pendingSecondConfirm = nil
            event = session.focusEngine.move(moveCommand)
            session.queryInput.lastScope = .labels
            statusMessage = focusedMessage(for: session)
        case .typeLabel(let character):
            session.pendingSecondConfirm = nil
            let typingResult = session.focusEngine.typeLabelCharacter(character)
            session.queryInput.lastScope = .labels
            event = typingResult.event
            let feedback = feedback(for: typingResult, typedCharacter: character, session: session)
            statusMessage = feedback.message
            statusTone = feedback.tone
        case .appendQuery(let grapheme):
            session.pendingSecondConfirm = nil
            appendQuery(grapheme, to: &session)
            session.queryInput.lastScope = session.queryInput.pinnedScope ?? .elements
            let resolution = applyQueryResolution(to: &session)
            activeSession = session
            overlayPresenter.updateStatus(status(for: session, resolution: resolution, message: nil, tone: .neutral))
            return nil
        case .deleteQueryCharacter:
            session.pendingSecondConfirm = nil
            if !session.queryInput.buffer.isEmpty {
                session.queryInput.buffer.removeLast()
            } else {
                session.focusEngine.clearLabelBuffer()
            }
            if !session.queryInput.buffer.isEmpty {
                let resolution = applyQueryResolution(to: &session)
                activeSession = session
                overlayPresenter.updateStatus(status(for: session, resolution: resolution, message: nil, tone: .neutral))
                return nil
            }
            event = nil
            statusMessage = "Input cleared"
        case .clearQueryBuffer:
            session.pendingSecondConfirm = nil
            session.queryInput = QueryInputState(lastScope: session.queryInput.lastScope)
            session.focusEngine.clearLabelBuffer()
            session.elementMatches = []
            session.elementMatchIndex = 0
            event = nil
            statusMessage = "Input cleared"
        case .clearLabelBuffer:
            session.pendingSecondConfirm = nil
            session.focusEngine.clearLabelBuffer()
            session.queryInput.buffer = ""
            session.queryInput.pinnedScope = nil
            event = nil
            statusMessage = "Input cleared"
        case .pinScope(let scope):
            session.pendingSecondConfirm = nil
            session.queryInput.pinnedScope = scope
            session.queryInput.lastScope = scope
            refreshWindowIndexIfNeeded(session: &session)
            event = nil
            statusMessage = "Pinned \(scope.rawValue)"
        case .selectScope(let scope):
            session.pendingSecondConfirm = nil
            selectScope(scope, session: &session)
            if session.queryInput.buffer.isEmpty {
                event = nil
                statusMessage = scope == .labels ? "Labels" : "Pinned \(scope.rawValue)"
            } else {
                let resolution = applyQueryResolution(to: &session)
                activeSession = session
                overlayPresenter.updateStatus(status(for: session, resolution: resolution, message: nil, tone: .neutral))
                return nil
            }
        case .cycleMatch(let forward):
            session.pendingSecondConfirm = nil
            if shouldCycleQueryMatches(session, scope: .elements) {
                cycleElementMatch(forward: forward, session: &session)
                let resolution = applyQueryResolution(to: &session)
                activeSession = session
                overlayPresenter.updateStatus(status(for: session, resolution: resolution, message: nil, tone: .neutral))
                return nil
            } else if shouldCycleQueryMatches(session, scope: .windows) {
                cycleWindowMatch(forward: forward, session: &session)
                let resolution = applyQueryResolution(to: &session)
                activeSession = session
                overlayPresenter.updateStatus(status(for: session, resolution: resolution, message: nil, tone: .neutral))
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

        let event = session.focusEngine.focusNearest(to: gazePoint)
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
                OverlayInteractionStatus(
                    typedLabelBuffer: session.focusEngine.labelBuffer,
                    message: result.statusText,
                    tone: .failure
                )
            )
            return
        }

        let isSecondConfirmProvided = session.pendingSecondConfirm?.focusedItemID == focusedItemID
        overlayPresenter.setMouseInputEnabled(false)
        let result = clickExecutor.execute(
            focusedIndex: focusedItemID,
            context: session.snapshot.context,
            isSecondConfirmProvided: isSecondConfirmProvided
        )
        AppLogger.interaction.info(
            "confirm click executed index=\(focusedItemID, privacy: .public) result=\(String(describing: result), privacy: .public)"
        )
        let focusedLabel = labelText(for: focusedItemID, in: session)
        lastClickResult = result
        clickResultObserver(result)
        recordClick(result: result, context: session.snapshot.context)

        switch result {
        case .success:
            overlayPresenter.updateStatus(
                OverlayInteractionStatus(
                    focusedLabel: focusedLabel,
                    message: "Clicked",
                    tone: .success
                )
            )
            // 클릭 성공은 target UI를 바꿀 수 있어 다음 activation에서 stale
            // candidate가 재사용되지 않도록 scan cache를 무효화한다.
            scanner.invalidate()
            close()
        case .failure(.executionFailed(.secondConfirmRequired(let riskClass))):
            overlayPresenter.setMouseInputEnabled(true)
            session.pendingSecondConfirm = PendingSecondConfirm(
                focusedItemID: focusedItemID,
                riskClass: riskClass
            )
            activeSession = session
            overlayPresenter.updateStatus(
                OverlayInteractionStatus(
                    focusedLabel: focusedLabel,
                    typedLabelBuffer: session.focusEngine.labelBuffer,
                    message: "Press Return again for \(riskClass.statusText)",
                    tone: .warning
                )
            )
        case .failure:
            overlayPresenter.setMouseInputEnabled(true)
            session.pendingSecondConfirm = nil
            activeSession = session
            overlayPresenter.updateStatus(
                OverlayInteractionStatus(
                    focusedLabel: focusedLabel,
                    typedLabelBuffer: session.focusEngine.labelBuffer,
                    message: result.statusText,
                    tone: .failure
                )
            )
        }
    }

    func close() {
        overlayPresenter.close()
        activeSession = nil
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
            record(
                kind: .clickCompleted(
                    risk: risk.logCode,
                    success: result.isSuccess
                ),
                context: context
            )
        }
    }

    private func record(kind: InteractionEventKind, context: TargetContext) {
        interactionRecorder.record(
            InteractionEvent(
                timestamp: dateProvider(),
                kind: kind,
                windowTitleHash: windowTitleHasher.hash(context.window.title)
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

    private func buildElementIndex(
        context: TargetContext,
        scanResult: AccessibilityScanResult
    ) -> ElementSearchIndex {
        if let searchableNodeCollector {
            let collectedIndex = searchableNodeCollector.buildIndex(context: context)
            if !collectedIndex.nodes.isEmpty {
                return collectedIndex
            }
        }

        return ElementSearchIndex(
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

    private func appendQuery(_ grapheme: String, to session: inout OverlaySessionState) {
        if session.queryInput.buffer.isEmpty || grapheme.count > 1 {
            session.queryInput.buffer = grapheme
        } else {
            session.queryInput.buffer.append(grapheme)
        }
    }

    @discardableResult
    private func applyQueryResolution(to session: inout OverlaySessionState) -> QueryResolution {
        session.elementMatches = session.elementIndex.search(session.queryInput.buffer)
        session.windowMatches = session.windowIndex.search(session.queryInput.buffer)
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
            windowIndex: session.windowIndex,
            windowMatchIndex: session.windowMatchIndex
        )
        session.queryInput.lastScope = resolution.scope
        if let focusTargetCandidateIndex = resolution.focusTargetCandidateIndex {
            _ = session.focusEngine.focusItem(id: focusTargetCandidateIndex)
        } else if resolution.scope == .elements {
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

    private func refreshWindowIndexIfNeeded(session: inout OverlaySessionState) {
        guard session.queryInput.pinnedScope == .windows || session.queryInput.lastScope == .windows else {
            return
        }

        if session.windowIndex.isStale() {
            session.windowIndex = windowSearchIndexProvider()
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
            refreshWindowIndexIfNeeded(session: &session)
        }
    }

    private func activateFocusedWindow(session: inout OverlaySessionState) {
        let resolution = applyQueryResolution(to: &session)
        guard let entryID = resolution.windowEntryID,
              let entry = session.windowIndex.entry(id: entryID) else {
            activeSession = session
            overlayPresenter.updateStatus(
                status(for: session, resolution: resolution, message: "Window not found", tone: .failure)
            )
            return
        }

        switch windowActivator.activate(entry) {
        case .success:
            rescanFrontmost(message: "\(entry.appName) activated")
        case .failure:
            activeSession = session
            overlayPresenter.updateStatus(
                status(for: session, resolution: resolution, message: "Window activation failed", tone: .failure)
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
            overlayPresenter.updateStatus(OverlayInteractionStatus(message: "Rescan failed", tone: .failure))
            return
        }

        let scanResult: AccessibilityScanResult
        switch scanner.scan(context: context) {
        case .success(let result):
            scanResult = result
        case .failure:
            overlayPresenter.updateStatus(OverlayInteractionStatus(message: "Rescan failed", tone: .failure))
            return
        }

        let layout = overlayPresenter.show(
            targetFrame: context.window.frame,
            candidates: scanResult.candidates,
            labels: [],
            onEscape: { [weak self] in
                self?.close()
            },
            onKeyboardCommand: { [weak self] command in
                _ = self?.handleKeyboardCommand(command)
            },
            onScopeSelection: { [weak self] scope in
                _ = self?.handleKeyboardCommand(.selectScope(scope))
            }
        )
        let snapshot = OverlaySessionSnapshot(context: context, scanResult: scanResult, layout: layout)
        let session = OverlaySessionState(
            snapshot: snapshot,
            focusEngine: FocusEngine(layout: layout),
            queryInput: QueryInputState(lastScope: .elements),
            elementIndex: buildElementIndex(context: context, scanResult: scanResult),
            windowIndex: windowSearchIndexProvider()
        )
        activeSession = session
        updateOverlayStatus(for: session, message: message, tone: .success)
    }

    private func status(
        for session: OverlaySessionState,
        resolution: QueryResolution?,
        message: String?,
        tone: OverlayInteractionStatus.Tone
    ) -> OverlayInteractionStatus {
        let activeScope = resolution?.scope ?? session.queryInput.pinnedScope ?? session.queryInput.lastScope
        let enterHint = activeScope == .windows
            ? AppContent.localized(for: .english).enterActionSwitchWindow
            : AppContent.localized(for: .english).enterActionClick

        return OverlayInteractionStatus(
            focusedLabel: labelText(for: session.focusEngine.focusedItemID, in: session),
            typedLabelBuffer: session.focusEngine.labelBuffer,
            queryBuffer: session.queryInput.buffer,
            activeScope: activeScope,
            pinnedScope: session.queryInput.pinnedScope,
            matchCount: resolution?.matchCount ?? 0,
            matchIndex: resolution.map { $0.matchIndex + 1 } ?? 0,
            focusedDisplayName: resolution?.focusedDisplayName,
            enterActionHint: enterHint,
            message: message,
            tone: tone
        )
    }

    private func focusedMessage(for session: OverlaySessionState) -> String? {
        guard labelText(for: session.focusEngine.focusedItemID, in: session) != nil else {
            return nil
        }

        return "Focused"
    }

    private func feedback(
        for typingResult: LabelTypingResult,
        typedCharacter: Character,
        session: OverlaySessionState
    ) -> (message: String?, tone: OverlayInteractionStatus.Tone) {
        if typingResult.isExactMatch,
           labelText(for: typingResult.matchedItemID, in: session) != nil {
            return ("Focused", .success)
        }

        if !typingResult.buffer.isEmpty {
            return ("Typing \(typingResult.buffer)", .neutral)
        }

        let typedLabel = String(typedCharacter).uppercased()
        return ("No label \(typedLabel)", .failure)
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

extension AccessibilityScanner: OverlaySessionScanning {}

/// overlay 표시 abstraction.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
protocol OverlaySessionPresenting {
    @discardableResult
    func show(
        targetFrame: CGRect,
        candidates: [ClickableCandidate],
        labels: [String],
        onEscape: @escaping () -> Void,
        onKeyboardCommand: @MainActor @escaping (FocusKeyboardCommand) -> Void,
        onScopeSelection: @MainActor @escaping (QueryScope) -> Void
    ) -> OverlayLayout

    func close()

    func updateFocus(focusedLabelID: Int?)

    func updateStatus(_ status: OverlayInteractionStatus)

    func setMouseInputEnabled(_ isEnabled: Bool)
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
    var elementMatches: [SearchMatch] = []
    var elementMatchIndex: Int = 0
    var windowIndex: WindowSearchIndex = WindowSearchIndex(entries: [])
    var windowMatches: [WindowMatch] = []
    var windowMatchIndex: Int = 0
    var pendingSecondConfirm: PendingSecondConfirm?
}

/// 위험 click second confirm 대기 상태.
///
/// @author suho.do
/// @since 2026-07-02
struct PendingSecondConfirm: Equatable {
    let focusedItemID: Int
    let riskClass: ClickRiskClass
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

    var statusText: String {
        switch self {
        case .safeNavigation:
            "safe action"
        case .stateChange:
            "state change"
        case .destructive:
            "destructive action"
        case .externalEffect:
            "external action"
        case .unknownRisk:
            "unknown action"
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

private extension Result where Success == ClickExecutionSuccess, Failure == OverlaySessionClickFailure {
    var statusText: String {
        switch self {
        case .success:
            "Click succeeded"
        case .failure(let failure):
            failure.statusText
        }
    }
}

private extension OverlaySessionClickFailure {
    var statusText: String {
        switch self {
        case .scanFailed:
            "Click failed: target changed"
        case .missingFocusedTarget:
            "Click failed: no focused target"
        case .executionFailed(let failure):
            failure.statusText
        }
    }
}

private extension ClickExecutionFailure {
    var statusText: String {
        switch self {
        case .missingPressAction:
            "Click failed: no supported action"
        case .secondConfirmRequired(let riskClass):
            "Press Return again for \(riskClass.statusText)"
        case .axPressFailed:
            "Click failed: accessibility action failed"
        case .coordinateFallbackDisabled:
            "Click failed: coordinate fallback is off"
        case .coordinateFallbackFailed:
            "Click failed: coordinate fallback failed"
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
        }
    }
}
