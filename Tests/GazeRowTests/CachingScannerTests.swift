import CoreGraphics
import Foundation
import XCTest
@testable import GazeRow

/// CachingScanner 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-07
@MainActor
final class CachingScannerTests: XCTestCase {

    func test_scan_최초요청은_wrapped를_호출하고_결과를_반환() {
        // given
        let scanResult = makeScanResult(candidateCount: 1)
        let spy = SpyScanner(results: [.success(scanResult)])
        let sut = CachingScanner(wrapped: spy, timeToLive: 0.5, dateProvider: { Date(timeIntervalSince1970: 1_000) })

        // when
        let result = sut.scan(context: makeContext())

        // then
        XCTAssertEqual(result, .success(scanResult))
        XCTAssertEqual(spy.scanCallCount, 1)
    }

    func test_scan_TTL이내_동일context는_cache를_반환하고_재스캔하지_않음() {
        // given
        let firstResult = makeScanResult(candidateCount: 1)
        let secondResult = makeScanResult(candidateCount: 5)
        let spy = SpyScanner(results: [.success(firstResult), .success(secondResult)])
        var now = Date(timeIntervalSince1970: 1_000)
        let sut = CachingScanner(wrapped: spy, timeToLive: 0.5, dateProvider: { now })
        let context = makeContext()

        // when
        _ = sut.scan(context: context)
        now = now.addingTimeInterval(0.4)
        let cached = sut.scan(context: context)

        // then
        XCTAssertEqual(cached, .success(firstResult))
        XCTAssertEqual(spy.scanCallCount, 1)
    }

    func test_scan_TTL경계에서는_cache_hit() {
        // given
        let firstResult = makeScanResult(candidateCount: 1)
        let spy = SpyScanner(results: [.success(firstResult), .success(makeScanResult(candidateCount: 9))])
        var now = Date(timeIntervalSince1970: 1_000)
        let sut = CachingScanner(wrapped: spy, timeToLive: 0.5, dateProvider: { now })
        let context = makeContext()

        // when
        _ = sut.scan(context: context)
        now = now.addingTimeInterval(0.5)
        let cached = sut.scan(context: context)

        // then
        XCTAssertEqual(cached, .success(firstResult))
        XCTAssertEqual(spy.scanCallCount, 1)
    }

    func test_scan_TTL초과면_재스캔() {
        // given
        let firstResult = makeScanResult(candidateCount: 1)
        let secondResult = makeScanResult(candidateCount: 3)
        let spy = SpyScanner(results: [.success(firstResult), .success(secondResult)])
        var now = Date(timeIntervalSince1970: 1_000)
        let sut = CachingScanner(wrapped: spy, timeToLive: 0.5, dateProvider: { now })
        let context = makeContext()

        // when
        _ = sut.scan(context: context)
        now = now.addingTimeInterval(0.51)
        let rescanned = sut.scan(context: context)

        // then
        XCTAssertEqual(rescanned, .success(secondResult))
        XCTAssertEqual(spy.scanCallCount, 2)
    }

    func test_scan_window_frame이_다르면_재스캔() {
        // given
        let firstResult = makeScanResult(candidateCount: 1)
        let secondResult = makeScanResult(candidateCount: 2)
        let spy = SpyScanner(results: [.success(firstResult), .success(secondResult)])
        let sut = CachingScanner(wrapped: spy, timeToLive: 0.5, dateProvider: { Date(timeIntervalSince1970: 1_000) })

        // when
        _ = sut.scan(context: makeContext(frame: CGRect(x: 0, y: 0, width: 500, height: 320)))
        let resized = sut.scan(context: makeContext(frame: CGRect(x: 0, y: 0, width: 640, height: 480)))

        // then
        XCTAssertEqual(resized, .success(secondResult))
        XCTAssertEqual(spy.scanCallCount, 2)
    }

    func test_scan_window_title이_다르면_재스캔() {
        // given
        let firstResult = makeScanResult(candidateCount: 1)
        let secondResult = makeScanResult(candidateCount: 2)
        let spy = SpyScanner(results: [.success(firstResult), .success(secondResult)])
        let sut = CachingScanner(wrapped: spy, timeToLive: 0.5, dateProvider: { Date(timeIntervalSince1970: 1_000) })

        // when
        _ = sut.scan(context: makeContext(title: "Documents"))
        let renamed = sut.scan(context: makeContext(title: "Downloads"))

        // then
        XCTAssertEqual(renamed, .success(secondResult))
        XCTAssertEqual(spy.scanCallCount, 2)
    }

