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
        let labelPlacement = effectiveLabelPlacement(candidateCount: candidates.count)
        var placedLabels: [OverlayLabel] = []
        placedLabels.reserveCapacity(candidates.count)
        var placedFrames: [CGRect] = []
        if labelPlacement == .adaptive {
            placedFrames.reserveCapacity(candidates.count)
        }
        var collisionIndex = LabelCollisionIndex(
            cellSize: max(configuration.labelSize.width, configuration.labelSize.height)
        )
        var collisionCount = 0
        var occlusionCount = 0

        for (index, candidate) in candidates.enumerated() {
            let candidateFrame = mapper.mapScreenFrameToLocal(candidate.frame)
            let text = labelText(index)
            let labelFrame = placeLabelFrame(
                over: candidateFrame,
                labelSize: labelSize(for: text),
                placed: placedFrames,
                in: mapper.localBounds,
                placement: labelPlacement
            )

            if collisionIndex.intersects(labelFrame) {
                collisionCount += 1
            }
            collisionIndex.insert(labelFrame)

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
            if labelPlacement == .adaptive {
                placedFrames.append(labelFrame)
            }
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
    /// `.prefixFree`는 현행 기본으로 홈로우 우선 가변폭 hint(`HintLabelGenerator`)를
    /// 써서 대부분의 후보에 1글자 label을 배정하고, `.fixedWidth`는 배치 단위 고정폭
    /// (`LabelGenerator`)을 쓴다. 두 전략 모두 prefix-free라 type-to-filter와 정합한다.
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
        labelSize: CGSize,
        placed: [CGRect],
        in bounds: CGRect,
        placement: LabelPlacement
    ) -> CGRect {
        switch placement {
        case .centered:
            return makeCenteredLabelFrame(over: candidateFrame, labelSize: labelSize, in: bounds)
        case .adaptive:
            return OverlayLabelPlacer(
                labelSize: labelSize,
                labelSpacing: configuration.labelSpacing,
                edgeInset: configuration.edgeInset,
                collisionShiftLimit: configuration.collisionShiftLimit
            ).place(over: candidateFrame, placed: placed, in: bounds)
        }
    }

    /// 라벨 수가 많은 화면에서는 후보 중앙 겹침보다 adaptive 배치를 우선한다.
    private func effectiveLabelPlacement(candidateCount: Int) -> LabelPlacement {
        guard configuration.usesAdaptivePlacementForDenseLayouts,
              configuration.labelPlacement == .centered,
              candidateCount >= configuration.denseCandidateThreshold else {
            return configuration.labelPlacement
        }

        return .adaptive
    }

    /// 긴 라벨은 고정 폭 안에 글자를 압축하지 않도록 폭을 확장한다.
    private func labelSize(for text: String) -> CGSize {
        let extraCharacters = max(0, text.count - 2)
        return CGSize(
            width: configuration.labelSize.width + CGFloat(extraCharacters) * 10,
            height: configuration.labelSize.height
        )
    }

    /// 라벨을 후보 요소의 중앙에 겹쳐 배치한다.
    ///
    /// 후보에서 멀리 밀어내지 않으므로 라벨이 각 요소 위에 분산돼, 밀집 UI나
    /// 화면 가장자리에서 라벨이 한쪽으로 쏠려 뭉치는 현상을 없앤다. 화면 밖으로
    /// 벗어나지 않도록 경계 안으로만 clamp 한다.
    private func makeCenteredLabelFrame(
        over candidateFrame: CGRect,
        labelSize: CGSize,
        in bounds: CGRect
    ) -> CGRect {
        let origin = CGPoint(
            x: candidateFrame.midX - labelSize.width / 2,
            y: candidateFrame.midY - labelSize.height / 2
        )

        return clamp(CGRect(origin: origin, size: labelSize), to: bounds)
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

/// label frame collision을 인접 공간 bucket만 조회해 계산하는 index.
///
/// 각 label마다 이전 label 전체를 선형 검색하지 않아 centered 대량 layout을
/// 후보 수에 가깝게 확장한다. 실제 교차 여부는 CGRect로 재확인하므로 bucket
/// 경계에 걸친 frame도 기존 metric과 동일하게 처리한다.
private struct LabelCollisionIndex {
    private let cellSize: CGFloat
    private var frames: [CGRect] = []
    private var frameIndicesByCell: [Cell: [Int]] = [:]

    init(cellSize: CGFloat) {
        self.cellSize = max(1, cellSize)
    }

    func intersects(_ frame: CGRect) -> Bool {
        cells(for: frame).contains { cell in
            frameIndicesByCell[cell]?.contains { frameIndex in
                frames[frameIndex].intersects(frame)
            } == true
        }
    }

    mutating func insert(_ frame: CGRect) {
        let frameIndex = frames.count
        frames.append(frame)
        for cell in cells(for: frame) {
            frameIndicesByCell[cell, default: []].append(frameIndex)
        }
    }

    private func cells(for frame: CGRect) -> [Cell] {
        let minColumn = Int((frame.minX / cellSize).rounded(.down))
        let maxColumn = Int((frame.maxX / cellSize).rounded(.down))
        let minRow = Int((frame.minY / cellSize).rounded(.down))
        let maxRow = Int((frame.maxY / cellSize).rounded(.down))
        var result: [Cell] = []
        result.reserveCapacity((maxColumn - minColumn + 1) * (maxRow - minRow + 1))

        for column in minColumn...maxColumn {
            for row in minRow...maxRow {
                result.append(Cell(column: column, row: row))
            }
        }
        return result
    }

    private struct Cell: Hashable {
        let column: Int
        let row: Int
    }
}
