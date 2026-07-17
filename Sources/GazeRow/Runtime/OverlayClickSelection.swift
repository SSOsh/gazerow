import Foundation

/// 사용자가 overlay에서 선택한 최초 click 후보 snapshot.
///
/// @author suho.do
/// @since 2026-07-14
struct OverlayClickSelection: Equatable {
    let labelID: Int
    let candidate: ClickableCandidate
    let sourceCandidateCount: Int
    let targetDescriptor: AccessibilityTargetDescriptor?
    let generation: AccessibilityTreeGeneration
    let isChangeMonitoringActive: Bool

    init(
        labelID: Int,
        candidate: ClickableCandidate,
        sourceCandidateCount: Int,
        targetDescriptor: AccessibilityTargetDescriptor? = nil,
        generation: AccessibilityTreeGeneration = .initial,
        isChangeMonitoringActive: Bool = false
    ) {
        self.labelID = labelID
        self.candidate = candidate
        self.sourceCandidateCount = sourceCandidateCount
        self.targetDescriptor = targetDescriptor
        self.generation = generation
        self.isChangeMonitoringActive = isChangeMonitoringActive
    }
}
