import AppKit
import Carbon
import XCTest
@testable import GazeRow

/// GlobalHotKeyDefinition 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
@MainActor
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

    func test_fallbackOverlayActivation은_ControlOptionSpace를_CarbonModifier로_변환() {
        // given
        let sut = GlobalHotKeyDefinition.fallbackOverlayActivation

        // then
        XCTAssertEqual(sut.keyCode, OverlayActivationKeyCode.space)
        XCTAssertFalse((sut.carbonModifiers & UInt32(cmdKey)) != 0)
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

    func test_GlobalHotKeyController는_일치하는_hotKeyID만_처리한다() {
        // given
        var callCount = 0
        let sut = GlobalHotKeyController(definition: .gazeActivation) {
            callCount += 1
        }
        let overlayHotKeyID = EventHotKeyID(
            signature: GlobalHotKeyDefinition.fourCharacterCode("GzRw"),
            id: GlobalHotKeyDefinition.fallbackOverlayActivation.identifier
        )
        let gazeHotKeyID = EventHotKeyID(
            signature: GlobalHotKeyDefinition.fourCharacterCode("GzRw"),
            id: GlobalHotKeyDefinition.gazeActivation.identifier
        )

        // when
        let overlayHandled = sut.handlePressedHotKey(hotKeyID: overlayHotKeyID)
        let gazeHandled = sut.handlePressedHotKey(hotKeyID: gazeHotKeyID)

        // then
        XCTAssertFalse(overlayHandled)
        XCTAssertTrue(gazeHandled)
        XCTAssertEqual(callCount, 1)
    }
}
