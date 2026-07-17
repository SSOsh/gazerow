import Foundation

/// AX scan cache miss의 비식별 사유.
///
/// @author suho.do
/// @since 2026-07-17
enum AccessibilityScanCacheMissReason: String, Equatable {
    case empty
    case targetChanged = "target_changed"
    case expired
}

/// AX scan cache 무효화의 비식별 사유.
///
/// @author suho.do
/// @since 2026-07-17
enum AccessibilityScanCacheInvalidationReason: Equatable {
    case manual
    case scanFailure
    case accessibilityChange(AccessibilityChangeKind)

    var code: String {
        switch self {
        case .manual:
            "manual"
        case .scanFailure:
            "scan_failure"
        case .accessibilityChange(let kind):
            "ax_\(kind.rawValue)"
        }
    }
}

/// AX scan cache 동작을 원문 없이 기록하는 event.
///
/// @author suho.do
/// @since 2026-07-17
enum AccessibilityScanCacheEvent: Equatable {
    case hit
    case miss(AccessibilityScanCacheMissReason)
    case invalidated(AccessibilityScanCacheInvalidationReason)

    var code: String {
        switch self {
        case .hit:
            "hit"
        case .miss(let reason):
            "miss_\(reason.rawValue)"
        case .invalidated(let reason):
            "invalidated_\(reason.code)"
        }
    }
}
