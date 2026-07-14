import XCTest
@testable import GazeRow

/// 사용자 노출 정적 콘텐츠의 평가 결과 반영을 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class AppContentTests: XCTestCase {

    func test_appSupport_Ticket010통과앱을_supported로_표시한다() {
        // given
        let supportByName = Dictionary(
            uniqueKeysWithValues: AppContent.appSupport.map { ($0.name, $0.tier) }
        )

        // when & then
        XCTAssertEqual(supportByName["Finder"], .supported)
        XCTAssertEqual(supportByName["VS Code"], .supported)
        XCTAssertEqual(supportByName["Safari"], .supported)
        XCTAssertEqual(supportByName["Chrome"], .supported)
        XCTAssertEqual(supportByName["System Settings"], .supported)
        XCTAssertEqual(supportByName["Slack"], .supported)
        XCTAssertEqual(supportByName["Notion"], .supported)
        XCTAssertEqual(supportByName["Discord"], .limited)
        XCTAssertEqual(supportByName["Obsidian"], .unverified)
    }

    func test_knownLimitations_PostMVP제한앱을_포함한다() {
        // given
        let limitations = AppContent.knownLimitations.joined(separator: "\n")

        // when & then
        XCTAssertTrue(limitations.contains("Discord now exposes app UI candidates"))
        XCTAssertTrue(limitations.contains("representative click task still needs verification"))
    }

    func test_overlayUsageSteps_핵심조작을_순서대로_안내한다() {
        // given
        let steps = AppContent.overlayUsageSteps
        let joined = steps.joined(separator: "\n")

        // when & then
        XCTAssertFalse(steps.isEmpty)
        XCTAssertTrue(joined.contains("label"))
        XCTAssertTrue(joined.contains("Return"))
        XCTAssertTrue(joined.contains("Esc"))
        XCTAssertTrue(joined.contains("physical key"))
    }

    func test_windowControlShortcutsNotice_frontmost창과_권한조건을_안내한다() {
        // given
        let notice = AppContent.windowControlShortcutsNotice

        // when & then
        XCTAssertTrue(notice.contains("frontmost window"))
        XCTAssertTrue(notice.contains("Accessibility"))
    }

    func test_supportDonationContent는_커피값후원과_계좌번호추후추가를_안내한다() {
        // given
        let message = AppContent.supportDonationMessage

        // when & then
        XCTAssertEqual(AppContent.supportDonationMenuTitle, "Support GazeRow")
        XCTAssertEqual(AppContent.supportDonationTitle, "Support GazeRow")
        XCTAssertTrue(message.contains("커피값 후원"))
        XCTAssertTrue(message.contains("계좌번호는 추후 추가 예정"))
    }

    func test_localized_english는_기존영문콘텐츠를_제공한다() {
        // given
        let content = AppContent.localized(for: .english)

        // when & then
        XCTAssertEqual(content.languageLabel, "Language")
        XCTAssertEqual(content.permissionsTitle, "Permissions")
        XCTAssertTrue(content.overlayUsageSteps.joined(separator: "\n").contains("physical key"))
    }

    func test_localized_korean은_한국어설정콘텐츠를_제공한다() {
        // given
        let content = AppContent.localized(for: .korean)
        let appText = AppState.localized(for: .korean)

        // when & then
        XCTAssertEqual(content.languageLabel, "언어")
        XCTAssertEqual(content.permissionsTitle, "권한")
        XCTAssertTrue(content.overlayUsageSteps.joined(separator: "\n").contains("한글 키보드"))
        XCTAssertTrue(appText.privacyNotice.contains("화면 녹화"))
    }

    func test_queryOverlayContent는_한영_scope와_hint를_제공한다() {
        // given
        let english = AppContent.localized(for: .english)
        let korean = AppContent.localized(for: .korean)

        // when & then
        XCTAssertEqual(english.queryScopeTitle(.windows), "Windows")
        XCTAssertEqual(english.queryScopeTitle(.elements), "Elements")
        XCTAssertEqual(english.queryScopeTitle(.labels), "Labels")
        XCTAssertEqual(korean.queryScopeTitle(.windows), "창")
        XCTAssertEqual(korean.queryScopeTitle(.elements), "요소")
        XCTAssertEqual(korean.queryScopeTitle(.labels), "라벨")
        XCTAssertEqual(korean.queryNoMatch, "매칭 없음")
        XCTAssertTrue(korean.queryKeyHint(for: .windows, enterActionHint: korean.enterActionSwitchWindow).contains("창 전환"))
        XCTAssertTrue(korean.queryKeyHint(for: .labels, enterActionHint: korean.enterActionClick).contains("/ 요소"))
        XCTAssertTrue(korean.queryKeyHint(for: .labels, enterActionHint: korean.enterActionClick).contains("; 창"))
        XCTAssertTrue(english.queryMatchSummary(count: 2, index: 1, displayName: "Delete").contains("Delete"))
    }

    func test_queryScopeRole는_각scope의_역할을_한영으로_설명한다() {
        // given
        let english = AppContent.localized(for: .english)
        let korean = AppContent.localized(for: .korean)

        // when & then
        XCTAssertEqual(english.queryScopeRole(.labels), "Aim a label to click")
        XCTAssertEqual(english.queryScopeRole(.elements), "Search elements by name")
        XCTAssertEqual(english.queryScopeRole(.windows), "Search windows to switch")
        XCTAssertEqual(korean.queryScopeRole(.labels), "라벨을 겨냥해 클릭")
        XCTAssertEqual(korean.queryScopeRole(.elements), "요소를 이름으로 검색")
        XCTAssertEqual(korean.queryScopeRole(.windows), "창을 이름으로 검색·전환")
    }

    func test_overlayStatusText_english는_기존영문문구를_유지한다() {
        // given
        let content = AppContent.localized(for: .english)

        // when & then
        XCTAssertEqual(content.overlayReadyText, "Ready")
        XCTAssertEqual(content.overlayInputClearedText, "Input cleared")
        XCTAssertEqual(content.overlayFocusedText, "Focused")
        XCTAssertEqual(content.overlayLabelsSelectedText, "Labels")
        XCTAssertEqual(content.overlayClickedText, "Clicked")
        XCTAssertEqual(content.overlayTypingText("AB"), "Typing AB")
        XCTAssertEqual(content.overlayNoLabelText("J"), "No label J")
        XCTAssertEqual(content.overlayPinnedText(.elements), "Pinned elements")
        XCTAssertEqual(content.overlayWindowActivatedText(appName: "Safari"), "Safari activated")
    }

    func test_overlayStatusText_korean은_한국어문구를_제공한다() {
        // given
        let content = AppContent.localized(for: .korean)

        // when & then
        XCTAssertEqual(content.overlayReadyText, "준비됨")
        XCTAssertEqual(content.overlayInputClearedText, "입력을 지웠습니다")
        XCTAssertEqual(content.overlayFocusedText, "포커스됨")
        XCTAssertEqual(content.overlayLabelsSelectedText, "라벨")
        XCTAssertEqual(content.overlayClickedText, "클릭함")
        XCTAssertEqual(content.overlayTypingText("AB"), "입력 중 AB")
        XCTAssertEqual(content.overlayNoLabelText("J"), "라벨 J 없음")
        XCTAssertEqual(content.overlayPinnedText(.elements), "요소 고정")
        XCTAssertEqual(content.overlayWindowActivatedText(appName: "Safari"), "Safari 활성화됨")
    }

    func test_clickFailureText_english는_기존영문문구를_유지한다() {
        // given
        let content = AppContent.localized(for: .english)

        // when & then
        XCTAssertEqual(content.clickSucceededText, "Click succeeded")
        XCTAssertEqual(
            content.clickResultText(.failure(.missingFocusedTarget(index: -1))),
            "Click failed: no focused target"
        )
        XCTAssertEqual(
            content.clickFailureText(.missingFocusedTarget(index: -1)),
            "Click failed: no focused target"
        )
        XCTAssertEqual(
            content.clickExecutionFailureText(.missingPressAction),
            "Click failed: no supported action"
        )
        XCTAssertEqual(
            content.overlaySecondConfirmText(.destructive),
            "Press Return again for destructive action"
        )
    }

    func test_clickFailureText_korean은_한국어문구를_제공한다() {
        // given
        let content = AppContent.localized(for: .korean)

        // when & then
        XCTAssertEqual(
            content.clickFailureText(.missingFocusedTarget(index: -1)),
            "클릭 실패: focus된 대상 없음"
        )
        XCTAssertEqual(
            content.clickExecutionFailureText(.missingPressAction),
            "클릭 실패: 지원되는 action 없음"
        )
        XCTAssertEqual(
            content.overlaySecondConfirmText(.destructive),
            "파괴적 동작을(를) 실행하려면 Return을 다시 누르세요"
        )
    }
}
