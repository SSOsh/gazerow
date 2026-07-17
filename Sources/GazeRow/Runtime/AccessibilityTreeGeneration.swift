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
