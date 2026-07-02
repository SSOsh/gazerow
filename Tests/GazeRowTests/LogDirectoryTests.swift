import XCTest
@testable import GazeRow

/// `LogDirectory`의 경로 resolve와 디렉토리 생성 단위 테스트.
///
/// 실제 Application Support를 오염시키지 않도록 임시 디렉토리를 baseOverride로 주입한다.
///
/// @author suho.do
/// @since 2026-07-02
final class LogDirectoryTests: XCTestCase {

    /// 테스트마다 격리되는 임시 base 디렉토리.
    private var tempBase: URL!

    override func setUpWithError() throws {
        tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("LogDirectoryTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempBase, FileManager.default.fileExists(atPath: tempBase.path) {
            try FileManager.default.removeItem(at: tempBase)
        }
    }

    private func makeSUT() -> LogDirectory {
        LogDirectory(baseOverride: tempBase)
    }

    func test_resolveDirectory_baseOverride하위에_GazeRow폴더_생성() throws {
        // given
        let sut = makeSUT()

        // when
        let directory = try sut.resolveDirectory()

        // then
        XCTAssertEqual(directory.lastPathComponent, "GazeRow")
        XCTAssertEqual(directory.deletingLastPathComponent().path, tempBase.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    }

    func test_resolveDirectory_두번_호출해도_같은경로_멱등() throws {
        // given
        let sut = makeSUT()

        // when
        let first = try sut.resolveDirectory()
        let second = try sut.resolveDirectory()

        // then
        XCTAssertEqual(first.path, second.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
    }

    func test_interactionLogURL_파일명과_상위디렉토리_보장() throws {
        // given
        let sut = makeSUT()

        // when
        let url = try sut.interactionLogURL()

        // then
        XCTAssertEqual(url.lastPathComponent, "interaction.log.jsonl")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "GazeRow")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }

    func test_debugExportURL_파일명과_상위디렉토리_보장() throws {
        // given
        let sut = makeSUT()

        // when
        let url = try sut.debugExportURL()

        // then
        XCTAssertEqual(url.lastPathComponent, "debug-export.txt")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "GazeRow")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }

    func test_interactionLog와_debugExport는_다른파일_같은디렉토리() throws {
        // given
        let sut = makeSUT()

        // when
        let logURL = try sut.interactionLogURL()
        let exportURL = try sut.debugExportURL()

        // then
        XCTAssertNotEqual(logURL.lastPathComponent, exportURL.lastPathComponent)
        XCTAssertEqual(
            logURL.deletingLastPathComponent().path,
            exportURL.deletingLastPathComponent().path
        )
    }
}
