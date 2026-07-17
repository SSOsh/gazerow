import Foundation
import XCTest

/// 무료 ZIP 베타 배포 스크립트의 입력 검증과 사용자 안내를 검증한다.
///
/// @author suho.do
/// @since 2026-07-17
final class BetaDistributionScriptTests: XCTestCase {

    func test_packageScript는_잘못된버전을_빌드전에거부한다() throws {
        // given
        let script = repositoryRoot
            .appendingPathComponent("scripts/package_beta_release.sh")

        // when
        let result = try runScript(
            script,
            environment: ["MARKETING_VERSION": "0.1-beta"]
        )

        // then
        XCTAssertEqual(result.status, 64)
        XCTAssertTrue(result.output.contains("MARKETING_VERSION"))
    }

    func test_verifyScript는_필수인자가없으면_usage를반환한다() throws {
        // given
        let script = repositoryRoot
            .appendingPathComponent("scripts/verify_beta_release.sh")

        // when
        let result = try runScript(script)

        // then
        XCTAssertEqual(result.status, 64)
        XCTAssertTrue(result.output.contains("Usage:"))
    }

    func test_readme는_무료베타의_OpenAnyway절차를_안내한다() throws {
        // given
        let korean = try String(
            contentsOf: repositoryRoot.appendingPathComponent("README.md"),
            encoding: .utf8
        )
        let english = try String(
            contentsOf: repositoryRoot.appendingPathComponent("README.en.md"),
            encoding: .utf8
        )

        // when & then
        XCTAssertTrue(korean.contains("확인 없이 열기(Open Anyway)"))
        XCTAssertTrue(korean.contains("macos-universal.zip"))
        XCTAssertTrue(english.contains("Open Anyway"))
        XCTAssertTrue(english.contains("macos-universal.zip"))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func runScript(
        _ script: URL,
        environment overrides: [String: String] = [:]
    ) throws -> (status: Int32, output: String) {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        process.standardOutput = output
        process.standardError = output
        process.environment = ProcessInfo.processInfo.environment.merging(
            overrides,
            uniquingKeysWith: { _, override in override }
        )

        try process.run()
        process.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        return (
            process.terminationStatus,
            String(decoding: data, as: UTF8.self)
        )
    }
}
