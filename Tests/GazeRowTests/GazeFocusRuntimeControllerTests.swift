import CoreGraphics
import CoreVideo
import XCTest
@testable import GazeRow

/// GazeFocusRuntimeController 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeFocusRuntimeControllerTests: XCTestCase {

    func test_start_optInOff이면_frameProvider를_시작하지_않음() {
        // given
        let frameProvider = StubGazeFrameProvider()
        let sut = makeSUT(
            frameProvider: frameProvider,
            isCameraGazeEnabled: { false },
            isCameraAuthorized: { true },
            pointEstimator: makeReadyEstimator()
        )

        // when
        let result = sut.start()

        // then
        XCTAssertEqual(result, .failure(.cameraGazeOptInDisabled))
        XCTAssertEqual(frameProvider.startCallCount, 0)
    }

    func test_start_camera권한없으면_frameProvider를_시작하지_않음() {
        // given
        let frameProvider = StubGazeFrameProvider()
        let sut = makeSUT(
            frameProvider: frameProvider,
            isCameraGazeEnabled: { true },
            isCameraAuthorized: { false },
            pointEstimator: makeReadyEstimator()
        )

        // when
        let result = sut.start()

        // then
        XCTAssertEqual(result, .failure(.cameraPermissionDenied))
        XCTAssertEqual(frameProvider.startCallCount, 0)
    }

    func test_start_calibration없으면_frameProvider를_시작하지_않음() {
        // given
        let frameProvider = StubGazeFrameProvider()
        let sut = makeSUT(
            frameProvider: frameProvider,
            isCameraGazeEnabled: { true },
            isCameraAuthorized: { true },
            pointEstimator: GazePointEstimator(calibrationModel: GazeCalibrationModel())
        )

        // when
        let result = sut.start()

        // then
        XCTAssertEqual(result, .failure(.calibrationUnavailable))
        XCTAssertEqual(frameProvider.startCallCount, 0)
    }

    func test_start_조건이_충족되면_frameProvider를_시작() {
        // given
        let frameProvider = StubGazeFrameProvider()
        let sut = makeSUT(
            frameProvider: frameProvider,
            isCameraGazeEnabled: { true },
            isCameraAuthorized: { true },
            pointEstimator: makeReadyEstimator()
        )

        // when
        let result = sut.start()

        // then
        XCTAssertEqual(result, .success)
        XCTAssertEqual(frameProvider.startCallCount, 1)
        XCTAssertNotNil(frameProvider.onFrame)
    }

    func test_focus_feature를_gazePoint로_변환해_overlayFocus에_전달() throws {
        // given
        var focusedPoints: [CGPoint] = []
        let sut = makeSUT(
            pointEstimator: makeReadyEstimator(),
            focusOverlay: { point in
                focusedPoints.append(point)
            }
        )

        // when
        let result = sut.focus(feature: makeFeature(x: 0.5, y: 0.5))

        // then
        XCTAssertEqual(try result.get(), CGPoint(x: 50, y: 50))
        XCTAssertEqual(focusedPoints, [CGPoint(x: 50, y: 50)])
    }

    func test_frameCallback은_minimumFrameInterval보다_빠른_frame을_건너뛴다() throws {
        // given
        let frameProvider = StubGazeFrameProvider()
        let detector = StubGazeLandmarkDetector(detections: [makeDetection(x: 0.5, y: 0.5)])
        var now = Date(timeIntervalSince1970: 10)
        var focusedPoints: [CGPoint] = []
        let sut = makeSUT(
            frameProvider: frameProvider,
            landmarkDetector: detector,
            pointEstimator: makeReadyEstimator(),
            focusOverlay: { point in
                focusedPoints.append(point)
            },
            minimumFrameInterval: 0.1,
            dateProvider: { now }
        )
        XCTAssertEqual(sut.start(), .success)
        let pixelBuffer = try makePixelBuffer()

        // when
        frameProvider.onFrame?(pixelBuffer)
        now = Date(timeIntervalSince1970: 10.05)
        frameProvider.onFrame?(pixelBuffer)
        now = Date(timeIntervalSince1970: 10.11)
        frameProvider.onFrame?(pixelBuffer)

        // then
        XCTAssertEqual(detector.detectCallCount, 2)
        XCTAssertEqual(focusedPoints.count, 2)
        XCTAssertEqual(focusedPoints[0].x, 50, accuracy: 0.000_001)
        XCTAssertEqual(focusedPoints[0].y, 50, accuracy: 0.000_001)
        XCTAssertEqual(focusedPoints[1].x, 50, accuracy: 0.000_001)
        XCTAssertEqual(focusedPoints[1].y, 50, accuracy: 0.000_001)
    }

    private func makeSUT(
        frameProvider: StubGazeFrameProvider = StubGazeFrameProvider(),
        landmarkDetector: StubGazeLandmarkDetector = StubGazeLandmarkDetector(),
        isCameraGazeEnabled: @escaping () -> Bool = { true },
        isCameraAuthorized: @escaping () -> Bool = { true },
        pointEstimator: GazePointEstimator,
        focusOverlay: @escaping (CGPoint) -> Void = { _ in },
        minimumFrameInterval: TimeInterval = 1.0 / 15.0,
        dateProvider: @escaping () -> Date = Date.init
    ) -> GazeFocusRuntimeController {
        GazeFocusRuntimeController(
            frameProvider: frameProvider,
            landmarkDetector: landmarkDetector,
            pointEstimator: pointEstimator,
            isCameraGazeEnabled: isCameraGazeEnabled,
            isCameraAuthorized: isCameraAuthorized,
            focusOverlay: focusOverlay,
            minimumFrameInterval: minimumFrameInterval,
            dateProvider: dateProvider
        )
    }

    private func makeReadyEstimator() -> GazePointEstimator {
        GazePointEstimator(
            calibrationModel: GazeCalibrationModel(
                samples: [
                    makeSample(x: 0.1, y: 0.1, screenX: 0, screenY: 0),
                    makeSample(x: 0.9, y: 0.1, screenX: 100, screenY: 0),
                    makeSample(x: 0.1, y: 0.9, screenX: 0, screenY: 100),
                    makeSample(x: 0.9, y: 0.9, screenX: 100, screenY: 100),
                    makeSample(x: 0.5, y: 0.5, screenX: 50, screenY: 50)
                ]
            )
        )
    }

    private func makeSample(
        x: CGFloat,
        y: CGFloat,
        screenX: CGFloat,
        screenY: CGFloat
    ) -> GazeCalibrationSample {
        GazeCalibrationSample(
            feature: makeFeature(x: x, y: y),
            screenPoint: CGPoint(x: screenX, y: screenY)
        )
    }

    private func makeFeature(x: CGFloat, y: CGFloat) -> EyeFeature {
        EyeFeature(
            leftEyeCenter: CGPoint(x: x - 0.1, y: y),
            rightEyeCenter: CGPoint(x: x + 0.1, y: y),
            eyeMidpoint: CGPoint(x: x, y: y),
            interocularDistance: 0.2,
            noseCenter: nil,
            faceCenter: CGPoint(x: x, y: y)
        )
    }

    private func makeDetection(x: CGFloat, y: CGFloat) -> FaceLandmarkDetection {
        FaceLandmarkDetection(
            boundingBox: CGRect(x: x - 0.2, y: y - 0.2, width: 0.4, height: 0.4),
            confidence: 1,
            leftEye: [CGPoint(x: x - 0.1, y: y)],
            rightEye: [CGPoint(x: x + 0.1, y: y)],
            faceContour: [],
            nose: []
        )
    }

    private func makePixelBuffer() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            1,
            1,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        return try XCTUnwrap(pixelBuffer)
    }
}

private final class StubGazeFrameProvider: GazeFrameProviding {
    var onFrame: ((CVPixelBuffer) -> Void)?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func start() throws {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }
}

private final class StubGazeLandmarkDetector: GazeFaceLandmarkDetecting {
    private let detections: [FaceLandmarkDetection]
    private(set) var detectCallCount = 0

    init(detections: [FaceLandmarkDetection] = []) {
        self.detections = detections
    }

    func detect(in pixelBuffer: CVPixelBuffer) throws -> [FaceLandmarkDetection] {
        detectCallCount += 1
        return detections
    }
}
