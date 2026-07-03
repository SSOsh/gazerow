import CoreGraphics
import CoreVideo
import XCTest
@testable import GazeRow

/// `GazeOneShotFocusController`의 one-shot 캡처 동작 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeOneShotFocusControllerTests: XCTestCase {

    func test_start_calibration없으면_frameProvider를_시작하지_않고_실패() {
        // given
        let frameProvider = MockGazeFrameProvider()
        let sut = GazeOneShotFocusController(
            pointEstimator: GazePointEstimator(calibrationModel: GazeCalibrationModel()),
            frameProvider: frameProvider,
            landmarkDetector: ConfigurableLandmarkDetector()
        )
        var results: [Result<CGPoint, GazeOneShotFailure>] = []

        // when
        sut.start { results.append($0) }

        // then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, .failure(.calibrationUnavailable))
        XCTAssertEqual(frameProvider.startCallCount, 0)
    }

    func test_start_frameProvider가_실패하면_frameProviderFailed로_종료() {
        // given
        let frameProvider = MockGazeFrameProvider()
        frameProvider.startError = TestError()
        let sut = GazeOneShotFocusController(
            pointEstimator: makeReadyEstimator(),
            frameProvider: frameProvider,
            landmarkDetector: ConfigurableLandmarkDetector()
        )
        var results: [Result<CGPoint, GazeOneShotFailure>] = []

        // when
        sut.start { results.append($0) }

        // then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, .failure(.frameProviderFailed))
        XCTAssertEqual(frameProvider.stopCallCount, 1)
    }

    func test_유효_feature를_얻으면_추정좌표로_성공하고_카메라를_끈다() throws {
        // given
        let frameProvider = MockGazeFrameProvider()
        let detector = ConfigurableLandmarkDetector()
        detector.detections = [makeDetection()]
        let sut = GazeOneShotFocusController(
            pointEstimator: makeReadyEstimator(),
            frameProvider: frameProvider,
            landmarkDetector: detector
        )
        var results: [Result<CGPoint, GazeOneShotFailure>] = []

        // when
        sut.start { results.append($0) }
        frameProvider.emit(makePixelBuffer())

        // then
        XCTAssertEqual(results.count, 1)
        assertPoint(try results.first?.get(), equals: CGPoint(x: 50, y: 50))
        XCTAssertEqual(frameProvider.stopCallCount, 1)
        XCTAssertNil(frameProvider.onFrame)
    }

    func test_얼굴이_없는_프레임은_대기하다가_유효_feature에서_성공() throws {
        // given
        let frameProvider = MockGazeFrameProvider()
        let detector = ConfigurableLandmarkDetector()
        detector.detections = []
        let sut = GazeOneShotFocusController(
            pointEstimator: makeReadyEstimator(),
            frameProvider: frameProvider,
            landmarkDetector: detector
        )
        var results: [Result<CGPoint, GazeOneShotFailure>] = []

        // when: 얼굴 없는 프레임 → 아직 종료되지 않음
        sut.start { results.append($0) }
        frameProvider.emit(makePixelBuffer())
        XCTAssertTrue(results.isEmpty)

        // when: 유효 feature 프레임
        detector.detections = [makeDetection()]
        frameProvider.emit(makePixelBuffer())

        // then
        XCTAssertEqual(results.count, 1)
        assertPoint(try results.first?.get(), equals: CGPoint(x: 50, y: 50))
    }

    func test_cancel하면_noFaceDetected로_종료() {
        // given
        let frameProvider = MockGazeFrameProvider()
        let sut = GazeOneShotFocusController(
            pointEstimator: makeReadyEstimator(),
            frameProvider: frameProvider,
            landmarkDetector: ConfigurableLandmarkDetector()
        )
        var results: [Result<CGPoint, GazeOneShotFailure>] = []

        // when
        sut.start { results.append($0) }
        sut.cancel()

        // then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, .failure(.noFaceDetected))
        XCTAssertEqual(frameProvider.stopCallCount, 1)
    }

    func test_start하면_타임아웃이_예약된다() {
        // given
        let frameProvider = MockGazeFrameProvider()
        let scheduler = ManualTimeoutScheduler()
        let sut = GazeOneShotFocusController(
            pointEstimator: makeReadyEstimator(),
            frameProvider: frameProvider,
            landmarkDetector: ConfigurableLandmarkDetector(),
            timeout: 2.0,
            timeoutScheduler: scheduler
        )

        // when
        sut.start { _ in }

        // then
        XCTAssertEqual(scheduler.scheduledInterval, 2.0)
    }

    func test_얼굴을_못_얻은_채_타임아웃되면_카메라를_끄고_noFaceDetected로_종료() {
        // given: 얼굴이 계속 없는 상황
        let frameProvider = MockGazeFrameProvider()
        let detector = ConfigurableLandmarkDetector()
        detector.detections = []
        let scheduler = ManualTimeoutScheduler()
        let sut = GazeOneShotFocusController(
            pointEstimator: makeReadyEstimator(),
            frameProvider: frameProvider,
            landmarkDetector: detector,
            timeoutScheduler: scheduler
        )
        var results: [Result<CGPoint, GazeOneShotFailure>] = []

        // when: 얼굴 없는 프레임만 오다가 타임아웃 발생
        sut.start { results.append($0) }
        frameProvider.emit(makePixelBuffer())
        XCTAssertTrue(results.isEmpty)
        scheduler.fire()

        // then: 카메라가 꺼지고 실패로 종료
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, .failure(.noFaceDetected))
        XCTAssertEqual(frameProvider.stopCallCount, 1)
        XCTAssertNil(frameProvider.onFrame)
    }

    func test_유효_feature로_성공하면_타임아웃_예약이_취소된다() {
        // given
        let frameProvider = MockGazeFrameProvider()
        let detector = ConfigurableLandmarkDetector()
        detector.detections = [makeDetection()]
        let scheduler = ManualTimeoutScheduler()
        let sut = GazeOneShotFocusController(
            pointEstimator: makeReadyEstimator(),
            frameProvider: frameProvider,
            landmarkDetector: detector,
            timeoutScheduler: scheduler
        )

        // when
        sut.start { _ in }
        frameProvider.emit(makePixelBuffer())

        // then: 성공 종료 시 예약된 타임아웃이 취소됨
        XCTAssertGreaterThanOrEqual(scheduler.cancelCallCount, 1)
    }

    func test_성공_후_타임아웃이_발화해도_completion은_추가로_불리지_않는다() {
        // given
        let frameProvider = MockGazeFrameProvider()
        let detector = ConfigurableLandmarkDetector()
        detector.detections = [makeDetection()]
        let scheduler = ManualTimeoutScheduler()
        let sut = GazeOneShotFocusController(
            pointEstimator: makeReadyEstimator(),
            frameProvider: frameProvider,
            landmarkDetector: detector,
            timeoutScheduler: scheduler
        )
        var callCount = 0

        // when: 성공 종료 후 뒤늦게 타임아웃 핸들러가 호출돼도 무시돼야 함
        sut.start { _ in callCount += 1 }
        frameProvider.emit(makePixelBuffer())
        scheduler.fire()

        // then
        XCTAssertEqual(callCount, 1)
    }

    func test_여러_유효_프레임이_와도_completion은_정확히_한_번() {
        // given
        let frameProvider = MockGazeFrameProvider()
        let detector = ConfigurableLandmarkDetector()
        detector.detections = [makeDetection()]
        let sut = GazeOneShotFocusController(
            pointEstimator: makeReadyEstimator(),
            frameProvider: frameProvider,
            landmarkDetector: detector
        )
        var callCount = 0

        // when
        sut.start { _ in callCount += 1 }
        frameProvider.emit(makePixelBuffer())
        frameProvider.emit(makePixelBuffer())
        sut.cancel()

        // then
        XCTAssertEqual(callCount, 1)
    }

    // MARK: - Helpers

    private func assertPoint(
        _ actual: CGPoint?,
        equals expected: CGPoint,
        accuracy: CGFloat = 0.001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("point가 nil", file: file, line: line)
            return
        }
        XCTAssertEqual(actual.x, expected.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: accuracy, file: file, line: line)
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
            feature: EyeFeature(
                leftEyeCenter: CGPoint(x: x - 0.1, y: y),
                rightEyeCenter: CGPoint(x: x + 0.1, y: y),
                eyeMidpoint: CGPoint(x: x, y: y),
                interocularDistance: 0.2,
                noseCenter: nil,
                faceCenter: CGPoint(x: x, y: y)
            ),
            screenPoint: CGPoint(x: screenX, y: screenY)
        )
    }

    /// leftEye=(0.4,0.5), rightEye=(0.6,0.5) → eyeMidpoint=(0.5,0.5), distance=0.2.
    /// makeReadyEstimator의 (0.5,0.5) 샘플과 정확히 일치해 (50,50)으로 추정된다.
    private func makeDetection() -> FaceLandmarkDetection {
        FaceLandmarkDetection(
            boundingBox: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            confidence: 0.9,
            leftEye: [CGPoint(x: 0.4, y: 0.5)],
            rightEye: [CGPoint(x: 0.6, y: 0.5)],
            faceContour: [],
            nose: []
        )
    }

    private func makePixelBuffer() -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            4,
            4,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        return pixelBuffer!
    }
}

