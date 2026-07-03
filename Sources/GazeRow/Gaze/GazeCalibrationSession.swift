import CoreGraphics

/// calibration 진행 상태를 관리하는 순수 값 타입.
///
/// 정규화된 타깃 점(0...1)을 순서대로 제시하고, 각 점에서 수집한 `EyeFeature`를
/// 해당 화면 좌표와 페어링해 `GazeCalibrationSample`로 모은다. 카메라·UI 의존이 없어
/// 단위 테스트가 쉽다.
///
/// @author suho.do
/// @since 2026-07-03
struct GazeCalibrationSession: Equatable {

    /// 기본 9점(3x3 grid) 정규화 타깃. 화면 가장자리 여백을 둔다.
    static let defaultNormalizedTargets: [CGPoint] = {
        let coords: [CGFloat] = [0.1, 0.5, 0.9]
        return coords.flatMap { y in
            coords.map { x in CGPoint(x: x, y: y) }
        }
    }()

    /// 타깃 점을 배치할 화면(또는 창) 영역.
    let screenBounds: CGRect

    /// 0...1 정규화 좌표로 표현한 타깃 순서.
    let normalizedTargets: [CGPoint]

    /// 현재 제시 중인 타깃 인덱스.
    private(set) var currentIndex: Int

    /// 지금까지 수집한 calibration sample.
    private(set) var samples: [GazeCalibrationSample]

    init(
        screenBounds: CGRect,
        normalizedTargets: [CGPoint] = GazeCalibrationSession.defaultNormalizedTargets
    ) {
        self.screenBounds = screenBounds
        self.normalizedTargets = normalizedTargets
        self.currentIndex = 0
        self.samples = []
    }

    /// 모든 타깃을 수집 완료했는지 여부.
    var isComplete: Bool {
        currentIndex >= normalizedTargets.count
    }

    /// 전체 타깃 개수.
    var totalTargetCount: Int {
        normalizedTargets.count
    }

    /// 현재 타깃의 정규화 좌표(0...1). 완료 시 nil.
    var currentNormalizedTarget: CGPoint? {
        guard normalizedTargets.indices.contains(currentIndex) else {
            return nil
        }
        return normalizedTargets[currentIndex]
    }

    /// 현재 타깃의 화면 좌표. 완료 시 nil.
    var currentScreenPoint: CGPoint? {
        guard let normalized = currentNormalizedTarget else {
            return nil
        }
        return CGPoint(
            x: screenBounds.minX + normalized.x * screenBounds.width,
            y: screenBounds.minY + normalized.y * screenBounds.height
        )
    }

    /// 현재 타깃에서 수집한 feature를 기록하고 다음 타깃으로 넘어간다.
    ///
    /// 이미 완료된 상태면 아무 것도 하지 않는다.
    mutating func record(feature: EyeFeature) {
        guard let screenPoint = currentScreenPoint else {
            return
        }
        samples.append(
            GazeCalibrationSample(feature: feature, screenPoint: screenPoint)
        )
        currentIndex += 1
    }
}
