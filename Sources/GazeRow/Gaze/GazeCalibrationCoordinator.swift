import CoreGraphics
import CoreVideo
import Foundation

/// calibration 캡처 파이프라인을 조율한다.
///
/// 카메라 frame에서 최신 유효 `EyeFeature`만 보관하고, UI가 각 타깃에서 dwell을
/// 마친 뒤 `captureCurrentTarget()`을 호출하면 현재 타깃 화면 좌표와 페어링해
/// 샘플로 기록한다. 모든 타깃을 채우면 store에 저장하고 종료한다.
///
/// 타이밍(어느 시점에 캡처할지)은 UI가 결정하고, 데이터(수집/진행/저장)는 이
/// 타입이 담당해 단위 테스트가 쉽다. raw frame은 저장하지 않는다.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeCalibrationCoordinator {

    private let frameProvider: any GazeFrameProviding
    private let landmarkDetector: any GazeFaceLandmarkDetecting
    private let featureExtractor: EyeFeatureExtractor
    private let store: GazeCalibrationStore
    private let onProgress: (GazeCalibrationSession) -> Void
    private let onFinished: (Result<[GazeCalibrationSample], GazeCalibrationFailure>) -> Void

    private let lock = NSLock()
    private var session: GazeCalibrationSession
    private var latestFeature: EyeFeature?
    private var hasFinished = false

    init(
        screenBounds: CGRect,
        normalizedTargets: [CGPoint] = GazeCalibrationSession.defaultNormalizedTargets,
        frameProvider: any GazeFrameProviding = CameraFrameProvider(),
        landmarkDetector: any GazeFaceLandmarkDetecting = FaceLandmarkDetector(),
        featureExtractor: EyeFeatureExtractor = EyeFeatureExtractor(),
        store: GazeCalibrationStore = GazeCalibrationStore(),
        onProgress: @escaping (GazeCalibrationSession) -> Void = { _ in },
        onFinished: @escaping (Result<[GazeCalibrationSample], GazeCalibrationFailure>) -> Void
    ) {
        self.session = GazeCalibrationSession(
            screenBounds: screenBounds,
            normalizedTargets: normalizedTargets
        )
        self.frameProvider = frameProvider
        self.landmarkDetector = landmarkDetector
        self.featureExtractor = featureExtractor
        self.store = store
        self.onProgress = onProgress
        self.onFinished = onFinished
    }

    /// 카메라 캡처를 시작하고 초기 진행 상태를 알린다.
    func start() {
        lock.lock()
        hasFinished = false
        let initialSession = session
        lock.unlock()

        frameProvider.onFrame = { [weak self] pixelBuffer in
            self?.handleFrame(pixelBuffer)
        }

        do {
            try frameProvider.start()
            onProgress(initialSession)
        } catch {
            finish(with: .failure(.frameProviderFailed))
        }
    }

    /// 아직 종료되지 않았다면 취소로 종료한다.
    func cancel() {
        finish(with: .failure(.cancelled))
    }

    /// 현재 타깃에 대해 최신 유효 feature를 기록하고 다음 타깃으로 진행한다.
    ///
    /// 유효 feature가 아직 없으면 아무 것도 하지 않고 `false`를 반환한다(UI는 잠시
    /// 뒤 재시도). 마지막 타깃을 채우면 store에 저장하고 종료한다.
    @discardableResult
    func captureCurrentTarget() -> Bool {
        lock.lock()
        guard !hasFinished,
              !session.isComplete,
              let feature = latestFeature else {
            lock.unlock()
            return false
        }
        session.record(feature: feature)
        latestFeature = nil
        let snapshot = session
        let isComplete = session.isComplete
        let samples = session.samples
        lock.unlock()

        onProgress(snapshot)

        if isComplete {
            finishWithSave(samples)
        }
        return true
    }

    private func handleFrame(_ pixelBuffer: CVPixelBuffer) {
        let detections: [FaceLandmarkDetection]
        do {
            detections = try landmarkDetector.detect(in: pixelBuffer)
        } catch {
            return
        }

        guard let feature = detections.compactMap(featureExtractor.extract(from:)).first else {
            return
        }

        lock.lock()
        latestFeature = feature
        lock.unlock()
    }

    private func finishWithSave(_ samples: [GazeCalibrationSample]) {
        do {
            try store.save(samples)
            finish(with: .success(samples))
        } catch {
            finish(with: .failure(.saveFailed))
        }
    }

    private func finish(
        with result: Result<[GazeCalibrationSample], GazeCalibrationFailure>
    ) {
        lock.lock()
        guard !hasFinished else {
            lock.unlock()
            return
        }
        hasFinished = true
        lock.unlock()

        frameProvider.onFrame = nil
        frameProvider.stop()
        onFinished(result)
    }
}

/// calibration 캡처 실패 사유.
///
/// @author suho.do
/// @since 2026-07-03
enum GazeCalibrationFailure: Error, Equatable {
    case frameProviderFailed
    case cancelled
    case saveFailed
}
