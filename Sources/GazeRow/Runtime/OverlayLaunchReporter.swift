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
}
