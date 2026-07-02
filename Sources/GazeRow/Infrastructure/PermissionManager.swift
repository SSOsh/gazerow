import AppKit
import ApplicationServices
import Observation

/// Accessibility 권한 상태를 조회/요청/재확인하고, 관련 UX 진입점을 제공한다.
///
/// TICKET-002 범위. Accessibility 권한만 다룬다.
/// Camera(PR-003, Deferred)와 Input Monitoring(PR-002, 지연 요청)은
/// baseline 흐름에서 요청하지 않는다.
///
/// 시스템 권한 조회는 `trustCheck` 클로저로 주입해 단위 테스트가 가능하다.
///
/// - Note: 실제 overlay activation은 TICKET-005 이후 작업이다. 여기서는
///   `canActivateOverlay` gate와 안내 문구(`overlayUnavailableReason`)만 준비한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
@Observable
final class PermissionManager {

    /// Accessibility 권한 상태.
    enum AccessibilityStatus {
        /// 권한이 부여되어 AX tree 조회/AXPress가 가능한 상태.
        case granted
        /// 권한이 없어 overlay activation이 불가능한 상태.
        case notGranted
    }

    /// 현재 Accessibility 권한 상태. 외부에서는 읽기만 가능하다.
    private(set) var accessibilityStatus: AccessibilityStatus

    /// 시스템 권한 조회 함수. 기본값은 `AXIsProcessTrusted`.
    /// 테스트에서는 고정 Bool을 반환하는 클로저를 주입한다.
    private let trustCheck: () -> Bool

    /// Accessibility 권한 요청 프롬프트 실행 함수.
    /// 테스트에서는 호출 여부만 기록하는 클로저를 주입한다.
    private let permissionRequest: @MainActor () -> Void

    /// - Parameter trustCheck: Accessibility 신뢰 여부를 반환하는 클로저.
    ///   기본값은 `AXIsProcessTrusted()`이며, 프롬프트를 띄우지 않고 상태만 조회한다.
    init(
        trustCheck: @escaping () -> Bool = { AXIsProcessTrusted() },
        permissionRequest: @escaping @MainActor () -> Void = PermissionManager.requestSystemAccessibilityPermission
    ) {
        self.trustCheck = trustCheck
        self.permissionRequest = permissionRequest
        self.accessibilityStatus = trustCheck() ? .granted : .notGranted
    }

    // MARK: - Query

    /// 시스템 권한 상태를 다시 조회해 `accessibilityStatus`에 반영한다.
    ///
    /// 사용자가 System Settings에서 권한을 바꾼 뒤 앱으로 돌아오거나
    /// Recheck 버튼을 누를 때 호출한다.
    func refresh() {
        accessibilityStatus = trustCheck() ? .granted : .notGranted
    }

    /// overlay activation이 가능한지 여부. TICKET-005 이후 activation gate로 쓴다.
    var canActivateOverlay: Bool {
        accessibilityStatus == .granted
    }

    /// activation이 불가능한 이유 안내 문구. 가능하면 `nil`.
    ///
    /// PR-006에 따라 데이터 접근 범위를 기능 가치보다 먼저 설명한다.
    var overlayUnavailableReason: String? {
        canActivateOverlay ? nil : AppState.accessibilityRationale
    }

    // MARK: - Actions

    /// Accessibility 권한 요청 프롬프트를 띄운다.
    ///
    /// PR-001에 따라 첫 overlay activation 전 안내/요청 용도로 사용한다.
    /// 시스템이 System Settings로 유도하는 프롬프트를 표시하고, 이후 상태를 갱신한다.
    func requestAccessibilityPermission() {
        permissionRequest()
        refresh()
    }

    /// System Settings의 Accessibility 개인정보 보호 창을 연다.
    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private static func requestSystemAccessibilityPermission() {
        // kAXTrustedCheckOptionPrompt의 값. 전역 상수 직접 참조는 Swift 6
        // strict concurrency에서 non-Sendable var로 취급되어 문자열 값을 사용한다.
        let promptKey = "AXTrustedCheckOptionPrompt"
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
