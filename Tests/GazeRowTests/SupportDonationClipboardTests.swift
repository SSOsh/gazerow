import AppKit
import XCTest
@testable import GazeRow

/// 후원 계좌번호 클립보드 복사를 검증한다.
///
/// @author suho.do
/// @since 2026-07-17
final class SupportDonationClipboardTests: XCTestCase {

    func test_copyAccountNumber는_계좌번호만_클립보드에_저장한다() {
        // given
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("gazerow.support-donation.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
        pasteboard.setString("기존 내용", forType: .string)
        let sut = SupportDonationClipboard(pasteboard: pasteboard)

        // when
        let result = sut.copyAccountNumber()

        // then
        XCTAssertTrue(result)
        XCTAssertEqual(
            pasteboard.string(forType: .string),
            AppContent.supportDonationAccountNumber
        )
        XCTAssertFalse(pasteboard.string(forType: .string)?.contains("카카오뱅크") == true)
    }
}
