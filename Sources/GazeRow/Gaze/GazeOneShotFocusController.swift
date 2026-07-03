import CoreGraphics
import CoreVideo
import Foundation

/// 단축키 1회 입력에 대해 gaze point를 한 번만 추정하는 one-shot controller.
///
/// 카메라를 켜서 첫 유효 `EyeFeature`를 얻는 즉시 gaze point를 추정하고 카메라를 끈다.
/// 연속 추적을 하지 않으므로 프레임은 캡처 순간에만 메모리에 존재하며 저장하지 않는다.
/// 자동 클릭도 하지 않는다(추정 좌표만 completion으로 전달).
///
/// @author suho.do
/// @since 2026-07-03
final class GazeOneShotFocusController {

    private let frameProvider: any GazeFrameProviding
    private let landmarkDetector: any GazeFaceLandmarkDetecting
    private let featureExtractor: EyeFeatureExtractor
    private let pointEstimator: GazePointEstimator

    private let lock = NSLock()
    private var hasFinished = false
    private var completion: ((Result<CGPoint, GazeOneShotFailure>) -> Void)?

    init(
        pointEstimator: GazePointEstimator,
        frameProvider: any GazeFrameProviding = CameraFrameProvider(),
        landmarkDetector: any GazeFaceLandmarkDetecting = FaceLandmarkDetector(),
        featureExtractor: EyeFeatureExtractor = EyeFeatureExtractor()
    ) {
        self.pointEstimator = pointEstimator
        self.frameProvider = frameProvider
        self.landmarkDetector = landmarkDetector
        self.featureExtractor = featureExtractor
    }

    /// one-shot 캡처를 시작한다. 결과는 completion으로 정확히 한 번 전달된다.
    func start(completion: @escaping (Result<CGPoint, GazeOneShotFailure>) -> Void) {
        guard pointEstimator.isReady else {
            completion(.failure(.calibrationUnavailable))
            return
        }

        lock.lock()
        hasFinished = false
        self.completion = completion
        lock.unlock()

        frameProvider.onFrame = { [weak self] pixelBuffer in
            self?.handleFrame(pixelBuffer)
        }

        do {
            try frameProvider.start()
        } catch {
            finish(with: .failure(.frameProviderFailed))
        }
    }

    /// 유효 feature를 얻기 전에 취소한다(타임아웃 등). 아직 끝나지 않았다면 실패로 종료.
    func cancel() {
        finish(with: .failure(.noFaceDetected))
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

        do {
            let point = try pointEstimator.estimatePoint(for: feature)
            finish(with: .success(point))
        } catch {
            finish(with: .failure(.gazeEstimationFailed))
        }
    }

    private func finish(with result: Result<CGPoint, GazeOneShotFailure>) {
        lock.lock()
        guard !hasFinished, let completion else {
            lock.unlock()
            return
        }
        hasFinished = true
        self.completion = nil
        lock.unlock()

        frameProvider.onFrame = nil
        frameProvider.stop()
        completion(result)
    }
}

/// one-shot gaze 캡처 실패 사유.
///
/// @author suho.do
/// @since 2026-07-03
enum GazeOneShotFailure: Error, Equatable {
    case calibrationUnavailable
    case frameProviderFailed
    case noFaceDetected
    case gazeEstimationFailed
}
