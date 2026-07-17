import Darwin
import Foundation
import XCTest
@testable import GazeRow

/// FileProcessInstanceLock와 SingleInstanceCoordinator 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-16
final class FileProcessInstanceLockTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
    }

    func test_acquire는_첫번째_lock에_소유권을부여하고_두번째에_ownerPID를반환한다() {
        // given
        let lockFileURL = temporaryDirectory.appendingPathComponent("instance.lock")
        let first = FileProcessInstanceLock(
            lockFileURL: lockFileURL,
            processIdentifier: 101
        )
        let second = FileProcessInstanceLock(
            lockFileURL: lockFileURL,
            processIdentifier: 202
        )

        // when
        let firstResult = first.acquire()
        let secondResult = second.acquire()

        // then
        XCTAssertEqual(firstResult, .acquired)
        XCTAssertEqual(secondResult, .alreadyLocked(ownerProcessIdentifier: 101))
    }

    func test_release후_다른lock이_소유권을획득한다() {
        // given
        let lockFileURL = temporaryDirectory.appendingPathComponent("instance.lock")
        let first = FileProcessInstanceLock(
            lockFileURL: lockFileURL,
            processIdentifier: 101
        )
        let second = FileProcessInstanceLock(
            lockFileURL: lockFileURL,
            processIdentifier: 202
        )
        XCTAssertEqual(first.acquire(), .acquired)

        // when
        first.release()
        let result = second.acquire()

        // then
        XCTAssertEqual(result, .acquired)
    }

    func test_acquire는_남아있는lockFile에_실제lock이없으면_소유권을획득한다() throws {
        // given
        let lockFileURL = temporaryDirectory.appendingPathComponent("instance.lock")
        try Data("99999\n".utf8).write(to: lockFileURL)
        let sut = FileProcessInstanceLock(
            lockFileURL: lockFileURL,
            processIdentifier: 303
        )

        // when
        let result = sut.acquire()

        // then
        XCTAssertEqual(result, .acquired)
        XCTAssertEqual(try String(contentsOf: lockFileURL, encoding: .utf8), "303\n")
    }

    func test_acquire는_lockDirectory를생성할수없으면_unavailable을반환한다() throws {
        // given
        let blockedDirectory = temporaryDirectory.appendingPathComponent("blocked")
        try Data("file".utf8).write(to: blockedDirectory)
        let sut = FileProcessInstanceLock(
            lockFileURL: blockedDirectory.appendingPathComponent("instance.lock")
        )

        // when
        let result = sut.acquire()

        // then
        guard case .unavailable = result else {
            return XCTFail("Expected unavailable, got \(result)")
        }
    }
}

/// SingleInstanceCoordinator 정책 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-16
@MainActor
final class SingleInstanceCoordinatorTests: XCTestCase {

    func test_start는_lock획득시_primary로관찰을시작한다() {
        // given
        let processLock = FakeProcessInstanceLock(acquisition: .acquired)
        let messenger = FakeSingleInstanceActivationMessenger()
        let sut = SingleInstanceCoordinator(
            processLock: processLock,
            activationMessenger: messenger
        )
        var activationRequestCount = 0

        // when
        let result = sut.start {
            activationRequestCount += 1
        }
        messenger.sendActivationRequestToObserver()

        // then
        XCTAssertEqual(result, .primary)
        XCTAssertEqual(processLock.acquireCallCount, 1)
        XCTAssertEqual(messenger.startObservingCallCount, 1)
        XCTAssertEqual(activationRequestCount, 1)
    }

    func test_start는_이미시작한_primary에서_lock과관찰을중복시작하지않는다() {
        // given
        let processLock = FakeProcessInstanceLock(acquisition: .acquired)
        let messenger = FakeSingleInstanceActivationMessenger()
        let sut = SingleInstanceCoordinator(
            processLock: processLock,
            activationMessenger: messenger
        )
        XCTAssertEqual(sut.start {}, .primary)

        // when
        let result = sut.start {}

        // then
        XCTAssertEqual(result, .primary)
        XCTAssertEqual(processLock.acquireCallCount, 1)
        XCTAssertEqual(messenger.startObservingCallCount, 1)
    }

