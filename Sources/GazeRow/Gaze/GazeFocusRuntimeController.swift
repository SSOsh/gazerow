import CoreGraphics
import CoreVideo
import Foundation

/// camera frame을 gaze focus 이동으로 연결하는 runtime coordinator.
///
/// 이 타입은 자동 클릭을 하지 않는다. frame은 저장하지 않고, 추정된 gaze point만
/// overlay focus 이동 closure로 전달한다.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeFocusRuntimeController {

    private let frameProvider: any GazeFrameProviding
    private let landmarkDetector: any GazeFaceLandmarkDetecting
    private let featureExtractor: EyeFeatureExtractor
    private let pointEstimator: GazePointEstimator
    private let isCameraGazeEnabled: () -> Bool
    private let isCameraAuthorized: () -> Bool
    private let focusOverlay: (CGPoint) -> Void

    init(
        frameProvider: any GazeFrameProviding = CameraFrameProvider(),
        landmarkDetector: any GazeFaceLandmarkDetecting = FaceLandmarkDetector(),
        featureExtractor: EyeFeatureExtractor = EyeFeatureExtractor(),
        pointEstimator: GazePointEstimator,
        isCameraGazeEnabled: @escaping () -> Bool = {
            CameraGazeSettings().isOptInEnabled
        },
        isCameraAuthorized: @escaping () -> Bool,
        focusOverlay: @escaping (CGPoint) -> Void
    ) {
        self.frameProvider = frameProvider
        self.landmarkDetector = landmarkDetector
        self.featureExtractor = featureExtractor
        self.pointEstimator = pointEstimator
        self.isCameraGazeEnabled = isCameraGazeEnabled
        self.isCameraAuthorized = isCameraAuthorized
        self.focusOverlay = focusOverlay
    }

    func start() -> GazeFocusRuntimeStartResult {
        guard isCameraGazeEnabled() else {
            return .failure(.cameraGazeOptInDisabled)
        }

        guard isCameraAuthorized() else {
            return .failure(.cameraPermissionDenied)
        }

        guard pointEstimator.isReady else {
            return .failure(.calibrationUnavailable)
        }

        frameProvider.onFrame = { [weak self] pixelBuffer in
            self?.handleFrame(pixelBuffer)
        }

        do {
            try frameProvider.start()
            return .success
        } catch {
            return .failure(.frameProviderFailed)
        }
    }

    func stop() {
        frameProvider.stop()
        frameProvider.onFrame = nil
    }

    @discardableResult
    func focus(feature: EyeFeature) -> Result<CGPoint, GazeFocusRuntimeFailure> {
        do {
            let gazePoint = try pointEstimator.estimatePoint(for: feature)
            focusOverlay(gazePoint)
            return .success(gazePoint)
        } catch {
            return .failure(.gazeEstimationFailed)
        }
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

        _ = focus(feature: feature)
    }
}

/// Gaze runtime frame provider abstraction.
///
/// @author suho.do
/// @since 2026-07-03
protocol GazeFrameProviding: AnyObject {
    var onFrame: ((CVPixelBuffer) -> Void)? { get set }

    func start() throws

    func stop()
}

/// Gaze runtime landmark detector abstraction.
///
/// @author suho.do
/// @since 2026-07-03
protocol GazeFaceLandmarkDetecting {
    func detect(in pixelBuffer: CVPixelBuffer) throws -> [FaceLandmarkDetection]
}

/// Gaze runtime start 결과.
///
/// @author suho.do
/// @since 2026-07-03
enum GazeFocusRuntimeStartResult: Equatable {
    case success
    case failure(GazeFocusRuntimeStartFailure)
}

/// Gaze runtime start 실패 사유.
///
/// @author suho.do
/// @since 2026-07-03
enum GazeFocusRuntimeStartFailure: Equatable {
    case cameraGazeOptInDisabled
    case cameraPermissionDenied
    case calibrationUnavailable
    case frameProviderFailed
}

/// Gaze focus update 실패 사유.
///
/// @author suho.do
/// @since 2026-07-03
enum GazeFocusRuntimeFailure: Error, Equatable {
    case gazeEstimationFailed
}
