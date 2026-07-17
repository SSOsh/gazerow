import AppKit

/// 후원 계좌번호를 시스템 클립보드에 저장한다.
///
/// @author suho.do
/// @since 2026-07-17
struct SupportDonationClipboard {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    /// 기존 클립보드 내용을 지운 뒤 계좌번호만 일반 문자열로 복사한다.
    @discardableResult
    func copyAccountNumber() -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(
            AppContent.supportDonationAccountNumber,
            forType: .string
        )
    }
}
