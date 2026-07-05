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
    nonisolated let definition: GlobalHotKeyDefinition
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

    /// 발생한 hotkey 이벤트의 `EventHotKeyID`가 이 controller의 정의와 일치할 때만
    /// `onPress()`를 호출한다.
    ///
    /// 하나의 application event target에 여러 controller가 같은 handler를 설치하므로,
    /// 각 controller는 자신에게 해당하는 이벤트에만 반응하고 나머지는 핸들러 체인으로
    /// 전파되도록 한다.
    @discardableResult
    func handlePressedHotKey(id: EventHotKeyID) -> Bool {
        guard matchesRegisteredDefinition(id) else {
            return false
        }

        onPress()
        return true
    }

    /// hotkey 이벤트가 이 controller의 등록 정의에 속하는지 판정한다.
    ///
    /// Carbon event handler(비-isolated 컨텍스트)에서 필터로 사용한다.
    nonisolated func matchesRegisteredDefinition(_ id: EventHotKeyID) -> Bool {
        Self.matchesDefinition(
            eventSignature: id.signature,
            eventIdentifier: id.id,
            definitionSignature: definition.signature,
            definitionIdentifier: definition.identifier
        )
    }

    /// hotkey 이벤트가 특정 정의에 속하는지 판정하는 순수 함수.
    ///
    /// Carbon 의존 없이 단위 테스트할 수 있도록 signature/identifier 비교만 수행한다.
    nonisolated static func matchesDefinition(
        eventSignature: OSType,
        eventIdentifier: UInt32,
        definitionSignature: OSType,
        definitionIdentifier: UInt32
    ) -> Bool {
        eventSignature == definitionSignature
            && eventIdentifier == definitionIdentifier
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
        requiredModifiers: [.control, .option, .command],
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
    guard let userData, let event else {
        return OSStatus(eventNotHandledErr)
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
        return OSStatus(eventNotHandledErr)
    }

    let controller = Unmanaged<GlobalHotKeyController>
        .fromOpaque(userData)
        .takeUnretainedValue()

    // 이 controller의 정의와 일치하지 않으면 다른 controller가 처리하도록 전파한다.
    guard controller.matchesRegisteredDefinition(hotKeyID) else {
        return OSStatus(eventNotHandledErr)
    }

    Task { @MainActor in
        _ = controller.handlePressedHotKey(id: hotKeyID)
    }

    return noErr
}
