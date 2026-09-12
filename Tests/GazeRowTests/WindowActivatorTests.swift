import AppKit
import XCTest
@testable import GazeRow

/// WindowActivator 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-09
@MainActor
final class WindowActivatorTests: XCTestCase {

    func test_activate는_app이_없으면_appNotRunning을_반환한다() async {
        // given
        let sut = WindowActivator(runningApplicationProvider: { _ in nil })

        // when
        let result = await sut.activate(entry)

        // then
        XCTAssertWindowActivateFailure(result, .appNotRunning)
    }

    func test_activate는_frontmost가_될때까지_polling한다() async {
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
        let result = await sut.activate(entry)

        // then
        XCTAssertWindowActivateSuccess(result)
        XCTAssertEqual(slept, [0.05, 0.05])
    }

    func test_activate는_frontmost여도_선택창이준비될때까지_polling한다() async {
        // given
        var selectedWindowReadinessCalls = 0
        var focusRequestCount = 0
        var slept: [TimeInterval] = []
        let app = NSRunningApplication.current
        let targetWindow = AXUIElementCreateSystemWide()
        let sut = WindowActivator(
            runningApplicationProvider: { _ in app },
            activateApplication: { _ in true },
            requestWindowFocus: { _ in focusRequestCount += 1 },
            frontmostBundleIDProvider: { "com.example.Target" },
            selectedWindowReadinessProvider: { _ in
                selectedWindowReadinessCalls += 1
                return selectedWindowReadinessCalls >= 3
            },
            sleep: { slept.append($0) },
            maxPollDuration: 1,
            pollInterval: 0.05
        )

        // when
        let result = await sut.activate(makeEntry(axWindow: targetWindow))

        // then
        XCTAssertWindowActivateSuccess(result)
        XCTAssertEqual(selectedWindowReadinessCalls, 3)
        XCTAssertEqual(focusRequestCount, 3)
        XCTAssertEqual(slept, [0.05, 0.05])
    }

    func test_activate는_app활성화후_선택창에_focus를요청한다() async {
        // given
        var events: [String] = []
        let app = NSRunningApplication.current
        let targetWindow = AXUIElementCreateSystemWide()
        let sut = WindowActivator(
            runningApplicationProvider: { _ in app },
            activateApplication: { _ in
                events.append("activate")
                return true
            },
            requestWindowFocus: { _ in events.append("focus") },
            frontmostBundleIDProvider: { "com.example.Target" },
            selectedWindowReadinessProvider: { _ in
                events.append("ready")
                return true
            }
        )

        // when
        let result = await sut.activate(makeEntry(axWindow: targetWindow))

        // then
        XCTAssertWindowActivateSuccess(result)
        XCTAssertEqual(events, ["activate", "focus", "ready"])
    }

    func test_activate는_선택창이준비되지않으면_timeout을_반환한다() async {
        // given
        let app = NSRunningApplication.current
        let targetWindow = AXUIElementCreateSystemWide()
        let sut = WindowActivator(
            runningApplicationProvider: { _ in app },
            activateApplication: { _ in true },
            frontmostBundleIDProvider: { "com.example.Target" },
            selectedWindowReadinessProvider: { _ in false },
            sleep: { _ in },
            maxPollDuration: 0.1,
            pollInterval: 0.05
        )

        // when
        let result = await sut.activate(makeEntry(axWindow: targetWindow))

        // then
        XCTAssertWindowActivateFailure(result, .frontmostTimeout)
    }

    func test_activate는_frontmost_timeout을_반환한다() async {
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
        let result = await sut.activate(entry)

        // then
        XCTAssertWindowActivateFailure(result, .frontmostTimeout)
    }

    func test_activate는_대기중취소되면_cancelled를반환한다() async {
        // given
        let app = NSRunningApplication.current
        let sut = WindowActivator(
            runningApplicationProvider: { _ in app },
            activateApplication: { _ in true },
            frontmostBundleIDProvider: { "com.example.Other" },
            sleep: { _ in await Task.yield() },
            maxPollDuration: 1,
            pollInterval: 0.05
        )

        // when
        let task = Task { @MainActor in
            await sut.activate(self.entry)
        }
        await Task.yield()
        task.cancel()
        let result = await task.value

        // then
        XCTAssertWindowActivateFailure(result, .cancelled)
    }

    func test_activate가_polling을_기다리는동안_mainActor작업이실행된다() async {
        // given
        var didEnterSleep = false
        var didRunHeartbeat = false
        let app = NSRunningApplication.current
        let sut = WindowActivator(
            runningApplicationProvider: { _ in app },
            activateApplication: { _ in true },
            frontmostBundleIDProvider: { "com.example.Other" },
            sleep: { _ in
                didEnterSleep = true
                await Task.yield()
            },
            maxPollDuration: 1,
            pollInterval: 0.05
        )

        // when
        let activation = Task { @MainActor in
            await sut.activate(self.entry)
        }
        while !didEnterSleep {
            await Task.yield()
        }
        Task { @MainActor in
            didRunHeartbeat = true
        }
        await Task.yield()
        activation.cancel()
        _ = await activation.value

        // then
        XCTAssertTrue(didRunHeartbeat)
    }

