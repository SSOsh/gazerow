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
    case cancelled
}

/// Query Overlay windows scope activate abstraction.
///
/// @author suho.do
/// @since 2026-07-09
@MainActor
protocol WindowActivating {
    func activate(_ entry: WindowEntry) async -> Result<Void, WindowActivateFailure>
}

/// NSRunningApplication/AX 기반 창 활성화기.
///
/// @author suho.do
/// @since 2026-07-09
struct WindowActivator: WindowActivating {
    private let runningApplicationProvider: (pid_t) -> NSRunningApplication?
    private let activateApplication: (NSRunningApplication) -> Bool
    private let frontmostBundleIDProvider: () -> String?
    private let selectedWindowReadinessProvider: (WindowEntry) -> Bool
    private let sleep: @MainActor (TimeInterval) async -> Void
    private let maxPollDuration: TimeInterval
    private let pollInterval: TimeInterval

    init(
        runningApplicationProvider: @escaping (pid_t) -> NSRunningApplication? = {
            NSRunningApplication(processIdentifier: $0)
        },
        activateApplication: @escaping (NSRunningApplication) -> Bool = {
            $0.activate(options: [])
        },
        frontmostBundleIDProvider: @escaping () -> String? = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        },
        selectedWindowReadinessProvider: @escaping (WindowEntry) -> Bool = {
            WindowActivator.isSelectedWindowReady($0)
        },
        sleep: @escaping @MainActor (TimeInterval) async -> Void = { duration in
            try? await Task.sleep(for: .seconds(duration))
        },
        maxPollDuration: TimeInterval = 1.0,
        pollInterval: TimeInterval = 0.05
    ) {
        self.runningApplicationProvider = runningApplicationProvider
        self.activateApplication = activateApplication
        self.frontmostBundleIDProvider = frontmostBundleIDProvider
        self.selectedWindowReadinessProvider = selectedWindowReadinessProvider
        self.sleep = sleep
        self.maxPollDuration = max(0, maxPollDuration)
        self.pollInterval = max(0.01, pollInterval)
    }

    func activate(_ entry: WindowEntry) async -> Result<Void, WindowActivateFailure> {
        guard let application = runningApplicationProvider(entry.pid) else {
            return .failure(.appNotRunning)
        }

        guard activateApplication(application) else {
            return .failure(.appNotRunning)
        }

        if let axWindow = entry.axWindow {
            raise(axWindow)
        }

        let isTargetReady = await waitUntilTargetReady(entry)
        if Task.isCancelled {
            return .failure(.cancelled)
        }

        guard isTargetReady else {
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

    private func waitUntilTargetReady(_ entry: WindowEntry) async -> Bool {
        guard !Task.isCancelled else {
            return false
        }

        if entry.bundleID.isEmpty {
            await sleep(0.3)
        }

        var elapsed: TimeInterval = 0
        while elapsed <= maxPollDuration {
            guard !Task.isCancelled else {
                return false
            }
            let isApplicationFrontmost = entry.bundleID.isEmpty
                || frontmostBundleIDProvider() == entry.bundleID
            if isApplicationFrontmost,
               selectedWindowReadinessProvider(entry) {
                return true
            }
            await sleep(pollInterval)
            elapsed += pollInterval
        }
        return false
    }

    nonisolated static func isSelectedWindowReady(_ entry: WindowEntry) -> Bool {
        guard let selectedWindow = entry.axWindow else {
            return true
        }

        let applicationElement = AXUIElementCreateApplication(entry.pid)
        return isSameWindow(
            selectedWindow,
            as: copyWindow(kAXFocusedWindowAttribute, from: applicationElement)
        ) || isSameWindow(
            selectedWindow,
            as: copyWindow(kAXMainWindowAttribute, from: applicationElement)
        )
    }

    nonisolated private static func copyWindow(
        _ attribute: String,
        from applicationElement: AXUIElement
    ) -> AXUIElement? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            applicationElement,
            attribute as CFString,
            &value
        )
        guard error == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }

    nonisolated private static func isSameWindow(
        _ selectedWindow: AXUIElement,
        as activeWindow: AXUIElement?
    ) -> Bool {
        guard let activeWindow else {
            return false
        }

        return CFEqual(selectedWindow, activeWindow)
    }
}
