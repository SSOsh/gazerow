@preconcurrency import AVFoundation
import XCTest
@testable import GazeRow

/// CameraPermissionManager 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
@MainActor
final class CameraPermissionManagerTests: XCTestCase {

    func test_refresh_시스템권한상태를_반영() {
        // given
        var status = AVAuthorizationStatus.denied
        let sut = CameraPermissionManager(
            authorizationStatusProvider: { status },
            accessRequester: { completion in completion(false) }
        )

        // when
        status = .authorized
        sut.refresh()

        // then
        XCTAssertEqual(sut.cameraStatus, .authorized)
    }

    func test_requestCameraPermission_승인되면_authorized() async {
        // given
        let sut = CameraPermissionManager(
            authorizationStatusProvider: { .notDetermined },
            accessRequester: { completion in completion(true) }
        )

        // when
        await sut.requestCameraPermission()

        // then
        XCTAssertEqual(sut.cameraStatus, .authorized)
    }

    func test_requestCameraPermission_거부되면_provider상태를_반영() async {
        // given
        let sut = CameraPermissionManager(
            authorizationStatusProvider: { .denied },
            accessRequester: { completion in completion(false) }
        )

        // when
        await sut.requestCameraPermission()

        // then
        XCTAssertEqual(sut.cameraStatus, .denied)
    }
}
