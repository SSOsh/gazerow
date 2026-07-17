import CoreGraphics
import SwiftUI
import XCTest
@testable import GazeRow

/// 대량 overlay 렌더링 전략과 Canvas 경로 테스트.
///
/// @author suho.do
/// @since 2026-07-17
@MainActor
final class OverlayRenderingStrategyTests: XCTestCase {

    func test_resolve_threshold미만은_기존viewTree를_사용한다() {
        // given
        let labelCount = OverlayRenderingStrategy.canvasThreshold - 1

        // when
        let result = OverlayRenderingStrategy.resolve(labelCount: labelCount)

        // then
        XCTAssertEqual(result, .viewTree)
    }

    func test_resolve_threshold부터_canvas를_사용한다() {
        // given
        let labelCount = OverlayRenderingStrategy.canvasThreshold

        // when
        let result = OverlayRenderingStrategy.resolve(labelCount: labelCount)

        // then
        XCTAssertEqual(result, .canvas)
    }

    func test_OverlayView_대량Canvas경로를_image로_render한다() {
        // given
        let layout = makeLargeLayout()
        let renderer = ImageRenderer(
            content: OverlayView(
                layout: layout,
                focusedLabelID: layout.labels.last?.id,
                status: OverlayInteractionStatus(
                    focusedLabel: layout.labels.last?.text,
                    hasExplicitFocus: true
                )
            )
        )

        // when
        let image = renderer.nsImage

        // then
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size, layout.localBounds.size)
    }

    func test_OverlayView_대량Canvas경로는_highlight와함께_render한다() {
        // given
        let layout = makeLargeLayout()
        let renderer = ImageRenderer(
            content: OverlayView(
                layout: layout,
                focusedLabelID: layout.labels.last?.id,
                status: OverlayInteractionStatus(
                    focusedLabel: layout.labels.last?.text,
                    activeScope: .elements,
                    highlightFrame: layout.labels.first?.candidateFrame,
                    hasExplicitFocus: true
                )
            )
        )

        // when
        let image = renderer.nsImage

        // then
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size, layout.localBounds.size)
    }

    private func makeLargeLayout() -> OverlayLayout {
        let labels = (0..<675).map { index in
            let column = index % 45
            let row = index / 45
            let frame = CGRect(
                x: CGFloat(column * 40),
                y: CGFloat(row * 28),
                width: 32,
                height: 22
            )
            return OverlayLabel(
                id: index,
                text: LabelGenerator().label(for: index),
                candidateFrame: frame,
                labelFrame: frame,
                anchorPoint: CGPoint(x: frame.midX, y: frame.midY)
            )
        }
        return OverlayLayout(
            targetFrame: CGRect(x: 0, y: 0, width: 1_800, height: 420),
            localBounds: CGRect(x: 0, y: 0, width: 1_800, height: 420),
            labels: labels,
            metrics: OverlayLayoutMetrics(
                labelCount: labels.count,
                collisionCount: 0,
                occlusionCount: labels.count,
                displayScaleFactor: 2
            ),
            displayInfo: OverlayDisplayInfo(scaleFactor: 2, visibleFrame: nil)
        )
    }
}
