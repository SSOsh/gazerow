import OSLog

/// OSLog 기반 로깅 wrapper.
///
/// TICKET-001 범위에서는 app lifecycle 로그만 다룬다.
/// Interaction 로그 파일 저장, 개인정보 관련 로그는 TICKET-008에서 별도로 처리한다.
///
/// - Note: raw camera, raw window title, text value 등은 이 wrapper로 기록하지 않는다.
///
/// @author suho.do
/// @since 2026-07-02
enum AppLogger {

    /// 로그 subsystem. bundle identifier와 정렬한다.
    private static let subsystem = "dev.local.gazerow"

    /// app 실행/종료, settings open 등 lifecycle 이벤트 로거.
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")

    /// 세션 활성/비활성(kill switch) 상태 변화 로거.
    static let session = Logger(subsystem: subsystem, category: "session")

    /// Accessibility 등 권한 상태 변화 로거.
    static let permission = Logger(subsystem: subsystem, category: "permission")

    /// overlay open/close 등 표시 상태 로거.
    static let overlay = Logger(subsystem: subsystem, category: "overlay")

    /// interaction(focus/click) 관련 Info 로거.
    ///
    /// - Note: raw window title, text value 등 민감정보는 이 로거로 기록하지 않는다.
    static let interaction = Logger(subsystem: subsystem, category: "interaction")

    /// gaze focus activation 관련 로거.
    ///
    /// - Note: raw camera frame이나 얼굴 이미지는 이 로거로 기록하지 않는다.
    static let gaze = Logger(subsystem: subsystem, category: "gaze")
}
