import CoreGraphics
import CoreVideo
import XCTest
@testable import GazeRow

/// `GazeCalibrationCoordinator` 캡처/진행/저장 흐름 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeCalibrationCoordinatorTests: XCTestCase {

    private let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    private let twoTargets = [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 1.0, y: 1.0)]

    private var tempBase: URL!

    override func setUpWithError() throws {
        tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("GazeCalibrationCoordinatorTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempBase, FileManager.default.fileExists(atPath: tempBase.path) {
            try FileManager.default.removeItem(at: tempBase)
        }
    }

    func test_start_frameProvider를_시작하고_초기_진행을_알린다() {
        // given
        let frameProvider = MockGazeFrameProvider()
        var progresses: [GazeCalibrationSession] = []
        let sut = makeSUT(
            frameProvider: frameProvider,
            detector: ConfigurableLandmarkDetector(),
            onProgress: { progresses.append($0) }
        )

        // when
        sut.start()

        // then
        XCTAssertEqual(frameProvider.startCallCount, 1)
        XCTAssertEqual(progresses.count, 1)
        XCTAssertEqual(progresses.first?.currentIndex, 0)
    }

    func test_start_frameProvider가_실패하면_frameProviderFailed로_종료() {
        // given
        let frameProvider = MockGazeFrameProvider()
        frameProvider.startError = TestError()
        var results: [Result<[GazeCalibrationSample], GazeCalibrationFailure>] = []
        let sut = makeSUT(
            frameProvider: frameProvider,
            detector: ConfigurableLandmarkDetector(),
            onFinished: { results.append($0) }
        )

        // when
        sut.start()

        // then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, .failure(.frameProviderFailed))
    }

    func test_captureCurrentTarget_유효_feature_없으면_false() {
        // given
        let frameProvider = MockGazeFrameProvider()
        let sut = makeSUT(
            frameProvider: frameProvider,
            detector: ConfigurableLandmarkDetector()
        )
        sut.start()

        // when: 아직 프레임이 없음
        let result = sut.captureCurrentTarget()

        // then
        XCTAssertFalse(result)
    }

    func test_captureCurrentTarget_유효_feature_있으면_기록하고_전진() {
        // given
        let frameProvider = MockGazeFrameProvider()
        let detector = ConfigurableLandmarkDetector()
        detector.detections = [makeDetection()]
        var progresses: [GazeCalibrationSession] = []
        let sut = makeSUT(
            frameProvider: frameProvider,
            detector: detector,
            onProgress: { progresses.append($0) }
        )
        sut.start()
        frameProvider.emit(makePixelBuffer())

        // when
        let result = sut.captureCurrentTarget()

        // then
        XCTAssertTrue(result)
        XCTAssertEqual(progresses.last?.currentIndex, 1)
        XCTAssertEqual(progresses.last?.samples.count, 1)
        XCTAssertEqual(progresses.last?.samples.first?.screenPoint, CGPoint(x: 0, y: 0))
    }

    func test_모든_타깃_캡처하면_store에_저장하고_success로_종료() throws {
        // given
        let frameProvider = MockGazeFrameProvider()
        let detector = ConfigurableLandmarkDetector()
        detector.detections = [makeDetection()]
        let store = GazeCalibrationStore(directory: LogDirectory(baseOverride: tempBase))
        var results: [Result<[GazeCalibrationSample], GazeCalibrationFailure>] = []
        let sut = makeSUT(
            frameProvider: frameProvider,
            detector: detector,
            store: store,
            onFinished: { results.append($0) }
        )
        sut.start()

        // when: 두 타깃 모두 캡처
        frameProvider.emit(makePixelBuffer())
        XCTAssertTrue(sut.captureCurrentTarget())
        frameProvider.emit(makePixelBuffer())
        XCTAssertTrue(sut.captureCurrentTarget())

        // then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(try results.first?.get().count, 2)
        XCTAssertEqual(frameProvider.stopCallCount, 1)
        XCTAssertEqual(store.load().count, 2)
    }

    func test_완료_후_captureCurrentTarget는_무시() {
        // given
        let frameProvider = MockGazeFrameProvider()
        let detector = ConfigurableLandmarkDetector()
        detector.detections = [makeDetection()]
        let sut = makeSUT(
            frameProvider: frameProvider,
            detector: detector,
            store: GazeCalibrationStore(directory: LogDirectory(baseOverride: tempBase))
        )
        sut.start()
        frameProvider.emit(makePixelBuffer())
        _ = sut.captureCurrentTarget()
        frameProvider.emit(makePixelBuffer())
        _ = sut.captureCurrentTarget()

        // when: 완료 후 추가 캡처
        frameProvider.emit(makePixelBuffer())
        let result = sut.captureCurrentTarget()

        // then
        XCTAssertFalse(result)
    }

    func test_cancel하면_cancelled로_종료하고_카메라를_끈다() {
        // given
        let frameProvider = MockGazeFrameProvider()
        var results: [Result<[GazeCalibrationSample], GazeCalibrationFailure>] = []
        let sut = makeSUT(
            frameProvider: frameProvider,
            detector: ConfigurableLandmarkDetector(),
            onFinished: { results.append($0) }
        )
        sut.start()

        // when
        sut.cancel()

        // then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, .failure(.cancelled))
        XCTAssertEqual(frameProvider.stopCallCount, 1)
    }

    // MARK: - Helpers

    private func makeSUT(
        frameProvider: MockGazeFrameProvider,
        detector: ConfigurableLandmarkDetector,
        store: GazeCalibrationStore? = nil,
        onProgress: @escaping (GazeCalibrationSession) -> Void = { _ in },
        onFinished: @escaping (Result<[GazeCalibrationSample], GazeCalibrationFailure>) -> Void = { _ in }
    ) -> GazeCalibrationCoordinator {
        GazeCalibrationCoordinator(
            screenBounds: bounds,
            normalizedTargets: twoTargets,
            frameProvider: frameProvider,
            landmarkDetector: detector,
            featureExtractor: EyeFeatureExtractor(),
            store: store ?? GazeCalibrationStore(directory: LogDirectory(baseOverride: tempBase)),
            onProgress: onProgress,
            onFinished: onFinished
        )
    }

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
        CVPixelBufferCreate(kCFAllocatorDefault, 4, 4, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
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

private final class ConfigurableLandmarkDetector: GazeFaceLandmarkDetecting {
    var detections: [FaceLandmarkDetection] = []

    func detect(in pixelBuffer: CVPixelBuffer) throws -> [FaceLandmarkDetection] {
        detections
    }
}
