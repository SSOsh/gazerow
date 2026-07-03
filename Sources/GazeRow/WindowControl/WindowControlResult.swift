/// window control 동작 실행 결과.
///
/// @author suho.do
/// @since 2026-07-02
enum WindowControlResult: Equatable {
    /// 버튼 press 성공.
    case success
    /// Accessibility 권한이 없어 실행 불가.
    case permissionDenied
    /// frontmost 앱의 focused/main window를 얻지 못함.
    case windowUnavailable
    /// 창에 해당 컨트롤 버튼 attribute가 없음(예: 최소화 불가 창).
    case controlUnavailable
    /// AX press action이 실패함. 연결 값은 디버그 설명.
    case actionFailed(String)

    /// 성공 여부.
    var isSuccess: Bool {
        self == .success
    }

    /// 로그용 짧은 코드(원문 저장 없음).
    var logCode: String {
        switch self {
        case .success:
            return "success"
        case .permissionDenied:
            return "permission_denied"
        case .windowUnavailable:
            return "window_unavailable"
        case .controlUnavailable:
            return "control_unavailable"
        case .actionFailed:
            return "action_failed"
        }
    }
}
