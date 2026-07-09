import AppKit
import ApplicationServices
import Foundation

/// WindowSearchIndex entry activate 실패 사유.
///
/// @author suho.do
/// @since 2026-07-09
enum WindowActivateFailure: Error, Equatable {
    case appNotRunning
    case windowNotFound
    case axPermissionDenied
    case frontmostTimeout
}

/// Query Overlay windows scope activate abstraction.
///
/// @author suho.do
/// @since 2026-07-09
@MainActor
protocol WindowActivating {
    func activate(_ entry: WindowEntry) -> Result<Void, WindowActivateFailure>
}

/// NSRunningApplication/AX 기반 창 활성화기.
///
/// @author suho.do
/// @since 2026-07-09
struct WindowActivator: WindowActivating {
    private let runningApplicationProvider: (pid_t) -> NSRunningApplication?
    private let activateApplication: (NSRunningApplication) -> Bool
    private let frontmostBundleIDProvider: () -> String?
    private let sleep: (TimeInterval) -> Void
    private let maxPollDuration: TimeInterval
    private let pollInterval: TimeInterval

    init(
        runningApplicationProvider: @escaping (pid_t) -> NSRunningApplication? = {
            NSRunningApplication(processIdentifier: $0)
        },
        activateApplication: @escaping (NSRunningApplication) -> Bool = {
            $0.activate(options: [.activateIgnoringOtherApps])
        },
        frontmostBundleIDProvider: @escaping () -> String? = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        },
        sleep: @escaping (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) },
        maxPollDuration: TimeInterval = 1.0,
        pollInterval: TimeInterval = 0.05
    ) {
        self.runningApplicationProvider = runningApplicationProvider
        self.activateApplication = activateApplication
        self.frontmostBundleIDProvider = frontmostBundleIDProvider
        self.sleep = sleep
        self.maxPollDuration = max(0, maxPollDuration)
        self.pollInterval = max(0.01, pollInterval)
    }

    func activate(_ entry: WindowEntry) -> Result<Void, WindowActivateFailure> {
        guard let application = runningApplicationProvider(entry.pid) else {
            return .failure(.appNotRunning)
        }

        guard activateApplication(application) else {
            return .failure(.appNotRunning)
        }

        if let axWindow = entry.axWindow {
            raise(axWindow)
        }

        guard waitUntilFrontmost(bundleID: entry.bundleID) else {
            return .failure(.frontmostTimeout)
        }

        return .success(())
    }

    private func raise(_ window: AXUIElement) {
        var minimizedValue: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
           let isMinimized = minimizedValue as? Bool,
           isMinimized {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
    }

    private func waitUntilFrontmost(bundleID: String) -> Bool {
        guard !bundleID.isEmpty else {
            sleep(0.3)
            return true
        }

        var elapsed: TimeInterval = 0
        while elapsed <= maxPollDuration {
            if frontmostBundleIDProvider() == bundleID {
                return true
            }
            sleep(pollInterval)
            elapsed += pollInterval
        }
        return false
    }
}
