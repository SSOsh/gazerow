import CoreGraphics
import Foundation

/// AX scan 실행 경계를 넘길 대상 창의 비식별 snapshot.
///
/// AXUIElement, 앱명, 창 제목은 포함하지 않는다.
///
/// @author suho.do
/// @since 2026-07-17
struct AccessibilityScanTarget: Equatable, Sendable {
    let processIdentifier: pid_t
    let bundleIdentifier: String
    let windowFrame: CGRect

    init(context: TargetContext) {
        processIdentifier = context.application.processIdentifier
        bundleIdentifier = context.application.bundleIdentifier
        windowFrame = context.window.frame
    }
}

/// 직렬 AX runtime에 전달할 scan 요청 값.
///
/// @author suho.do
/// @since 2026-07-17
struct AccessibilityScanRequest: Equatable, Sendable {
    let activationID: UUID
    let target: AccessibilityScanTarget
    let configuration: AccessibilityScanConfiguration

    init(
        activationID: UUID,
        context: TargetContext,
        configuration: AccessibilityScanConfiguration = AccessibilityScanConfiguration()
    ) {
        self.activationID = activationID
        self.target = AccessibilityScanTarget(context: context)
        self.configuration = configuration
    }
}

/// AX scan 실행 결과를 AX 객체 없이 전달하는 값.
///
/// @author suho.do
/// @since 2026-07-17
enum AccessibilityScanExecutionOutcome: Equatable, Sendable {
    case success(AccessibilityScanResult)
    case failure(AccessibilityScanFailure)
}

/// AX runtime에서 UI actor로 돌려보내는 scan 응답 값.
///
/// @author suho.do
/// @since 2026-07-17
struct AccessibilityScanResponse: Equatable, Sendable {
    let activationID: UUID
    let outcome: AccessibilityScanExecutionOutcome
}
