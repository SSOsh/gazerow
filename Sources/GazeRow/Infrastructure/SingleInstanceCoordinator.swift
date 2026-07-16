import AppKit
import Darwin
import Foundation

/// 프로세스 잠금 획득 결과.
///
/// @author suho.do
/// @since 2026-07-16
enum ProcessInstanceLockAcquisition: Equatable {
    case acquired
    case alreadyLocked(ownerProcessIdentifier: pid_t?)
    case unavailable(errorCode: Int32)
}

/// 단일 인스턴스 process lock abstraction.
///
/// @author suho.do
/// @since 2026-07-16
protocol ProcessInstanceLocking: AnyObject {
    func acquire() -> ProcessInstanceLockAcquisition
    func release()
}

/// BSD exclusive file lock 기반 사용자 세션 process lock.
///
/// lock file은 번들 위치와 무관한 Application Support 경로를 사용하므로 설치본과
/// 로컬 빌드도 같은 lock을 공유한다. file descriptor를 프로세스 수명 동안 유지하며,
/// 비정상 종료 시에도 커널이 lock을 자동으로 해제한다.
///
/// @author suho.do
/// @since 2026-07-16
final class FileProcessInstanceLock: ProcessInstanceLocking {
    private let lockFileURL: URL
    private let processIdentifier: pid_t
    private let fileManager: FileManager
    private var fileDescriptor: Int32?

    init(
        lockFileURL: URL = FileProcessInstanceLock.defaultLockFileURL(),
        processIdentifier: pid_t = getpid(),
        fileManager: FileManager = .default
    ) {
        self.lockFileURL = lockFileURL
        self.processIdentifier = processIdentifier
        self.fileManager = fileManager
    }

    deinit {
        release()
    }

    func acquire() -> ProcessInstanceLockAcquisition {
        if fileDescriptor != nil {
            return .acquired
        }

        do {
            try fileManager.createDirectory(
                at: lockFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            return .unavailable(errorCode: Int32(clamping: (error as NSError).code))
        }

        let descriptor = Darwin.open(
            lockFileURL.path,
            O_CREAT | O_RDWR | O_EXLOCK | O_NONBLOCK,
            S_IRUSR | S_IWUSR
        )
        guard descriptor >= 0 else {
            let lockError = errno
            if lockError == EWOULDBLOCK || lockError == EAGAIN {
                return .alreadyLocked(
                    ownerProcessIdentifier: readOwnerProcessIdentifierFromLockedFile()
                )
            }
            return .unavailable(errorCode: lockError)
        }

        guard writeOwnerProcessIdentifier(to: descriptor) else {
            let writeError = errno
            Darwin.close(descriptor)
            return .unavailable(errorCode: writeError)
        }

        fileDescriptor = descriptor
        return .acquired
    }

    func release() {
        guard let fileDescriptor else {
            return
        }

        Darwin.close(fileDescriptor)
        self.fileDescriptor = nil
    }

    static func defaultLockFileURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return applicationSupport
            .appendingPathComponent("GazeRow", isDirectory: true)
            .appendingPathComponent("instance.lock", isDirectory: false)
    }

    private func writeOwnerProcessIdentifier(to descriptor: Int32) -> Bool {
        guard Darwin.ftruncate(descriptor, 0) == 0,
              Darwin.lseek(descriptor, 0, SEEK_SET) >= 0 else {
            return false
        }

        let data = Data("\(processIdentifier)\n".utf8)
        return data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return false
            }

