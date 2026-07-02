import XCTest
@testable import GazeRow

/// `PermissionManager`의 상태 조회/갱신/gate 로직 단위 테스트.
///
/// 시스템 API `AXIsProcessTrusted` 대신 `trustCheck` 클로저를 주입해
/// granted/notGranted 상태를 결정론적으로 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class PermissionManagerTests: XCTestCase {

    // MARK: - 초기화

    func test_초기화_권한있음_granted_상태와_activation_허용() {
        // given
        let sut = PermissionManager(trustCheck: { true })

        // when & then
        XCTAssertEqual(sut.accessibilityStatus, .granted)
        XCTAssertTrue(sut.canActivateOverlay)
        XCTAssertNil(sut.overlayUnavailableReason)
    }

    func test_초기화_권한없음_notGranted_상태와_activation_차단() {
        // given
        let sut = PermissionManager(trustCheck: { false })

        // when & then
        XCTAssertEqual(sut.accessibilityStatus, .notGranted)
        XCTAssertFalse(sut.canActivateOverlay)
        XCTAssertNotNil(sut.overlayUnavailableReason)
    }

    // MARK: - refresh

    func test_refresh_권한없음에서_부여됨으로_변경_반영() {
        // given
        var trusted = false
        let sut = PermissionManager(trustCheck: { trusted })
        XCTAssertEqual(sut.accessibilityStatus, .notGranted)

        // when
        trusted = true
        sut.refresh()

        // then
        XCTAssertEqual(sut.accessibilityStatus, .granted)
        XCTAssertTrue(sut.canActivateOverlay)
    }

    func test_refresh_권한부여에서_철회됨으로_변경_반영() {
        // given
        var trusted = true
        let sut = PermissionManager(trustCheck: { trusted })
        XCTAssertEqual(sut.accessibilityStatus, .granted)

        // when
        trusted = false
        sut.refresh()

        // then
        XCTAssertEqual(sut.accessibilityStatus, .notGranted)
        XCTAssertFalse(sut.canActivateOverlay)
    }

    // MARK: - 안내 문구

    func test_overlayUnavailableReason_권한없을때_안내문구_제공() {
        // given
        let sut = PermissionManager(trustCheck: { false })

        // when
        let reason = sut.overlayUnavailableReason

        // then
        XCTAssertEqual(reason, AppState.accessibilityRationale)
    }
}
