import CoreGraphics
import Foundation

/// target app/window resolve 결과 모델.
///
/// window title은 런타임 표시 목적으로만 보관하며, 로그 저장 대상이 아니다.
///
/// @author suho.do
/// @since 2026-07-02
struct TargetContext: Equatable {
    let application: TargetApplication
    let window: TargetWindow
    let resolvedAt: Date
}

/// frontmost application snapshot.
///
/// @author suho.do
/// @since 2026-07-02
struct TargetApplication: Equatable {
    let localizedName: String
    let bundleIdentifier: String
    let processIdentifier: pid_t
}

/// focused window snapshot.
///
/// @author suho.do
/// @since 2026-07-02
struct TargetWindow: Equatable {
    let frame: CGRect
    let title: String?

    var hasUsableFrame: Bool {
        frame.width > 0 && frame.height > 0
    }
}

/// target resolve 실패 사유.
///
/// @author suho.do
/// @since 2026-07-02
enum TargetResolutionFailure: Error, Equatable, CustomStringConvertible {
    case noFrontmostApplication
    case invalidProcessIdentifier(pid_t)
    case accessibilityPermissionDenied
    case focusedWindowUnavailable(bundleIdentifier: String, reason: String)
    case windowFrameUnavailable(bundleIdentifier: String, reason: String)
    case invalidWindowFrame(bundleIdentifier: String, frame: CGRect)

    var description: String {
        switch self {
        case .noFrontmostApplication:
            "No frontmost application is available."
        case .invalidProcessIdentifier(let processIdentifier):
            "Frontmost application has an invalid process identifier: \(processIdentifier)."
        case .accessibilityPermissionDenied:
            "Accessibility permission is not granted."
        case .focusedWindowUnavailable(let bundleIdentifier, let reason):
            "Focused window is unavailable for \(bundleIdentifier): \(reason)."
        case .windowFrameUnavailable(let bundleIdentifier, let reason):
            "Window frame is unavailable for \(bundleIdentifier): \(reason)."
        case .invalidWindowFrame(let bundleIdentifier, let frame):
            "Window frame is invalid for \(bundleIdentifier): \(frame)."
        }
    }
}

/// AX attribute 조회 실패 사유.
///
/// @author suho.do
/// @since 2026-07-02
enum AccessibilityReadFailure: Error, Equatable {
    case permissionDenied
    case focusedWindowUnavailable(String)
    case frameUnavailable(String)
}
