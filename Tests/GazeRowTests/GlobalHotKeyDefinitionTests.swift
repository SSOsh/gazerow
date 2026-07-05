import AppKit
import Carbon
import XCTest
@testable import GazeRow

/// GlobalHotKeyDefinition 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class GlobalHotKeyDefinitionTests: XCTestCase {

    func test_overlayActivation은_CommandShiftSpace를_CarbonModifier로_변환() {
        // given
        let sut = GlobalHotKeyDefinition.overlayActivation

        // then
        XCTAssertEqual(sut.keyCode, OverlayActivationKeyCode.space)
        XCTAssertTrue((sut.carbonModifiers & UInt32(cmdKey)) != 0)
        XCTAssertTrue((sut.carbonModifiers & UInt32(shiftKey)) != 0)
        XCTAssertFalse((sut.carbonModifiers & UInt32(optionKey)) != 0)
        XCTAssertFalse((sut.carbonModifiers & UInt32(controlKey)) != 0)
    }

    func test_fallbackOverlayActivation은_ControlOptionCommandSpace를_CarbonModifier로_변환() {
        // given
        let sut = GlobalHotKeyDefinition.fallbackOverlayActivation

        // then
        XCTAssertEqual(sut.keyCode, OverlayActivationKeyCode.space)
        XCTAssertTrue((sut.carbonModifiers & UInt32(cmdKey)) != 0)
        XCTAssertFalse((sut.carbonModifiers & UInt32(shiftKey)) != 0)
        XCTAssertTrue((sut.carbonModifiers & UInt32(optionKey)) != 0)
        XCTAssertTrue((sut.carbonModifiers & UInt32(controlKey)) != 0)
        XCTAssertEqual(sut.identifier, 2)
    }

    func test_gazeActivation은_ControlShiftSpace를_CarbonModifier로_변환() {
        // given
        let sut = GlobalHotKeyDefinition.gazeActivation

        // then
        XCTAssertEqual(sut.keyCode, OverlayActivationKeyCode.space)
        XCTAssertFalse((sut.carbonModifiers & UInt32(cmdKey)) != 0)
        XCTAssertTrue((sut.carbonModifiers & UInt32(shiftKey)) != 0)
        XCTAssertFalse((sut.carbonModifiers & UInt32(optionKey)) != 0)
        XCTAssertTrue((sut.carbonModifiers & UInt32(controlKey)) != 0)
        XCTAssertEqual(sut.identifier, 3)
    }

    func test_overlayActivationDefinitions는_기본과_보조_단축키를_포함() {
        // when
        let result = GlobalHotKeyDefinition.overlayActivationDefinitions

        // then
        XCTAssertEqual(result, [.overlayActivation, .fallbackOverlayActivation])
    }

    func test_fourCharacterCode는_4글자_signature를_생성() {
        // when
        let code = GlobalHotKeyDefinition.fourCharacterCode("GzRw")

        // then
        XCTAssertEqual(code, 0x477a5277)
    }

    // MARK: - hotKeyID 필터

    func test_matchesDefinition_signature와_identifier가_모두_같으면_true() {
        // given
        let signature = GlobalHotKeyDefinition.fourCharacterCode("GzRw")

        // when
        let result = GlobalHotKeyController.matchesDefinition(
            eventSignature: signature,
            eventIdentifier: 1,
            definitionSignature: signature,
            definitionIdentifier: 1
        )

        // then
        XCTAssertTrue(result)
    }

    func test_matchesDefinition_identifier가_다르면_false() {
        // given
        let signature = GlobalHotKeyDefinition.fourCharacterCode("GzRw")

        // when
        let result = GlobalHotKeyController.matchesDefinition(
            eventSignature: signature,
            eventIdentifier: 2,
            definitionSignature: signature,
            definitionIdentifier: 1
        )

        // then
        XCTAssertFalse(result)
    }

    func test_matchesDefinition_signature가_다르면_false() {
        // given
        let eventSignature = GlobalHotKeyDefinition.fourCharacterCode("GzRw")
        let definitionSignature = GlobalHotKeyDefinition.fourCharacterCode("XxYy")

        // when
        let result = GlobalHotKeyController.matchesDefinition(
            eventSignature: eventSignature,
            eventIdentifier: 1,
            definitionSignature: definitionSignature,
            definitionIdentifier: 1
        )

        // then
        XCTAssertFalse(result)
    }

    @MainActor
    func test_특정_hotKeyID_이벤트는_매칭_controller의_onPress만_트리거() {
        // given
        var overlayPressed = false
        var fallbackPressed = false

        let overlayController = GlobalHotKeyController(
            definition: .overlayActivation
        ) {
            overlayPressed = true
        }
        let fallbackController = GlobalHotKeyController(
            definition: .fallbackOverlayActivation
        ) {
            fallbackPressed = true
        }

        let overlayEventID = EventHotKeyID(
            signature: GlobalHotKeyDefinition.overlayActivation.signature,
            id: GlobalHotKeyDefinition.overlayActivation.identifier
        )

        // when: overlayActivation(identifier=1) 이벤트를 두 controller에 전달
        let overlayHandled = overlayController.handlePressedHotKey(id: overlayEventID)
        let fallbackHandled = fallbackController.handlePressedHotKey(id: overlayEventID)

        // then: 매칭되는 overlayController만 onPress 실행
        XCTAssertTrue(overlayHandled)
        XCTAssertTrue(overlayPressed)
        XCTAssertFalse(fallbackHandled)
        XCTAssertFalse(fallbackPressed)
    }

}
