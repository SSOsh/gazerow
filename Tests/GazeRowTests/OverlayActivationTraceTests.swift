import Foundation
import XCTest
@testable import GazeRow

/// Overlay activation timing event 수집을 검증한다.
///
/// @author suho.do
/// @since 2026-07-17
@MainActor
final class OverlayActivationTraceTests: XCTestCase {

    func test_mark은_경과시간과비식별메타데이터를_event로전달한다() {
        // given
        var capturedEvents: [OverlayActivationTraceEvent] = []
        let sut = OverlayActivationTracer { capturedEvents.append($0) }
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let activationID = sut.begin(at: startedAt)
        let metadata = OverlayActivationTraceMetadata(nodesVisited: 675, candidateCount: 520)

        // when
        sut.mark(
            .scanCompleted,
            activationID: activationID,
            at: startedAt.addingTimeInterval(0.1236),
            metadata: metadata
        )

        // then
        XCTAssertEqual(
            capturedEvents,
            [
                OverlayActivationTraceEvent(
                    activationID: activationID,
                    phase: .scanCompleted,
                    elapsedMilliseconds: 124,
                    metadata: metadata
                )
            ]
        )
    }

    func test_end후_mark은_경과시간을_0으로전달한다() {
        // given
        var capturedEvents: [OverlayActivationTraceEvent] = []
        let sut = OverlayActivationTracer { capturedEvents.append($0) }
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let activationID = sut.begin(at: startedAt)
        sut.end(activationID: activationID)

        // when
        sut.mark(
            .firstDisplayPass,
            activationID: activationID,
            at: startedAt.addingTimeInterval(1),
            metadata: OverlayActivationTraceMetadata()
        )

        // then
        XCTAssertEqual(capturedEvents.first?.elapsedMilliseconds, 0)
    }
}
