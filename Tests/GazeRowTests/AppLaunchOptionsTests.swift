import XCTest
@testable import GazeRow

/// `AppLaunchOptions`의 인자 파싱을 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class AppLaunchOptionsTests: XCTestCase {

    func test_init_requestAccessibility_인자가있으면_true() {
        // given
        let arguments = ["gazerow", "--request-accessibility"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertTrue(sut.requestsAccessibilityPermission)
    }

    func test_init_requestAccessibility_인자가없으면_false() {
        // given
        let arguments = ["gazerow"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertFalse(sut.requestsAccessibilityPermission)
    }

    func test_init_showOverlayOnLaunch_인자가있으면_true() {
        // given
        let arguments = ["gazerow", "--show-overlay-on-launch"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertTrue(sut.showsOverlayOnLaunch)
    }

    func test_init_showOverlayOnLaunch_인자가없으면_false() {
        // given
        let arguments = ["gazerow"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertFalse(sut.showsOverlayOnLaunch)
    }

    func test_init_targetBundleId_값이있으면_반환() {
        // given
        let arguments = ["gazerow", "--target-bundle-id", "com.apple.finder"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertEqual(sut.targetBundleIdentifier, "com.apple.finder")
    }

    func test_init_targetBundleId_값이없으면_nil() {
        // given
        let arguments = ["gazerow", "--target-bundle-id"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertNil(sut.targetBundleIdentifier)
    }

    func test_init_targetBundleId_다음값이다른옵션이면_nil() {
        // given
        let arguments = ["gazerow", "--target-bundle-id", "--show-overlay-on-launch"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertNil(sut.targetBundleIdentifier)
    }

    func test_init_printOverlayLabelMap_인자가있으면_true() {
        // given
        let arguments = ["gazerow", "--print-overlay-label-map"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertTrue(sut.printsOverlayLabelMap)
    }

    func test_init_printHotKeyRegistration_인자가있으면_true() {
        // given
        let arguments = ["gazerow", "--print-hotkey-registration"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertTrue(sut.printsHotKeyRegistration)
    }

    func test_isHotKeyRegistrationProbeOnly_printHotKeyRegistration만_있으면_true() {
        // given
        let arguments = ["gazerow", "--print-hotkey-registration"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertTrue(sut.isHotKeyRegistrationProbeOnly)
    }

    func test_isHotKeyRegistrationProbeOnly_다른평가옵션이_있으면_false() {
        // given
        let arguments = ["gazerow", "--print-hotkey-registration", "--show-overlay-on-launch"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertFalse(sut.isHotKeyRegistrationProbeOnly)
    }

    func test_init_printOverlayLabelMap_인자가없으면_false() {
        // given
        let arguments = ["gazerow"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertFalse(sut.printsOverlayLabelMap)
    }

    func test_init_clickOverlayLabel_값이있으면_반환() {
        // given
        let arguments = ["gazerow", "--click-overlay-label", "AK"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertEqual(sut.clickOverlayLabel, "AK")
    }

    func test_init_clickOverlayLabel_값이없으면_nil() {
        // given
        let arguments = ["gazerow", "--click-overlay-label"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertNil(sut.clickOverlayLabel)
    }

    func test_init_clickOverlayLabel_다음값이다른옵션이면_nil() {
        // given
        let arguments = ["gazerow", "--click-overlay-label", "--show-overlay-on-launch"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertNil(sut.clickOverlayLabel)
    }

    func test_init_queryText_값이있으면_반환() {
        // given
        let arguments = ["gazerow", "--query-type-text", "--query-text", "explorer"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertEqual(sut.queryText, "explorer")
    }

    func test_init_queryText_값이없으면_nil() {
        // given
        let arguments = ["gazerow", "--query-text"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertNil(sut.queryText)
    }

    func test_init_queryScopePin_올바른값이면_scope를_반환() {
        // given
        let arguments = ["gazerow", "--query-scope-pin", "windows"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertEqual(sut.queryScopePin, .windows)
    }

    func test_init_queryScopePin_알수없는값이면_nil() {
        // given
        let arguments = ["gazerow", "--query-scope-pin", "unknown"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertNil(sut.queryScopePin)
    }

    func test_init_performQueryConfirm_인자가있으면_true() {
        // given
        let arguments = ["gazerow", "--perform-query-confirm"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertTrue(sut.performQueryConfirm)
    }

    func test_isHotKeyRegistrationProbeOnly_query옵션이_있으면_false() {
        // given
        let arguments = ["gazerow", "--print-hotkey-registration", "--query-text", "finder"]

        // when
        let sut = AppLaunchOptions(arguments: arguments)

        // then
        XCTAssertFalse(sut.isHotKeyRegistrationProbeOnly)
    }
}
