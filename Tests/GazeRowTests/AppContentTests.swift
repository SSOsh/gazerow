import XCTest
@testable import GazeRow

/// 사용자 노출 정적 콘텐츠의 평가 결과 반영을 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class AppContentTests: XCTestCase {

    func test_사용자표시이름은_gazerow다() {
        XCTAssertEqual(AppState.appName, "gazerow")
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

    func test_supportDonationContent는_후원계좌와_버튼문구를_제공한다() {
        // given
        let message = AppContent.supportDonationMessage

        // when & then
        XCTAssertEqual(AppContent.supportDonationMenuTitle, "Support gazerow")
        XCTAssertEqual(AppContent.supportDonationTitle, "Support gazerow")
        XCTAssertEqual(AppContent.supportDonationBankName, "카카오뱅크")
        XCTAssertEqual(AppContent.supportDonationAccountNumber, "3333-26-7184989")
        XCTAssertTrue(message.contains("커피값 후원"))
        XCTAssertTrue(message.contains("카카오뱅크 3333-26-7184989"))

        let english = AppContent.localized(for: .english)
        XCTAssertEqual(english.supportDonationCopyButton, "Copy Account Number")
        XCTAssertEqual(english.supportDonationCloseButton, "Close")

        let korean = AppContent.localized(for: .korean)
        XCTAssertEqual(korean.supportDonationCopyButton, "계좌번호 복사")
        XCTAssertEqual(korean.supportDonationCloseButton, "닫기")
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
        XCTAssertTrue(korean.queryKeyHint(for: .labels, enterActionHint: korean.enterActionClick).contains("/ 요소"))
        XCTAssertTrue(korean.queryKeyHint(for: .labels, enterActionHint: korean.enterActionClick).contains("; 창"))
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
            "Click failed: no focused target. Type a label or press Tab first."
        )
        XCTAssertEqual(
            content.clickFailureText(.missingFocusedTarget(index: -1)),
            "Click failed: no focused target. Type a label or press Tab first."
        )
        XCTAssertEqual(
            content.clickExecutionFailureText(.missingPressAction),
            "Click failed: no supported action. Try another label."
        )
        XCTAssertEqual(
            content.overlaySecondConfirmText(.destructive),
            "Press Return again for destructive action"
        )
        XCTAssertEqual(
            content.clickFailureText(.selectedTargetUnavailable(labelID: 1)),
            "The selected element is no longer available. Labels were refreshed."
        )
        XCTAssertEqual(
            content.clickFailureText(.selectedTargetChanged(labelID: 1)),
            "The screen changed, so labels were refreshed. Select again."
        )
        XCTAssertEqual(
            content.clickFailureText(.selectedTargetAmbiguous(labelID: 1)),
            "The target could not be identified safely, so no click was performed."
        )
    }

    func test_clickFailureText_korean은_한국어문구를_제공한다() {
        // given
        let content = AppContent.localized(for: .korean)

        // when & then
        XCTAssertEqual(
            content.clickFailureText(.missingFocusedTarget(index: -1)),
            "클릭 실패: 포커스된 대상이 없습니다. 라벨을 입력하거나 먼저 Tab을 누르세요."
        )
        XCTAssertEqual(
            content.clickExecutionFailureText(.missingPressAction),
            "클릭 실패: 지원되는 동작이 없습니다. 다른 라벨을 선택하세요."
        )
        XCTAssertEqual(
            content.overlaySecondConfirmText(.destructive),
            "파괴적 동작을(를) 실행하려면 Return을 다시 누르세요"
        )
        XCTAssertEqual(
            content.clickFailureText(.selectedTargetUnavailable(labelID: 1)),
            "선택한 요소가 더 이상 없습니다. 라벨을 갱신했습니다."
        )
        XCTAssertEqual(
            content.clickFailureText(.selectedTargetChanged(labelID: 1)),
            "화면이 변경되어 라벨을 갱신했습니다. 다시 선택하세요."
        )
        XCTAssertEqual(
            content.clickFailureText(.selectedTargetAmbiguous(labelID: 1)),
            "대상을 확실히 구분할 수 없어 클릭하지 않았습니다."
        )
    }
}
