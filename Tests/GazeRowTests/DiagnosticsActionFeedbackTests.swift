import XCTest
@testable import GazeRow

/// `DiagnosticsActionFeedback`의 사용자 표시 메시지 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class DiagnosticsActionFeedbackTests: XCTestCase {

    func test_초기상태_message는_nil() {
        // given
        let sut = DiagnosticsActionFeedback()

        // then
        XCTAssertNil(sut.message)
    }

    func test_didDeleteLogs_삭제완료_message_기록() {
        // given
        var sut = DiagnosticsActionFeedback()

        // when
        sut.didDeleteLogs()

        // then
        XCTAssertEqual(sut.message, "Interaction logs deleted.")
    }

    func test_didCreateDebugExport_생성완료_message_기록() {
        // given
        var sut = DiagnosticsActionFeedback()

        // when
        sut.didCreateDebugExport()

        // then
        XCTAssertEqual(sut.message, "Debug export created.")
    }

    func test_didFailDebugExport_생성실패_message_기록() {
        // given
        var sut = DiagnosticsActionFeedback()

        // when
        sut.didFailDebugExport()

        // then
        XCTAssertEqual(sut.message, "Debug export failed.")
    }

    func test_didDeleteDebugExport_삭제완료_message_기록() {
        // given
        var sut = DiagnosticsActionFeedback()

        // when
        sut.didDeleteDebugExport()

        // then
        XCTAssertEqual(sut.message, "Debug export deleted.")
    }
}
