import ApplicationServices
import Foundation

/// AX UI 변경을 감지해 scan cache 무효화 시점을 전달한다.
///
/// @author suho.do
/// @since 2026-07-17
@MainActor
protocol AccessibilityChangeMonitoring: AnyObject {
    /// 대상 프로세스 관찰을 시작한다. 하나 이상의 notification을 등록했을 때 true다.
    func start(
        processIdentifier: pid_t,
        onChange: @escaping @MainActor () -> Void
    ) -> Bool

    func stop()
}

/// `AXObserver`와 main run loop를 사용하는 production 변경 감지기.
///
/// notification을 받으면 기존 observer를 해제한 뒤 cache를 무효화한다. 다음 scan에서
/// observer를 다시 구성하므로 focused window가 바뀐 경우에도 새 window를 관찰한다.
///
/// @author suho.do
/// @since 2026-07-17
@MainActor
final class AXAccessibilityChangeMonitor: AccessibilityChangeMonitoring {
    private var observer: AXObserver?
    private var runLoopSource: CFRunLoopSource?
    private var registrations: [Registration] = []
    private var processIdentifier: pid_t?
    private var onChange: (@MainActor () -> Void)?

    nonisolated init() {}

    func start(
        processIdentifier: pid_t,
        onChange: @escaping @MainActor () -> Void
    ) -> Bool {
        if self.processIdentifier == processIdentifier, observer != nil {
            self.onChange = onChange
            return true
        }

        stop()

        var createdObserver: AXObserver?
        let creationError = AXObserverCreate(
            processIdentifier,
            accessibilityChangeCallback,
            &createdObserver
        )
        guard creationError == .success, let createdObserver else {
            return false
        }

        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        let focusedWindow = copyFocusedWindow(from: applicationElement)
        observer = createdObserver
        self.processIdentifier = processIdentifier
        self.onChange = onChange

        register(
            notifications: Self.applicationNotifications,
            for: applicationElement,
            observer: createdObserver
        )
        if let focusedWindow {
            register(
                notifications: Self.windowNotifications,
                for: focusedWindow,
                observer: createdObserver
            )
        }

        guard !registrations.isEmpty else {
            stop()
            return false
        }

        let source = AXObserverGetRunLoopSource(createdObserver)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let observer {
            for registration in registrations {
                AXObserverRemoveNotification(
                    observer,
                    registration.element,
                    registration.notification as CFString
                )
            }
        }

        registrations.removeAll(keepingCapacity: true)
        runLoopSource = nil
        observer = nil
        processIdentifier = nil
        onChange = nil
    }

    fileprivate func receiveChange() {
        let callback = onChange
        stop()
        callback?()
    }

    private func register(
        notifications: [String],
        for element: AXUIElement,
        observer: AXObserver
    ) {
        for notification in notifications {
            let error = AXObserverAddNotification(
                observer,
                element,
                notification as CFString,
                Unmanaged.passUnretained(self).toOpaque()
            )
            if error == .success || error == .notificationAlreadyRegistered {
                registrations.append(Registration(element: element, notification: notification))
            }
        }
    }

    private func copyFocusedWindow(from applicationElement: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        )
        guard error == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private static let applicationNotifications: [String] = [
        kAXFocusedWindowChangedNotification,
        kAXMainWindowChangedNotification,
        kAXWindowCreatedNotification
    ]

    private static let windowNotifications: [String] = [
        kAXUIElementDestroyedNotification,
        kAXMovedNotification,
        kAXResizedNotification,
        kAXTitleChangedNotification,
        kAXLayoutChangedNotification,
        kAXSelectedChildrenChangedNotification,
        kAXValueChangedNotification
    ]

    private struct Registration {
        let element: AXUIElement
        let notification: String
    }
}

private let accessibilityChangeCallback: AXObserverCallback = { _, _, _, refcon in
    guard let refcon else {
        return
    }

    let monitor = Unmanaged<AXAccessibilityChangeMonitor>
        .fromOpaque(refcon)
        .takeUnretainedValue()
    Task { @MainActor in
        monitor.receiveChange()
    }
}
