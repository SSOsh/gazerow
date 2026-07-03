import XCTest
@testable import GazeRow

/// `AppLaunchOptions`의 인자 파싱을 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class AppLaunchOptionsTests: XCTestCase {

    func test_init_requestAccessibility_인자가있으면_true() {
        // given
        let arguments = ["GazeRow", "--request-accessibility"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertTrue(sut.requestsAccessibilityPermission)
    }

    func test_init_requestAccessibility_인자가없으면_false() {
        // given
        let arguments = ["GazeRow"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertFalse(sut.requestsAccessibilityPermission)
    }

    func test_init_showOverlayOnLaunch_인자가있으면_true() {
        // given
        let arguments = ["GazeRow", "--show-overlay-on-launch"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertTrue(sut.showsOverlayOnLaunch)
    }

    func test_init_showOverlayOnLaunch_인자가없으면_false() {
        // given
        let arguments = ["GazeRow"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertFalse(sut.showsOverlayOnLaunch)
    }

    func test_init_targetBundleId_값이있으면_반환() {
        // given
        let arguments = ["GazeRow", "--target-bundle-id", "com.apple.finder"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertEqual(sut.targetBundleIdentifier, "com.apple.finder")
    }

    func test_init_targetBundleId_값이없으면_nil() {
        // given
        let arguments = ["GazeRow", "--target-bundle-id"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertNil(sut.targetBundleIdentifier)
    }

    func test_init_targetBundleId_다음값이다른옵션이면_nil() {
        // given
        let arguments = ["GazeRow", "--target-bundle-id", "--show-overlay-on-launch"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertNil(sut.targetBundleIdentifier)
    }

    func test_init_printOverlayLabelMap_인자가있으면_true() {
        // given
        let arguments = ["GazeRow", "--print-overlay-label-map"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertTrue(sut.printsOverlayLabelMap)
    }

    func test_init_printHotKeyRegistration_인자가있으면_true() {
        // given
        let arguments = ["GazeRow", "--print-hotkey-registration"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertTrue(sut.printsHotKeyRegistration)
    }

    func test_init_printOverlayLabelMap_인자가없으면_false() {
        // given
        let arguments = ["GazeRow"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertFalse(sut.printsOverlayLabelMap)
    }

    func test_init_clickOverlayLabel_값이있으면_반환() {
        // given
        let arguments = ["GazeRow", "--click-overlay-label", "AK"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertEqual(sut.clickOverlayLabel, "AK")
    }

    func test_init_clickOverlayLabel_값이없으면_nil() {
        // given
        let arguments = ["GazeRow", "--click-overlay-label"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertNil(sut.clickOverlayLabel)
    }

    func test_init_clickOverlayLabel_다음값이다른옵션이면_nil() {
        // given
        let arguments = ["GazeRow", "--click-overlay-label", "--show-overlay-on-launch"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertNil(sut.clickOverlayLabel)
    }
}