    func test_scan_processIdentifier가_다르면_재스캔() {
        // given
        let firstResult = makeScanResult(candidateCount: 1)
        let secondResult = makeScanResult(candidateCount: 2)
        let spy = SpyScanner(results: [.success(firstResult), .success(secondResult)])
        let sut = CachingScanner(wrapped: spy, timeToLive: 0.5, dateProvider: { Date(timeIntervalSince1970: 1_000) })

        // when
        _ = sut.scan(context: makeContext(processIdentifier: 100))
        let otherApp = sut.scan(context: makeContext(processIdentifier: 200))

        // then
        XCTAssertEqual(otherApp, .success(secondResult))
        XCTAssertEqual(spy.scanCallCount, 2)
    }

    func test_scan_실패는_cache하지_않고_다음요청에서_재시도() {
        // given
        let recovered = makeScanResult(candidateCount: 1)
        let spy = SpyScanner(
            results: [
                .failure(.focusedWindowUnavailable("temporary")),
                .success(recovered)
            ]
        )
        let sut = CachingScanner(wrapped: spy, timeToLive: 0.5, dateProvider: { Date(timeIntervalSince1970: 1_000) })
        let context = makeContext()

        // when
        let failure = sut.scan(context: context)
        let retry = sut.scan(context: context)

        // then
        XCTAssertEqual(failure, .failure(.focusedWindowUnavailable("temporary")))
        XCTAssertEqual(retry, .success(recovered))
        XCTAssertEqual(spy.scanCallCount, 2)
    }

    func test_invalidate_후에는_TTL이내라도_재스캔() {
        // given
        let firstResult = makeScanResult(candidateCount: 1)
        let secondResult = makeScanResult(candidateCount: 2)
        let spy = SpyScanner(results: [.success(firstResult), .success(secondResult)])
        let sut = CachingScanner(wrapped: spy, timeToLive: 0.5, dateProvider: { Date(timeIntervalSince1970: 1_000) })
        let context = makeContext()

        // when
        _ = sut.scan(context: context)
        sut.invalidate()
        let rescanned = sut.scan(context: context)

        // then
        XCTAssertEqual(rescanned, .success(secondResult))
        XCTAssertEqual(spy.scanCallCount, 2)
    }

    func test_scan_observer활성화시_연장TTL동안_cache를_재사용한다() {
        // given
        let firstResult = makeScanResult(candidateCount: 1)
        let spy = SpyScanner(results: [.success(firstResult), .success(makeScanResult(candidateCount: 2))])
        let monitor = SpyAccessibilityChangeMonitor(startResult: true)
        var now = Date(timeIntervalSince1970: 1_000)
        let sut = CachingScanner(
            wrapped: spy,
            timeToLive: 0.5,
            monitoredTimeToLive: 3,
            changeMonitor: monitor,
            dateProvider: { now }
        )
        let context = makeContext()

        // when
        _ = sut.scan(context: context)
        now = now.addingTimeInterval(2)
        let cached = sut.scan(context: context)

        // then
        XCTAssertEqual(cached, .success(firstResult))
        XCTAssertEqual(spy.scanCallCount, 1)
        XCTAssertEqual(monitor.startedProcessIdentifiers, [100])
    }

    func test_scan_observer변경이벤트후에는_연장TTL이내라도_재스캔한다() {
        // given
        let firstResult = makeScanResult(candidateCount: 1)
        let secondResult = makeScanResult(candidateCount: 2)
        let spy = SpyScanner(results: [.success(firstResult), .success(secondResult)])
        let monitor = SpyAccessibilityChangeMonitor(startResult: true)
        var now = Date(timeIntervalSince1970: 1_000)
        let sut = CachingScanner(
            wrapped: spy,
            timeToLive: 0.5,
            monitoredTimeToLive: 3,
            changeMonitor: monitor,
            dateProvider: { now }
        )
        let context = makeContext()

        // when
        _ = sut.scan(context: context)
        now = now.addingTimeInterval(1)
        monitor.sendChange()
        let rescanned = sut.scan(context: context)

        // then
        XCTAssertEqual(rescanned, .success(secondResult))
        XCTAssertEqual(spy.scanCallCount, 2)
        XCTAssertEqual(monitor.startedProcessIdentifiers, [100, 100])
    }