private struct TestError: Error {}

private final class MockGazeFrameProvider: GazeFrameProviding {
    var onFrame: ((CVPixelBuffer) -> Void)?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    var startError: Error?

    func start() throws {
        startCallCount += 1
        if let startError {
            throw startError
        }
    }

    func stop() {
        stopCallCount += 1
    }

    func emit(_ pixelBuffer: CVPixelBuffer) {
        onFrame?(pixelBuffer)
    }
}

private final class ManualTimeoutScheduler: GazeOneShotTimeoutScheduling {
    private(set) var scheduledInterval: TimeInterval?
    private(set) var cancelCallCount = 0
    private var handler: (() -> Void)?

    func schedule(after interval: TimeInterval, handler: @escaping () -> Void) {
        scheduledInterval = interval
        self.handler = handler
    }

    func cancel() {
        cancelCallCount += 1
        handler = nil
    }

    /// 예약된 타임아웃을 수동으로 발화시킨다(시간 지연 없이 검증).
    func fire() {
        handler?()
    }
}

private final class ConfigurableLandmarkDetector: GazeFaceLandmarkDetecting {
    var detections: [FaceLandmarkDetection] = []
    var error: Error?

    func detect(in pixelBuffer: CVPixelBuffer) throws -> [FaceLandmarkDetection] {
        if let error {
            throw error
        }
        return detections
    }
}
