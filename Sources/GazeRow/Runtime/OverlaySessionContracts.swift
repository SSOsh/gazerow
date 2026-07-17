import CoreGraphics
import Foundation

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

/// label 후보와 element index를 동일 AX walk에서 반환하는 scanner abstraction.
@MainActor
protocol OverlaySessionBundleProgressiveScanning: OverlaySessionProgressiveScanning {
    func scanBundleProgressively(
        context: TargetContext,
        onProgress: @escaping (AccessibilityScanProgress) -> Void
    ) async -> Result<AccessibilityScanBundle, AccessibilityScanFailure>
}

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
