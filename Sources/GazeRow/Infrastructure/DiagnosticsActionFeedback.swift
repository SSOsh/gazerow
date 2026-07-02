import Foundation

/// Diagnostics 섹션에서 사용자의 수동 액션 결과를 짧게 표시하는 상태.
///
/// 파일 경로나 원문 window title 같은 민감정보를 표시하지 않고, 성공/실패 여부만
/// 사용자에게 알려준다.
///
/// @author suho.do
/// @since 2026-07-02
struct DiagnosticsActionFeedback: Equatable {

    /// 사용자에게 표시할 최근 diagnostics 액션 결과.
    private(set) var message: String?

    /// interaction 로그 삭제 완료 상태를 기록한다.
    mutating func didDeleteLogs() {
        message = "Interaction logs deleted."
    }

    /// debug export 생성 완료 상태를 기록한다.
    mutating func didCreateDebugExport() {
        message = "Debug export created."
    }

    /// debug export 생성 실패 상태를 기록한다.
    mutating func didFailDebugExport() {
        message = "Debug export failed."
    }

    /// debug export 삭제 완료 상태를 기록한다.
    mutating func didDeleteDebugExport() {
        message = "Debug export deleted."
    }
}
