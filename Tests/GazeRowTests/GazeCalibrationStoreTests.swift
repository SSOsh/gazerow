import CoreGraphics
import XCTest
@testable import GazeRow

/// `GazeCalibrationStore`의 저장/로드/삭제 단위 테스트.
///
/// 실제 Application Support를 오염시키지 않도록 임시 디렉토리를 baseOverride로 주입한다.
///
/// @author suho.do
/// @since 2026-07-03
final class GazeCalibrationStoreTests: XCTestCase {

    /// 테스트마다 격리되는 임시 base 디렉토리.
    private var tempBase: URL!

    override func setUpWithError() throws {
        tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("GazeCalibrationStoreTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempBase, FileManager.default.fileExists(atPath: tempBase.path) {
            try FileManager.default.removeItem(at: tempBase)
        }
    }

    private func makeSUT() -> GazeCalibrationStore {
        GazeCalibrationStore(directory: LogDirectory(baseOverride: tempBase))
    }

    private func makeSample(x: CGFloat, y: CGFloat) -> GazeCalibrationSample {
        GazeCalibrationSample(
            feature: EyeFeature(
                leftEyeCenter: CGPoint(x: x, y: y),
                rightEyeCenter: CGPoint(x: x + 0.1, y: y),
                eyeMidpoint: CGPoint(x: x + 0.05, y: y),
                interocularDistance: 0.1,
                noseCenter: CGPoint(x: x + 0.05, y: y - 0.05),
                faceCenter: CGPoint(x: x + 0.05, y: y + 0.05)
            ),
            screenPoint: CGPoint(x: x * 1_000, y: y * 1_000)
        )
    }

    func test_load_저장전에는_빈배열() {
        // given
        let sut = makeSUT()

        // when
        let loaded = sut.load()

        // then
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_save_후_load하면_동일_샘플_반환() throws {
        // given
        let sut = makeSUT()
        let samples = [
            makeSample(x: 0.1, y: 0.1),
            makeSample(x: 0.5, y: 0.5),
            makeSample(x: 0.9, y: 0.9)
        ]

        // when
        try sut.save(samples)
        let loaded = sut.load()

        // then
        XCTAssertEqual(loaded, samples)
    }

    func test_save_두번_호출하면_마지막_값으로_덮어쓴다() throws {
        // given
        let sut = makeSUT()

        // when
        try sut.save([makeSample(x: 0.1, y: 0.1)])
        try sut.save([makeSample(x: 0.2, y: 0.2), makeSample(x: 0.3, y: 0.3)])
        let loaded = sut.load()

        // then
        XCTAssertEqual(loaded, [makeSample(x: 0.2, y: 0.2), makeSample(x: 0.3, y: 0.3)])
    }

    func test_clear_후에는_빈배열() throws {
        // given
        let sut = makeSUT()
        try sut.save([makeSample(x: 0.4, y: 0.4)])

        // when
        try sut.clear()
        let loaded = sut.load()

        // then
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_clear_파일이_없어도_에러없이_동작() throws {
        // given
        let sut = makeSUT()

        // when & then
        XCTAssertNoThrow(try sut.clear())
    }
}
