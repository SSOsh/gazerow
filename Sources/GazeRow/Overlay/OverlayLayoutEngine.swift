import CoreGraphics

/// clickable candidates를 overlay label layout으로 변환한다.
///
/// @author suho.do
/// @since 2026-07-02
struct OverlayLayoutEngine {
    private let configuration: OverlayLayoutConfiguration

    init(configuration: OverlayLayoutConfiguration = OverlayLayoutConfiguration()) {
        self.configuration = configuration
    }

    func makeLayout(
        targetFrame: CGRect,
        candidates: [ClickableCandidate],
        labels: [String] = [],
        displayInfo: OverlayDisplayInfo = OverlayDisplayInfo(scaleFactor: 1, visibleFrame: nil)
    ) -> OverlayLayout {
        let mapper = OverlayCoordinateMapper(targetFrame: targetFrame)
        let generatedLabels = LabelGenerator().labels(count: candidates.count)
        var placedLabels: [OverlayLabel] = []
        var collisionCount = 0
        var occlusionCount = 0

        for (index, candidate) in candidates.enumerated() {
            let candidateFrame = mapper.mapScreenFrameToLocal(candidate.frame)
            let text = index < labels.count ? labels[index] : generatedLabels[index]
            let labelFrame = makeCenteredLabelFrame(over: candidateFrame, in: mapper.localBounds)

            if placedLabels.contains(where: { $0.labelFrame.intersects(labelFrame) }) {
                collisionCount += 1
            }

            if labelFrame.intersects(candidateFrame) {
                occlusionCount += 1
            }

            placedLabels.append(
                OverlayLabel(
                    id: index,
                    text: text,
                    candidateFrame: candidateFrame,
                    labelFrame: labelFrame,
                    anchorPoint: CGPoint(x: candidateFrame.midX, y: candidateFrame.midY)
                )
            )
        }

        return OverlayLayout(
            targetFrame: targetFrame,
            localBounds: mapper.localBounds,
            labels: placedLabels,
            metrics: OverlayLayoutMetrics(
                labelCount: placedLabels.count,
                collisionCount: collisionCount,
                occlusionCount: occlusionCount,
                displayScaleFactor: displayInfo.scaleFactor
            ),
            displayInfo: displayInfo
        )
    }

    /// 라벨을 후보 요소의 중앙에 겹쳐 배치한다.
    ///
    /// 후보에서 멀리 밀어내지 않으므로 라벨이 각 요소 위에 분산돼, 밀집 UI나
    /// 화면 가장자리에서 라벨이 한쪽으로 쏠려 뭉치는 현상을 없앤다. 화면 밖으로
    /// 벗어나지 않도록 경계 안으로만 clamp 한다.
    private func makeCenteredLabelFrame(over candidateFrame: CGRect, in bounds: CGRect) -> CGRect {
        let origin = CGPoint(
            x: candidateFrame.midX - configuration.labelSize.width / 2,
            y: candidateFrame.midY - configuration.labelSize.height / 2
        )

        return clamp(CGRect(origin: origin, size: configuration.labelSize), to: bounds)
    }

    private func clamp(_ frame: CGRect, to bounds: CGRect) -> CGRect {
        let minX = bounds.minX + configuration.edgeInset
        let minY = bounds.minY + configuration.edgeInset
        let maxX = bounds.maxX - configuration.edgeInset - frame.width
        let maxY = bounds.maxY - configuration.edgeInset - frame.height

        let clampedX = maxX < minX ? minX : min(max(frame.minX, minX), maxX)
        let clampedY = maxY < minY ? minY : min(max(frame.minY, minY), maxY)

        return CGRect(
            x: clampedX,
            y: clampedY,
            width: frame.width,
            height: frame.height
        )
    }
}
