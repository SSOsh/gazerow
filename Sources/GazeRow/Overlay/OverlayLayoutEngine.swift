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
        let labelText = resolveLabelText(candidates: candidates, labels: labels)
        var placedLabels: [OverlayLabel] = []
        var collisionCount = 0
        var occlusionCount = 0

        for (index, candidate) in candidates.enumerated() {
            let candidateFrame = mapper.mapScreenFrameToLocal(candidate.frame)
            let text = labelText(index)
            let labelFrame = placeLabelFrame(
                over: candidateFrame,
                placed: placedLabels.map(\.labelFrame),
                in: mapper.localBounds
            )

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

    /// 후보 index에 부여할 label 문자열을 결정하는 함수를 만든다.
    ///
    /// 외부에서 `labels`를 명시 주입하면 호출자가 정한 index 대응을 그대로
    /// 유지한다. 자동 생성 경로에서는 `ordersLabelsSpatially`가 켜져 있을 때
    /// 후보를 공간 순(좌상→우하)으로 정렬해 짧은 label을 읽기 순서대로 배정하되,
    /// `OverlayLabel.id`는 원본 candidate index를 유지해 click/로그 파이프라인과의
    /// 계약을 깨지 않는다.
    private func resolveLabelText(
        candidates: [ClickableCandidate],
        labels: [String]
    ) -> (Int) -> String {
        let generated = generatedLabels(count: candidates.count)

        if !labels.isEmpty {
            return { index in
                if index < labels.count {
                    return labels[index]
                }

                return index < generated.count ? generated[index] : ""
            }
        }

        guard configuration.ordersLabelsSpatially else {
            return { index in index < generated.count ? generated[index] : "" }
        }

        let ordered = CandidateOrdering(rowBandHeight: configuration.rowBandHeight).ordered(candidates)
        var labelByOriginalIndex = Array(repeating: "", count: candidates.count)
        for (position, originalIndex) in ordered.enumerated() where position < generated.count {
            labelByOriginalIndex[originalIndex] = generated[position]
        }

        return { index in
            index < labelByOriginalIndex.count ? labelByOriginalIndex[index] : ""
        }
    }

    /// 설정된 label 전략에 따라 자동 label 문자열을 생성한다.
    ///
    /// `.fixedWidth`는 현행 기본(`LabelGenerator`, 배치 단위 고정폭)을 유지하고,
    /// `.prefixFree`는 홈로우 우선 가변폭 hint(`HintLabelGenerator`)로 대부분의
    /// 후보에 1글자 label을 배정한다. 두 전략 모두 prefix-free라 type-to-filter와
    /// 정합한다.
    private func generatedLabels(count: Int) -> [String] {
        switch configuration.labelStrategy {
        case .fixedWidth:
            return LabelGenerator().labels(count: count)
        case .prefixFree:
            return HintLabelGenerator().labels(count: count)
        }
    }

    /// 설정된 배치 전략에 따라 label frame을 계산한다.
    ///
    /// `.centered`는 현행 동작(후보 중앙, 겹침/가림 계측만)을 유지하고,
    /// `.adaptive`는 occlusion을 피하고 collision을 해소하도록 밀어낸다.
    private func placeLabelFrame(
        over candidateFrame: CGRect,
        placed: [CGRect],
        in bounds: CGRect
    ) -> CGRect {
        switch configuration.labelPlacement {
        case .centered:
            return makeCenteredLabelFrame(over: candidateFrame, in: bounds)
        case .adaptive:
            return OverlayLabelPlacer(
                labelSize: configuration.labelSize,
                labelSpacing: configuration.labelSpacing,
                edgeInset: configuration.edgeInset,
                collisionShiftLimit: configuration.collisionShiftLimit
            ).place(over: candidateFrame, placed: placed, in: bounds)
        }
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
