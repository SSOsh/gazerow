import Foundation

/// 관찰 중인 AX tree snapshot의 세대.
///
/// @author suho.do
/// @since 2026-07-17
struct AccessibilityTreeGeneration: Equatable, Comparable, Sendable {
    let value: UInt64

    static let initial = AccessibilityTreeGeneration(value: 0)

    func advanced() -> AccessibilityTreeGeneration {
        AccessibilityTreeGeneration(value: value == .max ? 0 : value + 1)
    }

    static func < (
        lhs: AccessibilityTreeGeneration,
        rhs: AccessibilityTreeGeneration
    ) -> Bool {
        lhs.value < rhs.value
    }
}

/// cache invalidation을 유발한 비식별 AX 변경 종류.
///
/// @author suho.do
/// @since 2026-07-17
enum AccessibilityChangeKind: String, Equatable, Sendable {
    case focusedWindow
    case windowCreated
    case elementDestroyed
    case geometry
    case title
    case layout
    case selection
    case value
    case unknown
}

/// AX observer가 cache에 전달하는 변경 metadata.
///
/// @author suho.do
/// @since 2026-07-17
struct AccessibilityChangeMetadata: Equatable, Sendable {
    let kind: AccessibilityChangeKind
}

/// 프로세스별 AX tree generation과 observer 상태 snapshot.
///
/// @author suho.do
/// @since 2026-07-17
struct AccessibilityTreeGenerationSnapshot: Equatable, Sendable {
    let generation: AccessibilityTreeGeneration
    let isChangeMonitoringActive: Bool
    let lastChangeKind: AccessibilityChangeKind?
}

/// scanner와 click revalidator가 공유하는 프로세스별 AX tree 상태 저장소.
///
/// @author suho.do
/// @since 2026-07-17
@MainActor
final class AccessibilityTreeGenerationStore {
    private var snapshots: [pid_t: AccessibilityTreeGenerationSnapshot] = [:]

    func snapshot(for processIdentifier: pid_t) -> AccessibilityTreeGenerationSnapshot {
        snapshots[processIdentifier] ?? AccessibilityTreeGenerationSnapshot(
            generation: .initial,
            isChangeMonitoringActive: false,
            lastChangeKind: nil
        )
    }

    func setMonitoringActive(
        _ isActive: Bool,
        for processIdentifier: pid_t
    ) {
        let current = snapshot(for: processIdentifier)
        snapshots[processIdentifier] = AccessibilityTreeGenerationSnapshot(
            generation: current.generation,
            isChangeMonitoringActive: isActive,
            lastChangeKind: current.lastChangeKind
        )
    }

    @discardableResult
    func recordChange(
        _ metadata: AccessibilityChangeMetadata,
        for processIdentifier: pid_t
    ) -> AccessibilityTreeGenerationSnapshot {
        let current = snapshot(for: processIdentifier)
        let changed = AccessibilityTreeGenerationSnapshot(
            generation: current.generation.advanced(),
            isChangeMonitoringActive: false,
            lastChangeKind: metadata.kind
        )
        snapshots[processIdentifier] = changed
        return changed
    }
}
