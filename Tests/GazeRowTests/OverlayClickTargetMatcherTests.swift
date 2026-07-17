import CoreGraphics
import XCTest
@testable import GazeRow

/// OverlayClickTargetMatcher 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-14
final class OverlayClickTargetMatcherTests: XCTestCase {

    func test_match은_검증된_기존index를_우선한다() {
        // given
        let selection = makeSelection(labelID: 1, title: "Open", frame: CGRect(x: 80, y: 20, width: 40, height: 20))
        let targets = [
            makeTarget(element: 0, title: "Close", frame: CGRect(x: 10, y: 20, width: 40, height: 20)),
            makeTarget(element: 1, title: " open ", frame: CGRect(x: 84, y: 20, width: 40, height: 20))
        ]

        // when
        let result = OverlayClickTargetMatcher().match(selection: selection, currentTargets: targets)

        // then
        XCTAssertEqual(matchDetails(result)?.element, 1)
        XCTAssertEqual(matchDetails(result)?.metadata.strategy, .validatedOriginalIndex)
        XCTAssertEqual(matchDetails(result)?.metadata.currentIndex, 1)
    }

    func test_match은_앞쪽후보삽입후_descriptor로_선택대상을_재연결한다() {
        // given
        let selection = makeSelection(labelID: 1, title: "Target", frame: CGRect(x: 80, y: 20, width: 40, height: 20))
        let targets = [
            makeTarget(element: 0, title: "Inserted", frame: CGRect(x: 10, y: 20, width: 40, height: 20)),
            makeTarget(element: 1, title: "Other", frame: CGRect(x: 45, y: 20, width: 20, height: 20)),
            makeTarget(element: 2, title: "Target", frame: CGRect(x: 81, y: 20, width: 40, height: 20))
        ]

        // when
        let result = OverlayClickTargetMatcher().match(selection: selection, currentTargets: targets)

        // then
        XCTAssertEqual(matchDetails(result)?.element, 2)
        XCTAssertEqual(matchDetails(result)?.metadata.strategy, .descriptor)
        XCTAssertEqual(matchDetails(result)?.metadata.currentIndex, 2)
    }

    func test_match은_선택대상이_허용범위를넘어이동하면_changed를_반환한다() {
        // given
        let selection = makeSelection(labelID: 0, title: "Target", frame: CGRect(x: 10, y: 20, width: 40, height: 20))
        let targets = [
            makeTarget(element: 0, title: "Target", frame: CGRect(x: 40, y: 20, width: 40, height: 20))
        ]

        // when
        let result = OverlayClickTargetMatcher().match(selection: selection, currentTargets: targets)

        // then
        XCTAssertEqual(result.kind, .changed)
    }

    func test_match은_선택대상이_제거되면_unavailable을_반환한다() {
        // given
        let selection = makeSelection(labelID: 0, title: "Target", frame: CGRect(x: 10, y: 20, width: 40, height: 20))
        let targets = [
            makeTarget(element: 0, title: "Other", frame: CGRect(x: 10, y: 20, width: 40, height: 20))
        ]

        // when
        let result = OverlayClickTargetMatcher().match(selection: selection, currentTargets: targets)

        // then
        XCTAssertEqual(result.kind, .unavailable)
    }

    func test_match은_title없는중복후보를_ambiguous로_반환한다() {
        // given
        let selection = makeSelection(labelID: 0, title: nil, frame: CGRect(x: 10, y: 20, width: 40, height: 20))
        let targets = [
            makeTarget(element: 0, title: "Changed", frame: CGRect(x: 12, y: 20, width: 40, height: 20)),
            makeTarget(element: 1, title: nil, frame: CGRect(x: 14, y: 20, width: 40, height: 20))
        ]

        // when
        let result = OverlayClickTargetMatcher().match(selection: selection, currentTargets: targets)

        // then
        XCTAssertEqual(result.kind, .ambiguous)
    }

    private func makeSelection(labelID: Int, title: String?, frame: CGRect) -> OverlayClickSelection {
        OverlayClickSelection(
            labelID: labelID,
            candidate: ClickableCandidate(
                role: AccessibilityRole.button,
                subrole: nil,
                title: title,
                frame: frame,
                actions: [AccessibilityAction.press]
            ),
            sourceCandidateCount: 3
        )
    }

    private func makeTarget(element: Int, title: String?, frame: CGRect) -> ClickTarget<Int> {
        ClickTarget(
            element: element,
            role: AccessibilityRole.button,
            title: title,
            frame: frame,
            actions: [AccessibilityAction.press]
        )
    }

    private func matchDetails(
        _ result: OverlayClickTargetMatch<Int>
    ) -> (element: Int, metadata: OverlayClickTargetMatchMetadata)? {
        guard case .matched(let target, let metadata) = result else {
            return nil
        }

        return (target.element, metadata)
    }
}

private extension OverlayClickTargetMatch where Element == Int {
    var kind: OverlayClickTargetMatchKind {
        switch self {
        case .matched:
            .matched
        case .unavailable:
            .unavailable
        case .changed:
            .changed
        case .ambiguous:
            .ambiguous
        }
    }
}

private enum OverlayClickTargetMatchKind: Equatable {
    case matched
    case unavailable
    case changed
    case ambiguous
}
