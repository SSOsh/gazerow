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