    func test_scan_observer시작실패시_기본TTL을_유지한다() {
        // given
        let firstResult = makeScanResult(candidateCount: 1)
        let secondResult = makeScanResult(candidateCount: 2)
        let spy = SpyScanner(results: [.success(firstResult), .success(secondResult)])
        let monitor = SpyAccessibilityChangeMonitor(startResult: false)
        var now = Date(timeIntervalSince1970: 1_000)
        let sut = CachingScanner(
            wrapped: spy,
            timeToLive: 0.5,
            monitoredTimeToLive: 3,
            changeMonitor: monitor,
            dateProvider: { now }
        )
        let context = makeContext()

        // when
        _ = sut.scan(context: context)
        now = now.addingTimeInterval(0.6)
        let rescanned = sut.scan(context: context)

        // then
        XCTAssertEqual(rescanned, .success(secondResult))
        XCTAssertEqual(spy.scanCallCount, 2)
    }

    func test_scan_process가_바뀌면_observer를_새process로_재시작한다() {
        // given
        let spy = SpyScanner(
            results: [
                .success(makeScanResult(candidateCount: 1)),
                .success(makeScanResult(candidateCount: 2))
            ]
        )
        let monitor = SpyAccessibilityChangeMonitor(startResult: true)
        let sut = CachingScanner(
            wrapped: spy,
            changeMonitor: monitor,
            dateProvider: { Date(timeIntervalSince1970: 1_000) }
        )

        // when
        _ = sut.scan(context: makeContext(processIdentifier: 100))
        _ = sut.scan(context: makeContext(processIdentifier: 200))

        // then
        XCTAssertEqual(monitor.startedProcessIdentifiers, [100, 200])
        XCTAssertEqual(spy.scanCallCount, 2)
    }

    private func makeContext(
        processIdentifier: pid_t = 100,
        frame: CGRect = CGRect(x: 100, y: 100, width: 500, height: 320),
        title: String? = "Finder"
    ) -> TargetContext {
        TargetContext(
            application: TargetApplication(
                localizedName: "Finder",
                bundleIdentifier: "com.apple.finder",
                processIdentifier: processIdentifier
            ),
            window: TargetWindow(frame: frame, title: title),
            resolvedAt: Date(timeIntervalSince1970: 1_788_748_400)
        )
    }

    private func makeScanResult(candidateCount: Int) -> AccessibilityScanResult {
        let candidates = (0..<candidateCount).map { index in
            ClickableCandidate(
                role: AccessibilityRole.button,
                subrole: nil,
                title: "Open \(index)",
                frame: CGRect(x: 120 + index * 40, y: 140, width: 40, height: 20),
                actions: [AccessibilityAction.press]
            )
        }
        return AccessibilityScanResult(
            candidates: candidates,
            nodesVisited: candidateCount + 1,
            scanDuration: 0.01,
            didHitDepthLimit: false,
            didHitNodeLimit: false,
            didTimeout: false,
            failedChildReadCount: 0
        )
    }
}

@MainActor
private final class SpyScanner: OverlaySessionScanning {
    private let results: [Result<AccessibilityScanResult, AccessibilityScanFailure>]
    private(set) var receivedContexts: [TargetContext] = []

    var scanCallCount: Int {
        receivedContexts.count
    }

    init(results: [Result<AccessibilityScanResult, AccessibilityScanFailure>]) {
        self.results = results
    }

    func scan(context: TargetContext) -> Result<AccessibilityScanResult, AccessibilityScanFailure> {
        receivedContexts.append(context)
        let index = min(receivedContexts.count - 1, results.count - 1)
        return results[index]
    }
}

@MainActor
private final class SpyAccessibilityChangeMonitor: AccessibilityChangeMonitoring {
    private let startResult: Bool
    private var onChange: (@MainActor () -> Void)?
    private(set) var startedProcessIdentifiers: [pid_t] = []
    private(set) var stopCallCount = 0

    init(startResult: Bool) {
        self.startResult = startResult
    }

    func start(
        processIdentifier: pid_t,
        onChange: @escaping @MainActor () -> Void
    ) -> Bool {
        startedProcessIdentifiers.append(processIdentifier)
        self.onChange = startResult ? onChange : nil
        return startResult
    }

    func stop() {
        stopCallCount += 1
        onChange = nil
    }

    func sendChange() {
        let callback = onChange
        onChange = nil
        callback?()
    }
}
