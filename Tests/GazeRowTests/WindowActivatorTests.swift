import AppKit
import XCTest
@testable import GazeRow

/// WindowActivator 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-09
@MainActor
final class WindowActivatorTests: XCTestCase {

    func test_activate는_app이_없으면_appNotRunning을_반환한다() {
        // given
        let sut = WindowActivator(runningApplicationProvider: { _ in nil })

        // when
        let result = sut.activate(entry)

        // then
        XCTAssertWindowActivateFailure(result, .appNotRunning)
    }

    func test_activate는_frontmost가_될때까지_polling한다() {
        // given
        var frontmostCalls = 0
        var slept: [TimeInterval] = []
        let app = NSRunningApplication.current
        let sut = WindowActivator(
            runningApplicationProvider: { _ in app },
            activateApplication: { _ in true },
            frontmostBundleIDProvider: {
                frontmostCalls += 1
                return frontmostCalls >= 3 ? "com.example.Target" : "com.example.Other"
            },
            sleep: { slept.append($0) },
            maxPollDuration: 1,
            pollInterval: 0.05
        )

        // when
        let result = sut.activate(entry)

        // then
        XCTAssertWindowActivateSuccess(result)
        XCTAssertEqual(slept, [0.05, 0.05])
    }

    func test_activate는_frontmost_timeout을_반환한다() {
        // given
        let app = NSRunningApplication.current
        let sut = WindowActivator(
            runningApplicationProvider: { _ in app },
            activateApplication: { _ in true },
            frontmostBundleIDProvider: { "com.example.Other" },
            sleep: { _ in },
            maxPollDuration: 0.1,
            pollInterval: 0.05
        )

        // when
        let result = sut.activate(entry)

        // then
        XCTAssertWindowActivateFailure(result, .frontmostTimeout)
    }

    private var entry: WindowEntry {
        WindowEntry(
            id: 0,
            appName: "Target",
            bundleID: "com.example.Target",
            windowTitle: "Main",
            windowTitleHash: "hash",
            pid: 100,
            axWindow: nil,
            appIcon: nil
        )
    }

    private func XCTAssertWindowActivateSuccess(
        _ result: Result<Void, WindowActivateFailure>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .success = result else {
            XCTFail("Expected success, got \(result).", file: file, line: line)
            return
        }
    }

    private func XCTAssertWindowActivateFailure(
        _ result: Result<Void, WindowActivateFailure>,
        _ expected: WindowActivateFailure,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let failure) = result else {
            XCTFail("Expected failure \(expected), got \(result).", file: file, line: line)
            return
        }
        XCTAssertEqual(failure, expected, file: file, line: line)
    }
}
