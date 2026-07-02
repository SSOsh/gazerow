import SwiftUI

/// target resolver 상태를 런타임에 확인하는 debug view.
///
/// window title은 화면 표시용으로만 사용하며 기본 로그/파일 저장 대상이 아니다.
///
/// @author suho.do
/// @since 2026-07-02
struct TargetContextDebugView: View {
    let context: TargetContext?
    let failure: TargetResolutionFailure?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target")
                .font(.headline)

            if let context {
                debugRow("App", context.application.localizedName)
                debugRow("Bundle", context.application.bundleIdentifier)
                debugRow("PID", String(context.application.processIdentifier))
                debugRow("Window", context.window.title ?? "Untitled")
                debugRow("Frame", formattedFrame(context.window.frame))
            } else if let failure {
                Text(failure.description)
                    .foregroundStyle(.secondary)
            } else {
                Text("No target resolved.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private func debugRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func formattedFrame(_ frame: CGRect) -> String {
        "x:\(Int(frame.origin.x)) y:\(Int(frame.origin.y)) w:\(Int(frame.width)) h:\(Int(frame.height))"
    }
}

#Preview {
    TargetContextDebugView(context: nil, failure: .accessibilityPermissionDenied)
        .padding()
}
