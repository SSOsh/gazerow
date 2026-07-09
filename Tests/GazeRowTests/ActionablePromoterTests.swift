import CoreGraphics
import XCTest
@testable import GazeRow

/// ActionablePromoter 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-09
final class ActionablePromoterTests: XCTestCase {

    func test_promote_이미_actionable이면_direct를_반환한다() {
        // given
        let candidate = candidate(title: "Delete", frame: frame(x: 10, y: 10))
        let index = ElementSearchIndex(nodes: [
            node(id: 0, title: "Delete", frame: candidate.frame)
        ])
        let sut = ActionablePromoter()

        // when
        let result = sut.promote(searchNodeID: 0, index: index, actionableCandidates: [candidate])

        // then
        XCTAssertEqual(result.actionableCandidateIndex, 0)
        XCTAssertEqual(result.method, .direct)
    }

    func test_promote_parentID_chain에서_actionable_ancestor를_찾는다() {
        // given
        let rowFrame = frame(x: 10, y: 10, width: 200, height: 40)
        let rowCandidate = candidate(role: AccessibilityRole.row, title: "General Row", frame: rowFrame)
        let index = ElementSearchIndex(nodes: [
            node(id: 0, role: AccessibilityRole.row, title: "General Row", frame: rowFrame, childrenIDs: [1]),
            node(id: 1, role: "AXStaticText", title: "General", frame: frame(x: 20, y: 18), parentID: 0)
        ])
        let sut = ActionablePromoter()

        // when
        let result = sut.promote(searchNodeID: 1, index: index, actionableCandidates: [rowCandidate])

        // then
        XCTAssertEqual(result.actionableCandidateIndex, 0)
        XCTAssertEqual(result.method, .ancestor(levels: 1))
    }

    func test_promote_childrenIDs_BFS에서_actionable_descendant를_찾는다() {
        // given
        let buttonFrame = frame(x: 20, y: 20)
        let joinButton = candidate(title: "Join", frame: buttonFrame)
        let index = ElementSearchIndex(nodes: [
            node(id: 0, role: AccessibilityRole.row, title: "General", frame: frame(x: 10, y: 10, width: 200, height: 50), childrenIDs: [1]),
            node(id: 1, title: "Join", frame: buttonFrame, parentID: 0)
        ])
        let sut = ActionablePromoter()

        // when
        let result = sut.promote(searchNodeID: 0, index: index, actionableCandidates: [joinButton])

        // then
        XCTAssertEqual(result.actionableCandidateIndex, 0)
        XCTAssertEqual(result.method, .descendant(levels: 1))
    }

    func test_promote_ancestor_descendant가_없으면_40pt_내_spatial_candidate를_찾는다() {
        // given
        let nearby = candidate(title: "Open", frame: frame(x: 40, y: 10))
        let far = candidate(title: "Far", frame: frame(x: 200, y: 10))
        let index = ElementSearchIndex(nodes: [
            node(id: 0, role: "AXStaticText", title: "Open label", frame: frame(x: 10, y: 10))
        ])
        let sut = ActionablePromoter()

        // when
        let result = sut.promote(searchNodeID: 0, index: index, actionableCandidates: [far, nearby])

        // then
        XCTAssertEqual(result.actionableCandidateIndex, 1)
        XCTAssertEqual(result.method, .spatial(distance: 30))
    }

    func test_promote_spatial_동점이면_AXPress가_있는_candidate를_우선한다() {
        // given
        let withoutPress = candidate(title: "Without", frame: frame(x: 40, y: 10), actions: [])
        let withPress = candidate(title: "With", frame: frame(x: -20, y: 10), actions: [AccessibilityAction.press])
        let index = ElementSearchIndex(nodes: [
            node(id: 0, role: "AXStaticText", title: "Label", frame: frame(x: 10, y: 10))
        ])
        let sut = ActionablePromoter()

        // when
        let result = sut.promote(searchNodeID: 0, index: index, actionableCandidates: [withoutPress, withPress])

        // then
        XCTAssertEqual(result.actionableCandidateIndex, 1)
    }

    func test_promote_40pt_밖이면_failure를_반환한다() {
        // given
        let index = ElementSearchIndex(nodes: [
            node(id: 0, role: "AXStaticText", title: "Label", frame: frame(x: 10, y: 10))
        ])
        let sut = ActionablePromoter()

        // when
        let result = sut.promote(
            searchNodeID: 0,
            index: index,
            actionableCandidates: [candidate(title: "Far", frame: frame(x: 120, y: 10))]
        )

        // then
        XCTAssertNil(result.actionableCandidateIndex)
        XCTAssertEqual(result.failure, .noSpatialNeighbor)
    }

    func test_promote_secure_candidate는_spatial에서_제외한다() {
        // given
        let secure = candidate(
            role: AccessibilityRole.secureTextField,
            title: "Password",
            frame: frame(x: 20, y: 10)
        )
        let normal = candidate(title: "Search", frame: frame(x: 38, y: 10))
        let index = ElementSearchIndex(nodes: [
            node(id: 0, role: "AXStaticText", title: "Label", frame: frame(x: 10, y: 10))
        ])
        let sut = ActionablePromoter()

        // when
        let result = sut.promote(searchNodeID: 0, index: index, actionableCandidates: [secure, normal])

        // then
        XCTAssertEqual(result.actionableCandidateIndex, 1)
    }

    func test_promote_searchNode가_없으면_failure를_반환한다() {
        // given
        let sut = ActionablePromoter()

        // when
        let result = sut.promote(
            searchNodeID: 999,
            index: ElementSearchIndex(nodes: []),
            actionableCandidates: []
        )

        // then
        XCTAssertEqual(result.failure, .searchNodeMissing)
    }

    private func node(
        id: Int,
        role: String? = AccessibilityRole.button,
        title: String? = nil,
        frame: CGRect,
        parentID: Int? = nil,
        childrenIDs: [Int] = []
    ) -> SearchableNode {
        SearchableNode(
            id: id,
            role: role,
            title: title,
            frame: frame,
            parentID: parentID,
            childrenIDs: childrenIDs
        )
    }

    private func candidate(
        role: String = AccessibilityRole.button,
        title: String?,
        frame: CGRect,
        actions: [String] = [AccessibilityAction.press]
    ) -> ClickableCandidate {
        ClickableCandidate(
            role: role,
            subrole: nil,
            title: title,
            frame: frame,
            actions: actions
        )
    }

    private func frame(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat = 20,
        height: CGFloat = 20
    ) -> CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}
