import Foundation

/// overlay activation의 단계별 지연을 기록하는 값.
///
/// @author suho.do
/// @since 2026-07-13
enum OverlayActivationPhase: String, Equatable {
    case shortcutReceived
    case targetResolved
    case scanCompleted
    case layoutCompleted
    case sessionReady
    case captureReady
    case panelsOrdered
    case firstDisplayPass
    case keyCaptured
    case commandHandled
    case focusStateChanged
}

/// activation trace에 기록할 비식별 성능 메타데이터.
///
/// @author suho.do
/// @since 2026-07-13
struct OverlayActivationTraceMetadata: Equatable {
    let nodesVisited: Int?
    let candidateCount: Int?
    let commandKind: String?
    let captureMode: String?
    let hasActiveSession: Bool?
    let didTimeout: Bool?
    let didHitNodeLimit: Bool?
    let didHitDepthLimit: Bool?
    let failedChildReadCount: Int?

    init(
        nodesVisited: Int? = nil,
        candidateCount: Int? = nil,
        commandKind: String? = nil,
        captureMode: String? = nil,
        hasActiveSession: Bool? = nil,
        didTimeout: Bool? = nil,
        didHitNodeLimit: Bool? = nil,
        didHitDepthLimit: Bool? = nil,
        failedChildReadCount: Int? = nil
    ) {
        self.nodesVisited = nodesVisited
        self.candidateCount = candidateCount
        self.commandKind = commandKind
        self.captureMode = captureMode
        self.hasActiveSession = hasActiveSession
        self.didTimeout = didTimeout
        self.didHitNodeLimit = didHitNodeLimit
        self.didHitDepthLimit = didHitDepthLimit
        self.failedChildReadCount = failedChildReadCount
    }
}

/// overlay activation의 한 단계에서 수집한 비식별 timing event.
///
/// @author suho.do
/// @since 2026-07-17
struct OverlayActivationTraceEvent: Equatable {
    let activationID: UUID
    let phase: OverlayActivationPhase
    let elapsedMilliseconds: Int
    let metadata: OverlayActivationTraceMetadata
}

/// overlay activation timing 기록 추상화.
///
/// @author suho.do
/// @since 2026-07-13
@MainActor
protocol OverlayActivationTracing {
    func begin(at date: Date) -> UUID

    func end(activationID: UUID)

    func mark(
        _ phase: OverlayActivationPhase,
        activationID: UUID,
        at date: Date,
        metadata: OverlayActivationTraceMetadata
    )
}

/// OSLog로 overlay activation timing을 기록한다.
///
/// @author suho.do
/// @since 2026-07-13
@MainActor
final class OverlayActivationTracer: OverlayActivationTracing {
    private var startedAtByID: [UUID: Date] = [:]
    private let onEvent: @MainActor (OverlayActivationTraceEvent) -> Void

    init(
        onEvent: @escaping @MainActor (OverlayActivationTraceEvent) -> Void = OverlayActivationTracer.recordToOSLog
    ) {
        self.onEvent = onEvent
    }

    func begin(at date: Date) -> UUID {
        let activationID = UUID()
        startedAtByID[activationID] = date
        return activationID
    }

    func end(activationID: UUID) {
        startedAtByID.removeValue(forKey: activationID)
    }

    func mark(
        _ phase: OverlayActivationPhase,
        activationID: UUID,
        at date: Date,
        metadata: OverlayActivationTraceMetadata
    ) {
        onEvent(
            OverlayActivationTraceEvent(
                activationID: activationID,
                phase: phase,
                elapsedMilliseconds: elapsedMilliseconds(for: activationID, at: date),
                metadata: metadata
            )
        )
    }

    private func elapsedMilliseconds(for activationID: UUID, at date: Date) -> Int {
        guard let startedAt = startedAtByID[activationID] else {
            return 0
        }

        return max(0, Int((date.timeIntervalSince(startedAt) * 1_000).rounded()))
    }

    private static func recordToOSLog(_ event: OverlayActivationTraceEvent) {
        let nodes = event.metadata.nodesVisited.map(String.init) ?? "-"
        let candidates = event.metadata.candidateCount.map(String.init) ?? "-"
        let command = event.metadata.commandKind ?? "-"
        let capture = event.metadata.captureMode ?? "-"
        let hasSession = event.metadata.hasActiveSession.map(String.init) ?? "-"
        let timeout = event.metadata.didTimeout.map(String.init) ?? "-"
        let nodeLimit = event.metadata.didHitNodeLimit.map(String.init) ?? "-"
        let depthLimit = event.metadata.didHitDepthLimit.map(String.init) ?? "-"
        let failedChildReads = event.metadata.failedChildReadCount.map(String.init) ?? "-"

        AppLogger.overlay.info(
            "overlay activation id=\(event.activationID.uuidString, privacy: .public) phase=\(event.phase.rawValue, privacy: .public) elapsedMs=\(event.elapsedMilliseconds, privacy: .public) nodes=\(nodes, privacy: .public) candidates=\(candidates, privacy: .public) command=\(command, privacy: .public) capture=\(capture, privacy: .public) session=\(hasSession, privacy: .public) timeout=\(timeout, privacy: .public) nodeLimit=\(nodeLimit, privacy: .public) depthLimit=\(depthLimit, privacy: .public) failedChildReads=\(failedChildReads, privacy: .public)"
        )
    }
}
