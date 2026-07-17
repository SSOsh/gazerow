import Foundation

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
    var targetDescriptors: [AccessibilityTargetDescriptor?] = []
    var generation: AccessibilityTreeGeneration = .initial
    var isChangeMonitoringActive = false
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
