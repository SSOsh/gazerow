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

    init(
        nodesVisited: Int? = nil,
        candidateCount: Int? = nil,
        commandKind: String? = nil,
        captureMode: String? = nil,
        hasActiveSession: Bool? = nil
    ) {
        self.nodesVisited = nodesVisited
        self.candidateCount = candidateCount
        self.commandKind = commandKind
        self.captureMode = captureMode
        self.hasActiveSession = hasActiveSession
    }
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
        let elapsedMilliseconds = elapsedMilliseconds(for: activationID, at: date)
        let nodes = metadata.nodesVisited.map(String.init) ?? "-"
        let candidates = metadata.candidateCount.map(String.init) ?? "-"
        let command = metadata.commandKind ?? "-"
        let capture = metadata.captureMode ?? "-"
        let hasSession = metadata.hasActiveSession.map(String.init) ?? "-"

        AppLogger.overlay.info(
            "overlay activation id=\(activationID.uuidString, privacy: .public) phase=\(phase.rawValue, privacy: .public) elapsedMs=\(elapsedMilliseconds, privacy: .public) nodes=\(nodes, privacy: .public) candidates=\(candidates, privacy: .public) command=\(command, privacy: .public) capture=\(capture, privacy: .public) session=\(hasSession, privacy: .public)"
        )
    }

    private func elapsedMilliseconds(for activationID: UUID, at date: Date) -> Int {
        guard let startedAt = startedAtByID[activationID] else {
            return 0
        }

        return max(0, Int((date.timeIntervalSince(startedAt) * 1_000).rounded()))
    }
}
