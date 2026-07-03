import CoreGraphics
import XCTest
@testable import GazeRow

/// OverlayLayoutEngine 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class OverlayLayoutEngineTests: XCTestCase {

    func test_mapScreenFrameToLocal_targetOrigin을_기준으로_변환() {
        // given
        let mapper = OverlayCoordinateMapper(targetFrame: CGRect(x: 100, y: 200, width: 400, height: 300))

        // when
        let local = mapper.mapScreenFrameToLocal(CGRect(x: 140, y: 260, width: 80, height: 30))

        // then
        XCTAssertEqual(local, CGRect(x: 40, y: 60, width: 80, height: 30))
        XCTAssertEqual(mapper.targetBoundaryFrame(), CGRect(x: 0, y: 0, width: 400, height: 300))
    }

    func test_makeLayout_candidate근처에_label을_배치하고_metric을_기록() {
        // given
        let candidate = makeCandidate(frame: CGRect(x: 140, y: 260, width: 80, height: 30))
        let sut = OverlayLayoutEngine()

        // when
        let layout = sut.makeLayout(
            targetFrame: CGRect(x: 100, y: 200, width: 400, height: 300),
            candidates: [candidate],
            labels: ["AA"],
            displayInfo: OverlayDisplayInfo(scaleFactor: 2, visibleFrame: nil)
        )

        // then
        XCTAssertEqual(layout.labels.count, 1)
        XCTAssertEqual(layout.labels.first?.text, "AA")
        XCTAssertEqual(layout.labels.first?.candidateFrame, CGRect(x: 40, y: 60, width: 80, height: 30))
        XCTAssertEqual(layout.metrics.labelCount, 1)
        XCTAssertEqual(layout.metrics.displayScaleFactor, 2)
        XCTAssertTrue(layout.metrics.isRetina)
    }

    func test_makeLayout_labels가_없으면_prefix없는_기본_label을_생성() {
        // given
        let candidates = (0..<28).map { index in
            makeCandidate(frame: CGRect(x: 20 + index * 4, y: 120, width: 2, height: 2))
        }
        let sut = OverlayLayoutEngine()

        // when
        let layout = sut.makeLayout(
            targetFrame: CGRect(x: 0, y: 0, width: 400, height: 300),
            candidates: candidates
        )

        // then
        XCTAssertEqual(layout.labels[0].text, "AA")
        XCTAssertEqual(layout.labels[25].text, "AZ")
        XCTAssertEqual(layout.labels[26].text, "BA")
        XCTAssertEqual(layout.labels[27].text, "BB")
    }

    func test_makeLayout_labelFrame을_targetBounds안으로_clamp() throws {
        // given
        let candidate = makeCandidate(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
        let sut = OverlayLayoutEngine()

        // when
        let layout = sut.makeLayout(
            targetFrame: CGRect(x: 0, y: 0, width: 100, height: 80),
            candidates: [candidate]
        )

        // then
        let labelFrame = try XCTUnwrap(layout.labels.first?.labelFrame)
        XCTAssertGreaterThanOrEqual(labelFrame.minX, 0)
        XCTAssertGreaterThanOrEqual(labelFrame.minY, 0)
        XCTAssertLessThanOrEqual(labelFrame.maxX, layout.localBounds.maxX)
        XCTAssertLessThanOrEqual(labelFrame.maxY, layout.localBounds.maxY)
    }

    func test_makeLayout_인접한_candidate에_label을_중앙_배치하면_겹침을_collisionCount로_기록() {
        // given
        let first = makeCandidate(frame: CGRect(x: 100, y: 120, width: 20, height: 20))
        let second = makeCandidate(frame: CGRect(x: 102, y: 122, width: 20, height: 20))
        let sut = OverlayLayoutEngine(
            configuration: OverlayLayoutConfiguration(
                labelSize: CGSize(width: 30, height: 20),
                labelSpacing: 4
            )
        )

        // when
        let layout = sut.makeLayout(
            targetFrame: CGRect(x: 0, y: 0, width: 300, height: 240),
            candidates: [first, second]
        )

        // then
        XCTAssertEqual(layout.metrics.collisionCount, 1)
        XCTAssertTrue(layout.labels[0].labelFrame.intersects(layout.labels[1].labelFrame))
    }

    func test_makeLayout_label을_candidate_중앙에_배치() {
        // given
        let candidate = makeCandidate(frame: CGRect(x: 140, y: 160, width: 80, height: 40))
        let sut = OverlayLayoutEngine(
            configuration: OverlayLayoutConfiguration(
                labelSize: CGSize(width: 30, height: 20),
                edgeInset: 0
            )
        )

        // when
        let layout = sut.makeLayout(
            targetFrame: CGRect(x: 0, y: 0, width: 400, height: 300),
            candidates: [candidate]
        )

        // then
        let candidateFrame = layout.labels[0].candidateFrame
        let labelFrame = layout.labels[0].labelFrame
        XCTAssertEqual(labelFrame.midX, candidateFrame.midX, accuracy: 0.001)
        XCTAssertEqual(labelFrame.midY, candidateFrame.midY, accuracy: 0.001)
    }

    func test_makeLayout_label이_candidate를_가리면_occlusionCount를_기록() {
        // given
        let candidate = makeCandidate(frame: CGRect(x: 10, y: 10, width: 24, height: 10))
        let sut = OverlayLayoutEngine(
            configuration: OverlayLayoutConfiguration(
                labelSize: CGSize(width: 80, height: 40),
                labelSpacing: 0,
                edgeInset: 0
            )
        )

        // when
        let layout = sut.makeLayout(
            targetFrame: CGRect(x: 0, y: 0, width: 60, height: 50),
            candidates: [candidate]
        )

        // then
        XCTAssertEqual(layout.metrics.occlusionCount, 1)
    }

    private func makeCandidate(frame: CGRect) -> ClickableCandidate {
        ClickableCandidate(
            role: AccessibilityRole.button,
            subrole: nil,
            title: "Button",
            frame: frame,
            actions: [AccessibilityAction.press]
        )
    }
}
