/// gaze focus 실행 전 선행 조건(opt-in·카메라 권한·캘리브레이션)을 순서대로 검사한다.
///
/// UI/카메라 의존이 없는 순수 판정 타입이라 단위 테스트가 쉽다. AppDelegate는 이
/// 판정 결과에 따라 실제 overlay/카메라 동선을 실행한다.
///
/// @author suho.do
/// @since 2026-07-03
struct GazeActivationGate {
    let isOptInEnabled: () -> Bool
    let isCameraAuthorized: () -> Bool
    let isCalibrationReady: () -> Bool

    /// 선행 조건을 우선순위 순서(opt-in → 권한 → 캘리브레이션)로 검사한다.
    func evaluate() -> GazeActivationDecision {
        guard isOptInEnabled() else {
            return .blocked(.optInDisabled)
        }
        guard isCameraAuthorized() else {
            return .blocked(.cameraPermissionDenied)
        }
        guard isCalibrationReady() else {
            return .blocked(.calibrationUnavailable)
        }
        return .proceed
    }
}

/// gaze 실행 게이트 판정 결과.
///
/// @author suho.do
/// @since 2026-07-03
enum GazeActivationDecision: Equatable {
    case proceed
    case blocked(GazeActivationBlockReason)
}

/// gaze 실행이 차단된 사유.
///
/// @author suho.do
/// @since 2026-07-03
enum GazeActivationBlockReason: Equatable {
    case optInDisabled
    case cameraPermissionDenied
    case calibrationUnavailable
}