            var writtenByteCount = 0
            while writtenByteCount < bytes.count {
                let result = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: writtenByteCount),
                    bytes.count - writtenByteCount
                )
                guard result > 0 else {
                    return false
                }
                writtenByteCount += result
            }
            return true
        }
    }

    private func readOwnerProcessIdentifier(from descriptor: Int32) -> pid_t? {
        guard Darwin.lseek(descriptor, 0, SEEK_SET) >= 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: 64)
        let readByteCount = buffer.withUnsafeMutableBytes { bytes in
            Darwin.read(descriptor, bytes.baseAddress, bytes.count)
        }
        guard readByteCount > 0 else {
            return nil
        }

        let value = String(decoding: buffer.prefix(readByteCount), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return pid_t(value)
    }

    private func readOwnerProcessIdentifierFromLockedFile() -> pid_t? {
        let descriptor = Darwin.open(lockFileURL.path, O_RDONLY)
        guard descriptor >= 0 else {
            return nil
        }
        defer { Darwin.close(descriptor) }
        return readOwnerProcessIdentifier(from: descriptor)
    }
}

/// 기존 인스턴스 활성화 요청 전달 abstraction.
///
/// @author suho.do
/// @since 2026-07-16
@MainActor
protocol SingleInstanceActivationMessaging: AnyObject {
    func startObserving(_ handler: @MainActor @escaping @Sendable () -> Void)
    func requestActivation()
    func stopObserving()
}

/// 사용자 세션 내 distributed notification 기반 활성화 요청 전달기.
///
/// @author suho.do
/// @since 2026-07-16
@MainActor
final class DistributedSingleInstanceActivationMessenger: SingleInstanceActivationMessaging {
    static let activationNotification = Notification.Name(
        "io.github.ssosh.gazerow.single-instance.activate"
    )

    private let center: DistributedNotificationCenter
    private var observer: (any NSObjectProtocol)?

    init(center: DistributedNotificationCenter = .default()) {
        self.center = center
    }

    func startObserving(_ handler: @MainActor @escaping @Sendable () -> Void) {
        stopObserving()
        observer = center.addObserver(
            forName: Self.activationNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                handler()
            }
        }
    }

    func requestActivation() {
        center.postNotificationName(
            Self.activationNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    func stopObserving() {
        guard let observer else {
            return
        }

        center.removeObserver(observer)
        self.observer = nil
    }
}

/// 앱 시작 시 단일 인스턴스 정책 판정 결과.
///
/// @author suho.do
/// @since 2026-07-16
enum SingleInstanceLaunchDecision: Equatable {
    case primary
    case duplicate(ownerProcessIdentifier: pid_t?)
    case unavailable(errorCode: Int32)
}

/// process lock과 기존 인스턴스 활성화 요청을 조합한다.
///
/// @author suho.do
/// @since 2026-07-16
@MainActor
final class SingleInstanceCoordinator {
    private let processLock: any ProcessInstanceLocking
    private let activationMessenger: any SingleInstanceActivationMessaging
    private let activateRunningApplication: @MainActor (pid_t) -> Bool
    private var ownsLock = false

    init(
        processLock: any ProcessInstanceLocking = FileProcessInstanceLock(),
        activationMessenger: (any SingleInstanceActivationMessaging)? = nil,
        activateRunningApplication: @MainActor @escaping (pid_t) -> Bool = { processIdentifier in
            NSRunningApplication(processIdentifier: processIdentifier)?
                .activate(options: []) ?? false
        }
    ) {
        self.processLock = processLock
        self.activationMessenger = activationMessenger ?? DistributedSingleInstanceActivationMessenger()
        self.activateRunningApplication = activateRunningApplication
    }

    func start(
        onActivationRequest: @MainActor @escaping @Sendable () -> Void
    ) -> SingleInstanceLaunchDecision {
        if ownsLock {
            return .primary
        }

        switch processLock.acquire() {
        case .acquired:
            ownsLock = true
            activationMessenger.startObserving(onActivationRequest)
            return .primary
        case .alreadyLocked(let ownerProcessIdentifier):
            activationMessenger.requestActivation()
            if let ownerProcessIdentifier {
                _ = activateRunningApplication(ownerProcessIdentifier)
            }
            return .duplicate(ownerProcessIdentifier: ownerProcessIdentifier)
        case .unavailable(let errorCode):
            return .unavailable(errorCode: errorCode)
        }
    }

    func stop() {
        guard ownsLock else {
            return
        }

        activationMessenger.stopObserving()
        processLock.release()
        ownsLock = false
    }
}