    func test_isSameWindow는_AX객체가달라도_identifier가같으면_true다() {
        // given
        let frame = CGRect(x: 10, y: 20, width: 800, height: 600)
        let selectedWindow = AXWindowReference(
            element: AXUIElementCreateApplication(100),
            fingerprint: AXWindowFingerprint(
                identifier: "main-window",
                title: "Document",
                frame: frame
            )
        )
        let activeWindow = AXWindowReference(
            element: AXUIElementCreateApplication(200),
            fingerprint: AXWindowFingerprint(
                identifier: "main-window",
                title: "Document",
                frame: frame
            )
        )

        // when
        let result = WindowActivator.isSameWindow(selectedWindow, as: activeWindow)

        // then
        XCTAssertTrue(result)
    }

    func test_isSameWindow는_identifier가다르면_frame이같아도_false다() {
        // given
        let frame = CGRect(x: 10, y: 20, width: 800, height: 600)
        let selectedWindow = AXWindowReference(
            element: AXUIElementCreateApplication(100),
            fingerprint: AXWindowFingerprint(
                identifier: "first",
                title: "Document",
                frame: frame
            )
        )
        let activeWindow = AXWindowReference(
            element: AXUIElementCreateApplication(200),
            fingerprint: AXWindowFingerprint(
                identifier: "second",
                title: "Document",
                frame: frame
            )
        )

        // when
        let result = WindowActivator.isSameWindow(selectedWindow, as: activeWindow)

        // then
        XCTAssertFalse(result)
    }

    func test_isSameWindow는_identifier가같아도_title이나frame이다르면_false다() {
        // given
        let selectedWindow = AXWindowReference(
            element: AXUIElementCreateApplication(100),
            fingerprint: AXWindowFingerprint(
                identifier: "main-window",
                title: "First",
                frame: CGRect(x: 10, y: 20, width: 800, height: 600)
            )
        )
        let activeWindow = AXWindowReference(
            element: AXUIElementCreateApplication(200),
            fingerprint: AXWindowFingerprint(
                identifier: "main-window",
                title: "Second",
                frame: CGRect(x: 100, y: 200, width: 800, height: 600)
            )
        )

        // when
        let result = WindowActivator.isSameWindow(selectedWindow, as: activeWindow)

        // then
        XCTAssertFalse(result)
    }

    func test_isSameWindow는_identifier가없으면_title과frame이같아도_false다() {
        // given
        let selectedWindow = AXWindowReference(
            element: AXUIElementCreateApplication(100),
            fingerprint: AXWindowFingerprint(
                identifier: nil,
                title: "Document",
                frame: CGRect(x: 10, y: 20, width: 800, height: 600)
            )
        )
        let activeWindow = AXWindowReference(
            element: AXUIElementCreateApplication(200),
            fingerprint: AXWindowFingerprint(
                identifier: nil,
                title: "Document",
                frame: CGRect(x: 10.5, y: 19.5, width: 800, height: 600)
            )
        )

        // when
        let result = WindowActivator.isSameWindow(selectedWindow, as: activeWindow)

        // then
        XCTAssertFalse(result)
    }

    func test_isSameWindow는_title이없으면_frame이같아도_false다() {
        // given
        let frame = CGRect(x: 10, y: 20, width: 800, height: 600)
        let selectedWindow = AXWindowReference(
            element: AXUIElementCreateApplication(100),
            fingerprint: AXWindowFingerprint(identifier: nil, title: nil, frame: frame)
        )
        let activeWindow = AXWindowReference(
            element: AXUIElementCreateApplication(200),
            fingerprint: AXWindowFingerprint(identifier: nil, title: nil, frame: frame)
        )

        // when
        let result = WindowActivator.isSameWindow(selectedWindow, as: activeWindow)

        // then
        XCTAssertFalse(result)
    }

    func test_isSameWindow는_fingerprint가다르고_AX객체도다르면_false다() {
        // given
        let selectedWindow = AXWindowReference(
            element: AXUIElementCreateApplication(100),
            fingerprint: AXWindowFingerprint(
                identifier: nil,
                title: "First",
                frame: CGRect(x: 10, y: 20, width: 800, height: 600)
            )
        )
        let activeWindow = AXWindowReference(
            element: AXUIElementCreateApplication(200),
            fingerprint: AXWindowFingerprint(
                identifier: nil,
                title: "Second",
                frame: CGRect(x: 100, y: 200, width: 800, height: 600)
            )
        )

        // when
        let result = WindowActivator.isSameWindow(selectedWindow, as: activeWindow)

        // then
        XCTAssertFalse(result)
    }

    func test_isSameWindow는_fingerprint가없어도_같은AX객체면_true다() {
        // given
        let element = AXUIElementCreateSystemWide()
        let selectedWindow = AXWindowReference(element: element)
        let activeWindow = AXWindowReference(element: element)

        // when
        let result = WindowActivator.isSameWindow(selectedWindow, as: activeWindow)

        // then
        XCTAssertTrue(result)
    }

    func test_isSameWindow는_activeWindow가없으면_false다() {
        // given
        let selectedWindow = AXWindowReference(
            element: AXUIElementCreateSystemWide()
        )

        // when
        let result = WindowActivator.isSameWindow(selectedWindow, as: nil)

        // then
        XCTAssertFalse(result)
    }

    private var entry: WindowEntry {
        makeEntry(axWindow: nil)
    }

    private func makeEntry(axWindow: AXUIElement?) -> WindowEntry {
        WindowEntry(
            id: 0,
            appName: "Target",
            bundleID: "com.example.Target",
            windowTitle: "Main",
            windowTitleHash: "hash",
            pid: 100,
            axWindow: axWindow,
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
