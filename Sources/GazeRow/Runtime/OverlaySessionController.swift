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
    private let windowTitleHasher: WindowTitleHasher
    private let dateProvider: () -> Date
    private let isSessionEnabled: () -> Bool
    private(set) var activeSession: OverlaySessionState?
    private(set) var lastClickResult: Result<ClickExecutionSuccess, OverlaySessionClickFailure>?

    init(
        targetResolver: any OverlaySessionTargetResolving = TargetResolver(),
        scanner: any OverlaySessionScanning = AccessibilityScanner(client: AXAccessibilityElementClient()),
        overlayPresenter: any OverlaySessionPresenting = OverlayWindowController(),
        interactionRecorder: any OverlaySessionInteractionRecording = InteractionLogStore(),
        clickExecutor: any OverlaySessionClickExecuting = AXOverlaySessionClickExecutor(),
        windowTitleHasher: WindowTitleHasher = WindowTitleHasher(salt: SessionSalt()),
        dateProvider: @escaping () -> Date = Date.init,
        isSessionEnabled: @escaping () -> Bool = { SessionController.shared.isEnabled }
    ) {
        self.targetResolver = targetResolver
        self.scanner = scanner
        self.overlayPresenter = overlayPresenter
        self.interactionRecorder = interactionRecorder
        self.clickExecutor = clickExecutor
        self.windowTitleHasher = windowTitleHasher
        self.dateProvider = dateProvider
        self.isSessionEnabled = isSessionEnabled
    }

    func start() -> OverlaySessionStartResult {
        lastClickResult = nil

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

        let scanResult: AccessibilityScanResult
        switch scanner.scan(context: context) {
        case .success(let result):
            scanResult = result
        case .failure(let failure):
            close()
            return .failure(.scanFailed(failure))
        }

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
            }
        )

        let snapshot = OverlaySessionSnapshot(
            context: context,
            scanResult: scanResult,
            layout: layout
        )
        activeSession = OverlaySessionState(
            snapshot: snapshot,
            focusEngine: FocusEngine(layout: layout)
        )
        overlayPresenter.updateFocus(focusedLabelID: activeSession?.focusEngine.focusedItemID)

        return .success(snapshot)
    }

    func handleKeyboardCommand(_ command: FocusKeyboardCommand) -> FocusEngineEvent? {
        guard var session = activeSession else {
            return nil
        }

        let event: FocusEngineEvent?
        switch command {
        case .move(let moveCommand):
            event = session.focusEngine.move(moveCommand)
        case .typeLabel(let character):
            event = session.focusEngine.typeLabelCharacter(character).event
        case .clearLabelBuffer:
            session.focusEngine.clearLabelBuffer()
            event = nil
        case .dryRunConfirm:
            let confirmResult = session.focusEngine.dryRunConfirm()
            activeSession = session
            executeClickIfPossible(confirmResult: confirmResult, context: session.snapshot.context)
            return confirmResult.event
        case .closeOverlay:
            close()
            return nil
        }

        activeSession = session
        overlayPresenter.updateFocus(focusedLabelID: session.focusEngine.focusedItemID)
        record(event, context: session.snapshot.context)
        return event
    }

    private func executeClickIfPossible(
        confirmResult: DryRunConfirmResult,
        context: TargetContext
    ) {
        guard let focusedItemID = confirmResult.focusedItemID else {
            lastClickResult = .failure(.missingFocusedTarget(index: -1))
            return
        }

        let result = clickExecutor.execute(
            focusedIndex: focusedItemID,
            context: context,
            isSecondConfirmProvided: false
        )
        lastClickResult = result

        if case .success = result {
            close()
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
        onKeyboardCommand: @MainActor @escaping (FocusKeyboardCommand) -> Void
    ) -> OverlayLayout

    func close()

    func updateFocus(focusedLabelID: Int?)
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
