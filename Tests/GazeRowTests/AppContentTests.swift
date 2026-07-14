import XCTest
@testable import GazeRow

/// 사용자 노출 정적 콘텐츠의 평가 결과 반영을 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class AppContentTests: XCTestCase {

    func test_사용자표시이름은_keyCursor다() {
        XCTAssertEqual(AppState.appName, "keyCursor")
    }

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

    func test_knownLimitations은_검증된중앙좌표클릭정책을_안내한다() {
        // given
        let english = AppContent.localized(for: .english)
        let korean = AppContent.localized(for: .korean)

        // when
        let englishLimitations = english.knownLimitations.joined(separator: "\n")
        let koreanLimitations = korean.knownLimitations.joined(separator: "\n")

        // then
        XCTAssertTrue(englishLimitations.contains("verified target's center coordinate"))
        XCTAssertTrue(englishLimitations.contains("no click is sent"))
        XCTAssertTrue(koreanLimitations.contains("현재 대상의 중앙 좌표"))
        XCTAssertTrue(koreanLimitations.contains("클릭하지 않고 라벨을 갱신"))
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
        XCTAssertTrue(joined.contains("Keyboard layout is handled automatically"))
        XCTAssertTrue(joined.contains("/ to search elements"))
        XCTAssertTrue(joined.contains("; to switch windows"))
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
        XCTAssertEqual(AppContent.supportDonationMenuTitle, "Support keyCursor")
        XCTAssertEqual(AppContent.supportDonationTitle, "Support keyCursor")
        XCTAssertTrue(message.contains("커피값 후원"))
        XCTAssertTrue(message.contains("계좌번호는 추후 추가 예정"))
    }

    func test_localized_english는_기존영문콘텐츠를_제공한다() {
        // given
        let content = AppContent.localized(for: .english)

        // when & then
        XCTAssertEqual(content.languageLabel, "Language")
        XCTAssertEqual(content.permissionsTitle, "Permissions")
        XCTAssertTrue(content.overlayUsageSteps.joined(separator: "\n").contains("Keyboard layout is handled automatically"))
    }

    func test_localized_korean은_한국어설정콘텐츠를_제공한다() {
        // given
        let content = AppContent.localized(for: .korean)
        let appText = AppState.localized(for: .korean)

        // when & then
        XCTAssertEqual(content.languageLabel, "언어")
        XCTAssertEqual(content.permissionsTitle, "권한")
        XCTAssertTrue(content.overlayUsageSteps.joined(separator: "\n").contains("자동으로 처리"))
        XCTAssertTrue(content.overlayUsageSteps.joined(separator: "\n").contains(";를 누르면 창을 전환"))
        XCTAssertTrue(appText.privacyNotice.contains("화면 녹화"))
    }

    func test_tutorialContent는_한영모두동일한키정책을제공한다() {
        // given
        let english = AppContent.localized(for: .english)
        let korean = AppContent.localized(for: .korean)

        // when & then
        XCTAssertTrue(english.tutorialDescription(for: .modePractice).contains("/"))
        XCTAssertTrue(english.tutorialDescription(for: .modePractice).contains(";"))
        XCTAssertTrue(korean.tutorialDescription(for: .modePractice).contains("/"))
        XCTAssertTrue(korean.tutorialDescription(for: .modePractice).contains(";"))
        XCTAssertEqual(english.replayTutorialButton, "Replay tutorial")
        XCTAssertEqual(korean.replayTutorialButton, "튜토리얼 다시 보기")
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
        XCTAssertTrue(english.queryMatchSummary(count: 2, index: 1, displayName: "Delete").contains("Delete"))
        // 겨냥 요약은 매칭 개수/인덱스 없이 대상 이름만 보여 검색 요약과 구분된다.
        XCTAssertEqual(english.gazeTargetSummary(displayName: "Save Draft"), "Aiming · Save Draft")
        XCTAssertEqual(korean.gazeTargetSummary(displayName: "Save Draft"), "겨냥 · Save Draft")
    }

    func test_setupReadinessContent는_상태별_다음행동을_제공한다() {
        // given
        let english = AppContent.localized(for: .english)
        let korean = AppContent.localized(for: .korean)

        // when & then
        XCTAssertEqual(english.setupReadinessTitle, "Setup Status")
        XCTAssertTrue(english.setupReadinessDetail(for: .permissionRequired).contains("Recheck"))
        XCTAssertTrue(english.setupReadinessDetail(for: .sessionDisabled).contains("Enable"))
        XCTAssertTrue(english.setupReadinessDetail(for: .ready).contains(OverlayActivationShortcut.activationDisplayName))

        XCTAssertEqual(korean.setupReadinessTitle, "설정 상태")
        XCTAssertTrue(korean.setupReadinessHeadline(for: .permissionRequired).contains("손쉬운 사용"))
        XCTAssertEqual(korean.setupReadinessBadge(for: .ready), korean.readyBadge)
    }
}
