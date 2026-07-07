import CoreGraphics

/// candidate를 가리지 않고 서로 겹치지 않게 label frame을 배치한다.
///
/// 후보 모서리 바깥(위/아래) 위치를 우선 시도해 occlusion을 피하고, 이미 놓인
/// label과 겹치면 나선형 offset으로 밀어내 collision을 해소한다. 어떤 위치도
/// 실패하면 후보 중앙(centered)으로 폴백한다. 후보 프레임 자체는 바꾸지 않고
/// label 사각형만 이동하므로 anchor(후보 중심)와 click 파이프라인에 영향이 없다.
///
/// @author suho.do
/// @since 2026-07-07
struct OverlayLabelPlacer {
    let labelSize: CGSize
    let labelSpacing: CGFloat
    let edgeInset: CGFloat
    let collisionShiftLimit: Int

    /// 후보를 가리지 않고 기존 label과 겹치지 않는 label frame을 계산한다.
    func place(over candidateFrame: CGRect, placed: [CGRect], in bounds: CGRect) -> CGRect {
        let corners = cornerFrames(over: candidateFrame, in: bounds)

        if let ideal = corners.first(where: { frame in
            !frame.intersects(candidateFrame) && !collides(frame, with: placed)
        }) {
            return ideal
        }

        for base in corners {
            if let resolved = resolveByShifting(base: base, placed: placed, in: bounds) {
                return resolved
            }
        }

        return centeredFrame(over: candidateFrame, in: bounds)
    }

    /// 후보 상/하단 모서리에 붙는 후보 위치 4곳을 생성한다.
    private func cornerFrames(over candidateFrame: CGRect, in bounds: CGRect) -> [CGRect] {
        let above = candidateFrame.minY - labelSize.height - labelSpacing
        let below = candidateFrame.maxY + labelSpacing
        let leftX = candidateFrame.minX
        let rightX = candidateFrame.maxX - labelSize.width

        let origins = [
            CGPoint(x: leftX, y: above),
            CGPoint(x: rightX, y: above),
            CGPoint(x: leftX, y: below),
            CGPoint(x: rightX, y: below)
        ]

        return origins.map { clamp(CGRect(origin: $0, size: labelSize), to: bounds) }
    }

    /// base 위치가 겹치면 나선형(우→하→좌→상) offset으로 collision을 회피한다.
    private func resolveByShifting(base: CGRect, placed: [CGRect], in bounds: CGRect) -> CGRect? {
        if !collides(base, with: placed) {
            return base
        }

        guard collisionShiftLimit > 0 else {
            return nil
        }

        let directions = [
            CGVector(dx: 1, dy: 0),
            CGVector(dx: 0, dy: 1),
            CGVector(dx: -1, dy: 0),
            CGVector(dx: 0, dy: -1)
        ]

        for step in 1...collisionShiftLimit {
            for direction in directions {
                let shifted = clamp(
                    base.offsetBy(
                        dx: direction.dx * CGFloat(step) * labelSpacing,
                        dy: direction.dy * CGFloat(step) * labelSpacing
                    ),
                    to: bounds
                )

                if !collides(shifted, with: placed) {
                    return shifted
                }
            }
        }

        return nil
    }

    private func centeredFrame(over candidateFrame: CGRect, in bounds: CGRect) -> CGRect {
        let origin = CGPoint(
            x: candidateFrame.midX - labelSize.width / 2,
            y: candidateFrame.midY - labelSize.height / 2
        )

        return clamp(CGRect(origin: origin, size: labelSize), to: bounds)
    }

    private func collides(_ frame: CGRect, with placed: [CGRect]) -> Bool {
        placed.contains { $0.intersects(frame) }
    }

    private func clamp(_ frame: CGRect, to bounds: CGRect) -> CGRect {
        let minX = bounds.minX + edgeInset
        let minY = bounds.minY + edgeInset
        let maxX = bounds.maxX - edgeInset - frame.width
        let maxY = bounds.maxY - edgeInset - frame.height

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
