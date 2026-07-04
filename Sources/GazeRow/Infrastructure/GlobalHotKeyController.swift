import AppKit
import Carbon

/// Carbon `RegisterEventHotKey` 기반 전역 단축키 등록기.
///
/// `NSEvent.addGlobalMonitorForEvents`는 Command 계열 조합을 앱 밖에서 안정적으로
/// 받지 못할 수 있어, overlay activation은 OS hotkey 등록을 우선 사용한다.
///
/// @author suho.do
/// @since 2026-07-03
@MainActor
final class GlobalHotKeyController {
    private let definition: GlobalHotKeyDefinition
    private let onPress: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(
        definition: GlobalHotKeyDefinition = .overlayActivation,
        onPress: @escaping @MainActor () -> Void
    ) {
        self.definition = definition
        self.onPress = onPress
    }

    func register() -> OSStatus {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            eventHandlerRef = nil
            return handlerStatus
        }

        let hotKeyID = EventHotKeyID(
            signature: definition.signature,
            id: definition.identifier
        )

        let registerStatus = RegisterEventHotKey(
            UInt32(definition.keyCode),
            definition.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            unregister()
        }

        return registerStatus
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    func matches(hotKeyID: EventHotKeyID) -> Bool {
        hotKeyID.signature == definition.signature
            && hotKeyID.id == definition.identifier
    }

    @discardableResult
    func handlePressedHotKey(hotKeyID: EventHotKeyID) -> Bool {
        guard matches(hotKeyID: hotKeyID) else {
            return false
        }

        onPress()
        return true
    }
}

/// Carbon hotkey 등록에 필요한 key/modifier 정의.
///
/// @author suho.do
/// @since 2026-07-03
struct GlobalHotKeyDefinition: Equatable {
    static let overlayActivation = GlobalHotKeyDefinition(
        keyCode: OverlayActivationKeyCode.space,
        requiredModifiers: [.command, .shift],
        signature: Self.fourCharacterCode("GzRw"),
        identifier: 1
    )
    static let fallbackOverlayActivation = GlobalHotKeyDefinition(
        keyCode: OverlayActivationKeyCode.space,
        requiredModifiers: [.control, .option],
        signature: Self.fourCharacterCode("GzRw"),
        identifier: 2
    )
    static let gazeActivation = GlobalHotKeyDefinition(
        keyCode: OverlayActivationKeyCode.space,
        requiredModifiers: [.control, .shift],
        signature: Self.fourCharacterCode("GzRw"),
        identifier: 3
    )
    static let overlayActivationDefinitions = [
        overlayActivation,
        fallbackOverlayActivation
    ]

    let keyCode: UInt16
    let requiredModifiers: NSEvent.ModifierFlags
    let signature: OSType
    let identifier: UInt32

    var carbonModifiers: UInt32 {
        var modifiers: UInt32 = 0

        if requiredModifiers.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if requiredModifiers.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if requiredModifiers.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if requiredModifiers.contains(.control) {
            modifiers |= UInt32(controlKey)
        }

        return modifiers
    }

    static func fourCharacterCode(_ string: String) -> OSType {
        string.utf8.prefix(4).reduce(OSType(0)) { result, character in
            (result << 8) + OSType(character)
        }
    }
}

private let hotKeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let userData else {
        return noErr
    }

    guard let hotKeyID = eventHotKeyID(from: event) else {
        return noErr
    }

    let controller = Unmanaged<GlobalHotKeyController>
        .fromOpaque(userData)
        .takeUnretainedValue()

    Task { @MainActor in
        controller.handlePressedHotKey(hotKeyID: hotKeyID)
    }

    return noErr
}

private func eventHotKeyID(from event: EventRef?) -> EventHotKeyID? {
    guard let event else {
        return nil
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr else {
        return nil
    }

    return hotKeyID
}
