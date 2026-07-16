import XCTest
@testable import GazeRow

/// command bar 상태별 문구와 key hint 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-13
final class OverlayCommandBarPresentationTests: XCTestCase {

    func test_idleLabels는_label과_primer를표시한다() {
        // given
        let status = OverlayInteractionStatus(phase: .idle)

        // when
        let result = OverlayCommandBarPresentation(
            status: status,
            content: AppContent.localized(for: .korean)
        )

        // then
        XCTAssertEqual(result.modeTitle, "라벨")
        XCTAssertEqual(result.summaryText, "라벨 키를 입력하세요")
        XCTAssertEqual(result.keyHints.map(\.key), ["A-Z", "/", ";", "Esc"])
        XCTAssertEqual(result.keyHints.map(\.action), ["선택", "요소 검색", "창 전환", "닫기"])
    }

    func test_matchingWindow는_Return을창전환으로표시한다() {
        // given
        let status = OverlayInteractionStatus(
            queryBuffer: "safari",
            activeScope: .windows,
            matchCount: 3,
            matchIndex: 1,
            focusedDisplayName: "Safari",
            enterActionHint: "switch window",
            phase: .matching
        )

        // when
        let result = OverlayCommandBarPresentation(
            status: status,
            content: AppContent.localized(for: .korean)
        )

        // then
        XCTAssertEqual(result.modeTitle, "창 전환")
        XCTAssertEqual(result.keyHints.first, OverlayKeyHint(key: "Return", action: "창 전환", priority: 0))
        XCTAssertEqual(result.keyHints.count, 5)
    }

    func test_noMatches는_Return을표시하지않는다() {
        // given
        let status = OverlayInteractionStatus(
            queryBuffer: "missing",
            activeScope: .elements,
            phase: .noMatches
        )

        // when
        let result = OverlayCommandBarPresentation(
            status: status,
            content: AppContent.localized(for: .english)
        )

        // then
        XCTAssertEqual(result.summaryText, "No element matches")
        XCTAssertFalse(result.keyHints.contains { $0.key == "Return" })
        XCTAssertEqual(result.keyHints.map(\.key), ["Delete", ";", "Esc"])
    }

    func test_위험확인은_재확인과취소만우선표시한다() {
        // given
        let status = OverlayInteractionStatus(
            activeScope: .labels,
            message: "Delete requires confirmation",
            tone: .warning,
            phase: .awaitingRiskConfirmation,
            requiresSecondConfirm: true
        )

        // when
        let result = OverlayCommandBarPresentation(
            status: status,
            content: AppContent.localized(for: .korean)
        )

        // then
        XCTAssertEqual(result.summaryText, "위험 동작입니다")
        XCTAssertEqual(result.keyHints.map(\.key), ["Return", "Esc"])
        XCTAssertEqual(result.keyHints.map(\.action), ["다시 확인", "취소"])
        XCTAssertEqual(result.helperText, "Delete requires confirmation")
    }

    func test_영문idle은_영문문구를사용한다() {
        // given
        let status = OverlayInteractionStatus(phase: .idle)

        // when
        let result = OverlayCommandBarPresentation(
            status: status,
            content: AppContent.localized(for: .english)
        )

        // then
        XCTAssertEqual(result.modeTitle, "Labels")
        XCTAssertEqual(result.summaryText, "Type a label key")
        XCTAssertEqual(result.helperText, "Type a label, then press Return to click")
    }
}
