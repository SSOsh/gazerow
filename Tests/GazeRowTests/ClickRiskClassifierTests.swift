import CoreGraphics
import XCTest
@testable import GazeRow

/// ClickRiskClassifier 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class ClickRiskClassifierTests: XCTestCase {

    func test_classify_press_button은_safeNavigation() {
        // given
        let target = clickTarget(title: "Open", actions: [AccessibilityAction.press])
        let sut = ClickRiskClassifier()

        // when
        let riskClass = sut.classify(target)

        // then
        XCTAssertEqual(riskClass, .safeNavigation)
    }

    func test_classify_checkbox는_stateChange() {
        // given
        let target = clickTarget(
            role: AccessibilityRole.checkBox,
            title: "Enabled",
            actions: [AccessibilityAction.press]
        )
        let sut = ClickRiskClassifier()

        // when
        let riskClass = sut.classify(target)

        // then
        XCTAssertEqual(riskClass, .stateChange)
    }

    func test_classify_delete_keyword는_destructive() {
        // given
        let target = clickTarget(title: "Delete Project", actions: [AccessibilityAction.press])
        let sut = ClickRiskClassifier()

        // when
        let riskClass = sut.classify(target)

        // then
        XCTAssertEqual(riskClass, .destructive)
    }

    func test_classify_send_keyword는_externalEffect() {
        // given
        let target = clickTarget(title: "Send Message", actions: [AccessibilityAction.press])
        let sut = ClickRiskClassifier()

        // when
        let riskClass = sut.classify(target)

        // then
        XCTAssertEqual(riskClass, .externalEffect)
    }

    func test_classify_action이_없으면_unknownRisk() {
        // given
        let target = clickTarget(title: "Mystery", actions: [])
        let sut = ClickRiskClassifier()

        // when
        let riskClass = sut.classify(target)

        // then
        XCTAssertEqual(riskClass, .unknownRisk)
    }

    private func clickTarget(
        role: String = AccessibilityRole.button,
        title: String?,
        actions: [String]
    ) -> ClickTarget<Int> {
        ClickTarget(
            element: 1,
            role: role,
            title: title,
            frame: CGRect(x: 10, y: 20, width: 30, height: 40),
            actions: actions
        )
    }
}