    func test_start는_lock중복시_기존인스턴스에요청하고_owner를활성화한다() {
        // given
        let processLock = FakeProcessInstanceLock(
            acquisition: .alreadyLocked(ownerProcessIdentifier: 1234)
        )
        let messenger = FakeSingleInstanceActivationMessenger()
        var activatedProcessIdentifiers: [pid_t] = []
        let sut = SingleInstanceCoordinator(
            processLock: processLock,
            activationMessenger: messenger,
            activateRunningApplication: { processIdentifier in
                activatedProcessIdentifiers.append(processIdentifier)
                return true
            }
        )

        // when
        let result = sut.start {}

        // then
        XCTAssertEqual(result, .duplicate(ownerProcessIdentifier: 1234))
        XCTAssertEqual(messenger.requestActivationCallCount, 1)
        XCTAssertEqual(activatedProcessIdentifiers, [1234])
        XCTAssertEqual(messenger.startObservingCallCount, 0)
    }

    func test_start는_ownerPID가없어도_기존인스턴스에요청하고종료판정한다() {
        // given
        let processLock = FakeProcessInstanceLock(
            acquisition: .alreadyLocked(ownerProcessIdentifier: nil)
        )
        let messenger = FakeSingleInstanceActivationMessenger()
        var activateCallCount = 0
        let sut = SingleInstanceCoordinator(
            processLock: processLock,
            activationMessenger: messenger,
            activateRunningApplication: { _ in
                activateCallCount += 1
                return true
            }
        )

        // when
        let result = sut.start {}

        // then
        XCTAssertEqual(result, .duplicate(ownerProcessIdentifier: nil))
        XCTAssertEqual(messenger.requestActivationCallCount, 1)
        XCTAssertEqual(activateCallCount, 0)
    }

    func test_start는_lock사용불가시_입력등록을허용하지않는다() {
        // given
        let processLock = FakeProcessInstanceLock(acquisition: .unavailable(errorCode: 13))
        let messenger = FakeSingleInstanceActivationMessenger()
        let sut = SingleInstanceCoordinator(
            processLock: processLock,
            activationMessenger: messenger
        )

        // when
        let result = sut.start {}

        // then
        XCTAssertEqual(result, .unavailable(errorCode: 13))
        XCTAssertEqual(messenger.startObservingCallCount, 0)
        XCTAssertEqual(messenger.requestActivationCallCount, 0)
    }

    func test_stop은_primary의관찰과lock을해제한다() {
        // given
        let processLock = FakeProcessInstanceLock(acquisition: .acquired)
        let messenger = FakeSingleInstanceActivationMessenger()
        let sut = SingleInstanceCoordinator(
            processLock: processLock,
            activationMessenger: messenger
        )
        XCTAssertEqual(sut.start {}, .primary)

        // when
        sut.stop()
        sut.stop()

        // then
        XCTAssertEqual(messenger.stopObservingCallCount, 1)
        XCTAssertEqual(processLock.releaseCallCount, 1)
    }
}

private final class FakeProcessInstanceLock: ProcessInstanceLocking {
    let acquisition: ProcessInstanceLockAcquisition
    private(set) var acquireCallCount = 0
    private(set) var releaseCallCount = 0

    init(acquisition: ProcessInstanceLockAcquisition) {
        self.acquisition = acquisition
    }

    func acquire() -> ProcessInstanceLockAcquisition {
        acquireCallCount += 1
        return acquisition
    }

    func release() {
        releaseCallCount += 1
    }
}

@MainActor
private final class FakeSingleInstanceActivationMessenger: SingleInstanceActivationMessaging {
    private var handler: (@MainActor @Sendable () -> Void)?
    private(set) var startObservingCallCount = 0
    private(set) var requestActivationCallCount = 0
    private(set) var stopObservingCallCount = 0

    func startObserving(_ handler: @MainActor @escaping @Sendable () -> Void) {
        startObservingCallCount += 1
        self.handler = handler
    }

    func requestActivation() {
        requestActivationCallCount += 1
    }

    func stopObserving() {
        stopObservingCallCount += 1
        handler = nil
    }

    func sendActivationRequestToObserver() {
        handler?()
    }
}
