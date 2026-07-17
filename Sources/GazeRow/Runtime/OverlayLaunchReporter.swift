import Foundation

/// 런치 옵션 기반 overlay smoke 결과를 stdout에 남기기 위한 formatter.
///
/// @author suho.do
/// @since 2026-07-02
enum OverlayLaunchReporter {

    static func starting(bundleIdentifier: String?) -> String {
        "GAZEROW_OVERLAY_RESULT starting bundle=\(bundleIdentifier ?? "<frontmost>")"
    }

    static func success(labelCount: Int) -> String {
        "GAZEROW_OVERLAY_RESULT success labels=\(labelCount)"
    }

    static func activationTrace(_ event: OverlayActivationTraceEvent) -> String {
        let metadata = event.metadata
        let nodes = metadata.nodesVisited.map(String.init) ?? "-"
        let candidates = metadata.candidateCount.map(String.init) ?? "-"
        let command = metadata.commandKind ?? "-"
        let capture = metadata.captureMode ?? "-"
        let session = metadata.hasActiveSession.map(String.init) ?? "-"
        let timeout = metadata.didTimeout.map(String.init) ?? "-"
        let nodeLimit = metadata.didHitNodeLimit.map(String.init) ?? "-"
        let depthLimit = metadata.didHitDepthLimit.map(String.init) ?? "-"
        let failedChildReads = metadata.failedChildReadCount.map(String.init) ?? "-"
        return [
            "GAZEROW_OVERLAY_TIMING",
            "phase=\(event.phase.rawValue)",
            "elapsed_ms=\(event.elapsedMilliseconds)",
            "nodes=\(nodes)",
            "candidates=\(candidates)",
            "command=\(command)",
            "capture=\(capture)",
            "session=\(session)",
            "timeout=\(timeout)",
            "node_limit=\(nodeLimit)",
            "depth_limit=\(depthLimit)",
            "failed_child_reads=\(failedChildReads)"
        ].joined(separator: " ")
    }

    static func failure(logCode: String) -> String {
        "GAZEROW_OVERLAY_RESULT failure reason=\(logCode)"
    }

    static func failureDetails(_ failure: OverlaySessionStartFailure) -> [String] {
        switch failure {
        case .noCandidates(let context, let scanResult):
            return [
                [
                    "GAZEROW_OVERLAY_SCAN_SUMMARY",
                    "bundle=\(context.application.bundleIdentifier)",
                    "candidates=0",
                    "nodes=\(scanResult.nodesVisited)",
                    "duration_ms=\(durationMilliseconds(scanResult.scanDuration))",
                    "depth_limit=\(scanResult.didHitDepthLimit)",
                    "node_limit=\(scanResult.didHitNodeLimit)",
                    "timeout=\(scanResult.didTimeout)",
                    "failed_child_reads=\(scanResult.failedChildReadCount)"
                ].joined(separator: " ")
            ]
        case .sessionDisabled,
             .targetResolutionFailed,
             .scanFailed:
            return []
        }
    }

    static func clickResult(
        _ result: Result<ClickExecutionSuccess, OverlaySessionClickFailure>
    ) -> String {
        switch result {
        case .success(let success):
            return [
                "GAZEROW_OVERLAY_CLICK_RESULT",
                "success",
                "method=\(methodCode(success.method))",
                "risk=\(riskCode(success.riskClass))",
                "fallback=\(success.fallbackUsed)"
            ].joined(separator: " ")
        case .failure(let failure):
            return [
                "GAZEROW_OVERLAY_CLICK_RESULT",
                "failure",
                "reason=\(failureCode(failure))"
            ].joined(separator: " ")
        }
    }

    static func queryResult(
        scope: QueryScope,
        matchCount: Int,
        matchIndex: Int,
        focusedDisplayName: String?,
        success: Bool
    ) -> String {
        [
            "GAZEROW_QUERY_RESULT",
            "scope=\(scope.rawValue)",
            "matches=\(matchCount)",
            "match_index=\(matchIndex)",
            "focus=\(sanitized(focusedDisplayName))",
            "success=\(success)"
        ].joined(separator: " ")
    }

    static func labelMap(layout: OverlayLayout, candidates: [ClickableCandidate]) -> [String] {
        layout.labels.map { label in
            let candidate = candidates[label.id]
            let frame = candidate.frame
            return [
                "GAZEROW_OVERLAY_LABEL",
                "index=\(label.id)",
                "label=\(label.text)",
                "role=\(candidate.role)",
                "title=\(sanitized(candidate.title))",
                "frame=\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width)),\(Int(frame.height))",
                "actions=\(candidate.actions.joined(separator: ","))"
            ].joined(separator: " ")
        }
    }

    private static func sanitized(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "<nil>"
        }

        return value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
    }

    private static func durationMilliseconds(_ duration: TimeInterval) -> Int {
        Int((duration * 1_000).rounded())
    }

    private static func methodCode(_ method: ClickExecutionMethod) -> String {
        switch method {
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

    private static func riskCode(_ riskClass: ClickRiskClass) -> String {
        switch riskClass {
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

    private static func failureCode(_ failure: OverlaySessionClickFailure) -> String {
        switch failure {
        case .scanFailed(let scanFailure):
            "scan_failed.\(scanFailureCode(scanFailure))"
        case .missingFocusedTarget:
            "missing_focused_target"
        case .selectedTargetUnavailable:
            "selected_target_unavailable"
        case .selectedTargetChanged:
            "selected_target_changed"
        case .selectedTargetAmbiguous:
            "selected_target_ambiguous"
        case .executionFailed(let executionFailure):
            "execution_failed.\(executionFailureCode(executionFailure))"
        }
    }

    private static func scanFailureCode(_ failure: AccessibilityScanFailure) -> String {
        switch failure {
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

    private static func executionFailureCode(_ failure: ClickExecutionFailure) -> String {
        switch failure {
        case .missingPressAction:
            "missing_action"
        case .secondConfirmRequired(let riskClass):
            "second_confirm_required.\(riskCode(riskClass))"
        case .axPressFailed:
            "ax_press_failed"
        case .coordinateFallbackDisabled:
            "coordinate_fallback_disabled"
        case .coordinateFallbackFailed:
            "coordinate_fallback_failed"
        }
    }
}
