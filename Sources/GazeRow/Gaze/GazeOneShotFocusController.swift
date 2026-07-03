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
    private let timeout: TimeInterval
    private let timeoutScheduler: any GazeOneShotTimeoutScheduling

    private let lock = NSLock()
    private var hasFinished = false
    private var completion: ((Result<CGPoint, GazeOneShotFailure>) -> Void)?

    init(
        pointEstimator: GazePointEstimator,
        frameProvider: any GazeFrameProviding = CameraFrameProvider(),
        landmarkDetector: any GazeFaceLandmarkDetecting = FaceLandmarkDetector(),
        featureExtractor: EyeFeatureExtractor = EyeFeatureExtractor(),
        timeout: TimeInterval = 2.0,
        timeoutScheduler: any GazeOneShotTimeoutScheduling = DispatchGazeOneShotTimeoutScheduler()
    ) {
        self.pointEstimator = pointEstimator
        self.frameProvider = frameProvider
        self.landmarkDetector = landmarkDetector
        self.featureExtractor = featureExtractor
        self.timeout = timeout
        self.timeoutScheduler = timeoutScheduler
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
            timeoutScheduler.schedule(after: timeout) { [weak self] in
                self?.cancel()
            }
        } catch {
            finish(with: .failure(.frameProviderFailed))
        }
    }

    /// 유효 feature를 얻기 전에 취소한다(타임아웃 등). 아직 끝나지 않았다면 실패로 종료.
    ///
    /// 얼굴/눈 특징을 못 얻는 상황에서도 카메라가 꺼지도록 보장하는 안전장치다.
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

        timeoutScheduler.cancel()
        frameProvider.onFrame = nil
        frameProvider.stop()
        completion(result)
    }
}

/// one-shot 캡처의 타임아웃 예약/취소를 담당하는 추상화.
///
/// 실제 구현은 지정 시간이 지나면 handler를 호출하고, `cancel()`로 예약을 무효화한다.
/// 테스트에서는 수동 트리거 구현을 주입해 시간 지연 없이 검증한다.
///
/// @author suho.do
/// @since 2026-07-03
protocol GazeOneShotTimeoutScheduling: AnyObject {
    func schedule(after interval: TimeInterval, handler: @escaping () -> Void)
    func cancel()
}

/// `DispatchQueue` 기반 기본 타임아웃 스케줄러.
///
/// 카메라 프레임 콜백(백그라운드 큐)과 예약 시점(메인 큐)이 서로 다른 스레드에서
/// 접근할 수 있어 내부 상태를 lock으로 보호한다.
///
/// @author suho.do
/// @since 2026-07-03
final class DispatchGazeOneShotTimeoutScheduler: GazeOneShotTimeoutScheduling {

    private let queue: DispatchQueue
    private let lock = NSLock()
    private var workItem: DispatchWorkItem?

    init(queue: DispatchQueue = .main) {
        self.queue = queue
    }

    func schedule(after interval: TimeInterval, handler: @escaping () -> Void) {
        cancel()

        let item = DispatchWorkItem(block: handler)
        lock.lock()
        workItem = item
        lock.unlock()

        queue.asyncAfter(deadline: .now() + interval, execute: item)
    }

    func cancel() {
        lock.lock()
        let item = workItem
        workItem = nil
        lock.unlock()

        item?.cancel()
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
