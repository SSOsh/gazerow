import XCTest
@testable import GazeRow

/// `InteractionLogStore`의 opt-in 기반 파일 기록/삭제 단위 테스트.
///
/// 실제 Application Support를 오염시키지 않도록 임시 디렉토리를 base로 주입하고,
/// opt-in 플래그는 임시 suite `UserDefaults`를 주입한다.
///
/// @author suho.do
/// @since 2026-07-02
final class InteractionLogStoreTests: XCTestCase {

    /// 테스트마다 격리되는 임시 디렉토리.
    private var tempBase: URL!

    override func setUpWithError() throws {
        tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("InteractionLogStoreTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempBase, FileManager.default.fileExists(atPath: tempBase.path) {
            try FileManager.default.removeItem(at: tempBase)
        }
    }

    /// 테스트마다 격리된 임시 UserDefaults를 만든다.
    private func makeDefaults() -> UserDefaults {
        let suiteName = "InteractionLogStoreTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    /// 임시 base를 쓰는 store와 로그 파일 URL을 함께 만든다.
    private func makeStore(defaults: UserDefaults) throws -> (InteractionLogStore, URL) {
        let logDirectory = LogDirectory(baseOverride: tempBase)
        let store = InteractionLogStore(defaults: defaults, logDirectory: logDirectory)
        let logURL = try logDirectory.interactionLogURL()
        return (store, logURL)
    }

    private func sampleEvent() -> InteractionEvent {
        InteractionEvent(
            timestamp: Date(timeIntervalSince1970: 0),
            kind: .focusChanged(method: "keyboard"),
            windowTitleHash: "abc123"
        )
    }

    func test_기본상태_optIn은_false() throws {
        // given
        let (store, _) = try makeStore(defaults: makeDefaults())

        // then
        XCTAssertFalse(store.isOptInEnabled)
    }

    func test_optInOff면_record해도_파일미생성() throws {
        // given
        let (store, logURL) = try makeStore(defaults: makeDefaults())

        // when
        store.record(sampleEvent())

        // then
        XCTAssertFalse(FileManager.default.fileExists(atPath: logURL.path))
    }

    func test_optInOn면_record시_파일에_append() throws {
        // given
        let (store, logURL) = try makeStore(defaults: makeDefaults())
        store.isOptInEnabled = true

        // when
        store.record(sampleEvent())
        store.record(sampleEvent())

        // then
        XCTAssertTrue(FileManager.default.fileExists(atPath: logURL.path))
        let content = try String(contentsOf: logURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(content.contains("\"type\":\"focusChanged\""))
        XCTAssertTrue(content.contains("\"windowTitleHash\":\"abc123\""))
    }

    func test_record된_JSON에_원문title은_없다() throws {
        // given
        let (store, logURL) = try makeStore(defaults: makeDefaults())
        store.isOptInEnabled = true

        // when
        store.record(sampleEvent())

        // then: hash만 있고 method는 코드값만 담긴다.
        let content = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(content.contains("\"method\":\"keyboard\""))
        XCTAssertFalse(content.contains("Untitled"))
    }

    func test_deleteAll_로그파일_삭제() throws {
        // given
        let (store, logURL) = try makeStore(defaults: makeDefaults())
        store.isOptInEnabled = true
        store.record(sampleEvent())
        XCTAssertTrue(FileManager.default.fileExists(atPath: logURL.path))

        // when
        store.deleteAll()

        // then
        XCTAssertFalse(FileManager.default.fileExists(atPath: logURL.path))
    }

    func test_deleteAll_파일없어도_안전() throws {
        // given
        let (store, logURL) = try makeStore(defaults: makeDefaults())
        XCTAssertFalse(FileManager.default.fileExists(atPath: logURL.path))

        // when & then: 예외 없이 no-op
        store.deleteAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: logURL.path))
    }
}
