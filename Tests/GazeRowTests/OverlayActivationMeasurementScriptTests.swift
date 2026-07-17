import Foundation
import XCTest

/// Overlay activation 측정 스크립트의 입력 계약을 검증한다.
///
/// @author suho.do
/// @since 2026-07-17
final class OverlayActivationMeasurementScriptTests: XCTestCase {

    func test_help는_사용법을출력한다() throws {
        // given
        let script = repositoryRoot.appendingPathComponent("scripts/measure_overlay_activation.sh")

        // when
        let result = try runScript(script, arguments: ["--help"])

        // then
        XCTAssertEqual(result.status, 0)
        XCTAssertTrue(result.output.contains("--target-bundle-id"))
        XCTAssertTrue(result.output.contains("does not type, focus, or click"))
    }

    func test_targetBundleId가없으면_사용법오류를반환한다() throws {
        // given
        let script = repositoryRoot.appendingPathComponent("scripts/measure_overlay_activation.sh")

        // when
        let result = try runScript(script)

        // then
        XCTAssertEqual(result.status, 2)
        XCTAssertTrue(result.output.contains("--target-bundle-id is required"))
    }

    func test_firstDisplayPass파서는_awk예약어_index를반복변수로사용하지않는다() throws {
        // given
        let script = repositoryRoot.appendingPathComponent("scripts/measure_overlay_activation.sh")

        // when
        let source = try String(contentsOf: script, encoding: .utf8)

        // then
        XCTAssertTrue(source.contains("for (field = 1; field <= NF; field++)"))
        XCTAssertFalse(source.contains("for (index = 1; index <= NF; index++)"))
        XCTAssertFalse(source.contains("index = int((count * percentile) + 0.999999)"))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func runScript(
        _ script: URL,
        arguments: [String] = []
    ) throws -> (status: Int32, output: String) {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path] + arguments
        process.standardOutput = output
        process.standardError = output

        try process.run()
        process.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        return (
            process.terminationStatus,
            String(decoding: data, as: UTF8.self)
        )
    }
}
