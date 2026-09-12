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

/// AX 객체 재생성 여부와 무관하게 실제 창을 식별하기 위한 공개 속성 조합.
///
/// @author suho.do
/// @since 2026-07-26
struct AXWindowFingerprint {
    let identifier: String?
    let title: String?
    let frame: CGRect?

    static let empty = AXWindowFingerprint(identifier: nil, title: nil, frame: nil)
}

/// 실제 AX 객체와 보수적 fallback fingerprint를 함께 보관한다.
///
/// @author suho.do
/// @since 2026-07-26
struct AXWindowReference {
    let element: AXUIElement
    let fingerprint: AXWindowFingerprint

    init(
        element: AXUIElement,
        fingerprint: AXWindowFingerprint = .empty
    ) {
        self.element = element
        self.fingerprint = fingerprint
    }
}

/// NSRunningApplication/AX 기반 창 활성화기.
///
/// @author suho.do
/// @since 2026-07-09
struct WindowActivator: WindowActivating {
    private let runningApplicationProvider: (pid_t) -> NSRunningApplication?
    private let activateApplication: (NSRunningApplication) -> Bool
    private let requestWindowFocus: (AXUIElement) -> Void
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
            if NSApp.isActive {
                NSApp.yieldActivation(to: $0)
                return $0.activate(from: NSRunningApplication.current, options: [])
            }
            return $0.activate(options: [])
        },
        requestWindowFocus: @escaping (AXUIElement) -> Void = {
            WindowActivator.requestFocus(for: $0)
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
        self.requestWindowFocus = requestWindowFocus
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
            requestWindowFocus(axWindow)
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

    nonisolated private static func requestFocus(for window: AXUIElement) {
        var minimizedValue: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
           let isMinimized = minimizedValue as? Bool,
           isMinimized {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
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
            if isApplicationFrontmost,
               let axWindow = entry.axWindow {
                requestWindowFocus(axWindow)
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
        let selectedReference = windowReference(selectedWindow)
        return isSameWindow(
            selectedReference,
            as: copyWindowReference(kAXFocusedWindowAttribute, from: applicationElement)
        ) || isSameWindow(
            selectedReference,
            as: copyWindowReference(kAXMainWindowAttribute, from: applicationElement)
        )
    }

    nonisolated private static func copyWindowReference(
        _ attribute: String,
        from applicationElement: AXUIElement
    ) -> AXWindowReference? {
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

        let window = value as! AXUIElement
        return windowReference(window)
    }

    nonisolated private static func windowReference(
        _ window: AXUIElement
    ) -> AXWindowReference {
        AXWindowReference(
            element: window,
            fingerprint: AXWindowFingerprint(
                identifier: stringAttribute(kAXIdentifierAttribute as String, from: window),
                title: stringAttribute(kAXTitleAttribute as String, from: window),
                frame: windowFrame(window)
            )
        )
    }

    nonisolated private static func stringAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) -> String? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )
        guard error == .success else {
            return nil
        }
        return value as? String
    }

    nonisolated private static func windowFrame(_ window: AXUIElement) -> CGRect? {
        guard let origin = pointAttribute(kAXPositionAttribute as String, from: window),
              let size = sizeAttribute(kAXSizeAttribute as String, from: window) else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    nonisolated private static func pointAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) -> CGPoint? {
        guard let value = axValue(attribute, from: element) else {
            return nil
        }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    nonisolated private static func sizeAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) -> CGSize? {
        guard let value = axValue(attribute, from: element) else {
            return nil
        }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    nonisolated private static func axValue(
        _ attribute: String,
        from element: AXUIElement
    ) -> AXValue? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return (value as! AXValue)
    }

    nonisolated static func isSameWindow(
        _ selectedWindow: AXWindowReference,
        as activeWindow: AXWindowReference?
    ) -> Bool {
        guard let activeWindow else {
            return false
        }

        if CFEqual(selectedWindow.element, activeWindow.element) {
            return true
        }

        guard hasSameFrame(selectedWindow.fingerprint.frame, activeWindow.fingerprint.frame),
              let selectedTitle = normalized(selectedWindow.fingerprint.title),
              let activeTitle = normalized(activeWindow.fingerprint.title),
              selectedTitle == activeTitle else {
            return false
        }

        guard let selectedIdentifier = normalized(selectedWindow.fingerprint.identifier),
              let activeIdentifier = normalized(activeWindow.fingerprint.identifier) else {
            return false
        }
        return selectedIdentifier == activeIdentifier
    }

    nonisolated private static func normalized(_ value: String?) -> String? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty else {
            return nil
        }
        return normalized
    }

    nonisolated private static func hasSameFrame(
        _ selectedFrame: CGRect?,
        _ activeFrame: CGRect?
    ) -> Bool {
        guard let selectedFrame,
              let activeFrame else {
            return false
        }
        let tolerance: CGFloat = 1
        return abs(selectedFrame.origin.x - activeFrame.origin.x) <= tolerance
            && abs(selectedFrame.origin.y - activeFrame.origin.y) <= tolerance
            && abs(selectedFrame.size.width - activeFrame.size.width) <= tolerance
            && abs(selectedFrame.size.height - activeFrame.size.height) <= tolerance
    }
}
