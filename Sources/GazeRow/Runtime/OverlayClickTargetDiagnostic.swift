import CoreGraphics
import Foundation

/// overlay label 선택 시점과 Enter click 대상 시점의 target 정보를 개인정보 없이 기록한다.
///
/// raw title, value, query는 남기지 않고 frame과 역할 정보만 비교 가능하게 유지한다.
///
/// @author suho.do
/// @since 2026-07-14
enum OverlayClickTargetDiagnostic {
    static func source(
        index: Int,
        candidateCount: Int,
        candidate: ClickableCandidate
    ) -> String {
        message(
            phase: "source",
            index: index,
            candidateCount: candidateCount,
            role: candidate.role,
            subrole: candidate.subrole,
            title: candidate.title,
            frame: candidate.frame,
            actions: candidate.actions
        )
    }

    static func resolved<Element>(
        index: Int,
        candidateCount: Int,
        target: ClickTarget<Element>
    ) -> String {
        message(
            phase: "resolved",
            index: index,
            candidateCount: candidateCount,
            role: target.role,
            subrole: target.subrole,
            title: target.title,
            frame: target.frame,
            actions: target.actions
        )
    }

    private static func message(
        phase: String,
        index: Int,
        candidateCount: Int,
        role: String,
        subrole: String?,
        title: String?,
        frame: CGRect,
        actions: [String]
    ) -> String {
        let frameText = "(\(Int(frame.minX.rounded())),\(Int(frame.minY.rounded())) \(Int(frame.width.rounded()))x\(Int(frame.height.rounded())))"
        return "click target diagnostic phase=\(phase) index=\(index) count=\(candidateCount) role=\(role) subrolePresent=\(subrole != nil) titlePresent=\(hasText(title)) actionCount=\(actions.count) frame=\(frameText)"
    }

    private static func hasText(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
