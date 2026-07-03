@preconcurrency import AVFoundation
import AppKit
import Observation

/// Camera 권한 상태를 조회/요청한다.
///
/// Camera gaze focus는 Post-MVP experimental 기능이므로 Settings opt-in 이후에만
/// `requestCameraPermission()`을 호출한다.
///
/// @author suho.do
/// @since 2026-07-03
@MainActor
@Observable
final class CameraPermissionManager {

    enum CameraStatus: Equatable {
        case authorized
        case notDetermined
        case denied
        case restricted

        var isAuthorized: Bool {
            self == .authorized
        }
    }

    private(set) var cameraStatus: CameraStatus

    private let authorizationStatusProvider: () -> AVAuthorizationStatus
    private let accessRequester: (@escaping @Sendable (Bool) -> Void) -> Void

    init(
        authorizationStatusProvider: @escaping () -> AVAuthorizationStatus = {
            AVCaptureDevice.authorizationStatus(for: .video)
        },
        accessRequester: @escaping (@escaping @Sendable (Bool) -> Void) -> Void = { completion in
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        }
    ) {
        self.authorizationStatusProvider = authorizationStatusProvider
        self.accessRequester = accessRequester
        self.cameraStatus = Self.map(authorizationStatusProvider())
    }

    func refresh() {
        cameraStatus = Self.map(authorizationStatusProvider())
    }

    func requestCameraPermission() async {
        let granted = await withCheckedContinuation { continuation in
            accessRequester { granted in
                continuation.resume(returning: granted)
            }
        }

        cameraStatus = granted ? .authorized : Self.map(authorizationStatusProvider())
    }

    func openCameraSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private static func map(_ status: AVAuthorizationStatus) -> CameraStatus {
        switch status {
        case .authorized:
            .authorized
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .restricted:
            .restricted
        @unknown default:
            .denied
        }
    }
}
