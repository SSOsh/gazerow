import CoreGraphics
import XCTest
@testable import GazeRow

/// AccessibilityScanConfiguration 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-12
final class AccessibilityScanModelsTests: XCTestCase {

    func test_ScanConfiguration_기본값은_넓은_AX트리를_수집할_여유를_둔다() {
        // given
        let sut = AccessibilityScanConfiguration()

        // then
        XCTAssertEqual(sut.maxDepth, 28)
        XCTAssertEqual(sut.maxNodes, 4_000)
        XCTAssertEqual(sut.timeout, 1.5)
    }

    func test_ScanConfiguration_음수값은_안전범위로_clamp한다() {
        // given
        let sut = AccessibilityScanConfiguration(maxDepth: -1, maxNodes: -1, timeout: -1)

        // then
        XCTAssertEqual(sut.maxDepth, 0)
        XCTAssertEqual(sut.maxNodes, 1)
        XCTAssertEqual(sut.timeout, 0)
    }

    func test_displayName_title이_있으면_title을_쓴다() {
        // given
        let sut = makeCandidate(title: "Save Draft")

        // then
        XCTAssertEqual(sut.displayName(index: 3), "Save Draft")
    }

    func test_displayName_title이_공백이면_role로_대체한다() {
        // given
        let sut = makeCandidate(role: AccessibilityRole.link, title: "   ")

        // then
        XCTAssertEqual(sut.displayName(index: 3), AccessibilityRole.link)
    }

    func test_displayName_title과_role이_비면_subrole로_대체한다() {
        // given
        let sut = makeCandidate(role: "  ", subrole: "AXSecureField", title: nil)

        // then
        XCTAssertEqual(sut.displayName(index: 3), "AXSecureField")
    }

    func test_displayName_모두_비면_Element와_index로_대체한다() {
        // given
        let sut = makeCandidate(role: "", subrole: "  ", title: nil)

        // then
        XCTAssertEqual(sut.displayName(index: 7), "Element 7")
    }

    func test_displayName_title_양끝_공백은_trim한다() {
        // given
        let sut = makeCandidate(title: "  Open  ")

        // then
        XCTAssertEqual(sut.displayName(index: 0), "Open")
    }

    private func makeCandidate(
        role: String = AccessibilityRole.button,
        subrole: String? = nil,
        title: String? = "Open"
    ) -> ClickableCandidate {
        ClickableCandidate(
            role: role,
            subrole: subrole,
            title: title,
            frame: CGRect(x: 0, y: 0, width: 10, height: 10),
            actions: [AccessibilityAction.press]
        )
    }
}
