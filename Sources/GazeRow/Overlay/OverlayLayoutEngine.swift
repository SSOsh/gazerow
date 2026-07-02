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
            let proposedFrame = makeInitialLabelFrame(near: candidateFrame, in: mapper.localBounds)
            let placement = mitigateCollision(
                proposedFrame: proposedFrame,
                candidateFrame: candidateFrame,
                occupiedFrames: placedLabels.map(\.labelFrame),
                bounds: mapper.localBounds
            )

            if placement.didCollide {
                collisionCount += 1
            }

            if placement.frame.intersects(candidateFrame) {
                occlusionCount += 1
            }

            placedLabels.append(
                OverlayLabel(
                    id: index,
                    text: text,
                    candidateFrame: candidateFrame,
                    labelFrame: placement.frame,
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

    private func makeInitialLabelFrame(near candidateFrame: CGRect, in bounds: CGRect) -> CGRect {
        let aboveOrigin = CGPoint(
            x: candidateFrame.midX - configuration.labelSize.width / 2,
            y: candidateFrame.minY - configuration.labelSize.height - configuration.labelSpacing
        )
        let belowOrigin = CGPoint(
            x: candidateFrame.midX - configuration.labelSize.width / 2,
            y: candidateFrame.maxY + configuration.labelSpacing
        )
        let aboveFrame = CGRect(origin: aboveOrigin, size: configuration.labelSize)
        let frame = aboveFrame.minY >= bounds.minY + configuration.edgeInset
            ? aboveFrame
            : CGRect(origin: belowOrigin, size: configuration.labelSize)

        return clamp(frame, to: bounds)
    }

    private func mitigateCollision(
        proposedFrame: CGRect,
        candidateFrame: CGRect,
        occupiedFrames: [CGRect],
        bounds: CGRect
    ) -> (frame: CGRect, didCollide: Bool) {
        var frame = proposedFrame
        var didCollide = false

        for _ in 0...configuration.collisionShiftLimit {
            guard intersectsAny(frame, occupiedFrames: occupiedFrames) else {
                return (frame, didCollide)
            }

            didCollide = true
            frame = nextCollisionFrame(
                currentFrame: frame,
                candidateFrame: candidateFrame,
                bounds: bounds
            )
        }

        return (frame, didCollide)
    }

    private func nextCollisionFrame(
        currentFrame: CGRect,
        candidateFrame: CGRect,
        bounds: CGRect
    ) -> CGRect {
        let shifted = currentFrame.offsetBy(
            dx: 0,
            dy: configuration.labelSize.height + configuration.labelSpacing
        )

        if shifted.maxY <= bounds.maxY - configuration.edgeInset {
            return shifted
        }

        let wrapped = CGRect(
            x: candidateFrame.maxX + configuration.labelSpacing,
            y: candidateFrame.midY - configuration.labelSize.height / 2,
            width: configuration.labelSize.width,
            height: configuration.labelSize.height
        )
        return clamp(wrapped, to: bounds)
    }

    private func intersectsAny(_ frame: CGRect, occupiedFrames: [CGRect]) -> Bool {
        occupiedFrames.contains { occupied in
            frame.intersects(
                occupied.insetBy(
                    dx: -configuration.labelSpacing,
                    dy: -configuration.labelSpacing
                )
            )
        }
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
