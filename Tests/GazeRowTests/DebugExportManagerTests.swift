import XCTest
@testable import GazeRow

/// `DebugExportManager`의 export 생성/삭제 단위 테스트.
///
/// 실제 Application Support를 오염시키지 않도록 임시 디렉토리를 base로 주입한다.
///
/// @author suho.do
/// @since 2026-07-02
final class DebugExportManagerTests: XCTestCase {

    /// 테스트마다 격리되는 임시 디렉토리.
    private var tempBase: URL!

    override func setUpWithError() throws {
        tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("DebugExportManagerTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempBase, FileManager.default.fileExists(atPath: tempBase.path) {
            try FileManager.default.removeItem(at: tempBase)
        }
    }

    /// 임시 base를 쓰는 매니저와 export 파일 URL을 함께 만든다.
    private func makeManager(
        diagnostics: @escaping () -> String = { "diagnostic-body" }
    ) throws -> (DebugExportManager, URL) {
        let logDirectory = LogDirectory(baseOverride: tempBase)
        let manager = DebugExportManager(
            logDirectory: logDirectory,
            now: { Date(timeIntervalSince1970: 0) },
            diagnosticsProvider: diagnostics
        )
        let exportURL = try logDirectory.debugExportURL()
        return (manager, exportURL)
    }

    func test_createExport_파일생성() throws {
        // given
        let (manager, exportURL) = try makeManager()

        // when
        let created = try manager.createExport()

        // then
        XCTAssertEqual(created, exportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
    }

    func test_createExport_진단본문_포함() throws {
        // given
        let (manager, exportURL) = try makeManager(diagnostics: { "SCAN-SUMMARY-42" })

        // when
        try manager.createExport()

        // then
        let content = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertTrue(content.contains("gazerow Debug Export"))
        XCTAssertTrue(content.contains("SCAN-SUMMARY-42"))
    }

    func test_deleteAll_export파일_삭제() throws {
        // given
        let (manager, exportURL) = try makeManager()
        try manager.createExport()
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        // when
        manager.deleteAll()

        // then
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportURL.path))
    }

    func test_deleteAll_파일없어도_안전() throws {
        // given
        let (manager, exportURL) = try makeManager()
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportURL.path))

        // when & then: 예외 없이 no-op
        manager.deleteAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportURL.path))
    }
}
