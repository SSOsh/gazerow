import XCTest
@testable import GazeRow

/// overlay confirm 성능 측정 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-14
@MainActor
final class OverlayClickPerformanceTests: XCTestCase {

    func test_summary는_nearestRank방식으로_p50과_p95를계산한다() {
        // given
        let samples = [10, 20, 30, 40, 50].map {
            OverlayClickPerformanceSample(
                rescanMilliseconds: $0,
                totalMilliseconds: $0 * 2,
                outcome: "clicked"
            )
        }

        // when
        let summary = OverlayClickPerformanceSummary(samples: samples)

        // then
        XCTAssertEqual(summary.sampleCount, 5)
        XCTAssertEqual(summary.rescanP50Milliseconds, 30)
        XCTAssertEqual(summary.rescanP95Milliseconds, 50)
        XCTAssertEqual(summary.totalP50Milliseconds, 60)
        XCTAssertEqual(summary.totalP95Milliseconds, 100)
    }

    func test_recorder는_최근최대개수만유지하고_요약을전달한다() {
        // given
        var summaries: [OverlayClickPerformanceSummary] = []
        let sut = OverlayClickPerformanceRecorder(maximumSampleCount: 2) { _, summary in
            summaries.append(summary)
        }

        // when
        sut.record(OverlayClickPerformanceSample(rescanMilliseconds: 10, totalMilliseconds: 20, outcome: "clicked"))
        sut.record(OverlayClickPerformanceSample(rescanMilliseconds: 20, totalMilliseconds: 30, outcome: "clicked"))
        sut.record(OverlayClickPerformanceSample(rescanMilliseconds: 30, totalMilliseconds: 40, outcome: "target_changed"))

        // then
        XCTAssertEqual(sut.samples.map(\.rescanMilliseconds), [20, 30])
        XCTAssertEqual(summaries.last?.sampleCount, 2)
        XCTAssertEqual(summaries.last?.rescanP50Milliseconds, 20)
        XCTAssertEqual(summaries.last?.rescanP95Milliseconds, 30)
    }

    func test_outcome은_원문없이_결과코드만_반환한다() {
        // given & when & then
        XCTAssertEqual(
            OverlayClickPerformanceOutcome.code(for: .failure(.selectedTargetChanged(labelID: 4))),
            "target_changed"
        )
        XCTAssertEqual(
            OverlayClickPerformanceOutcome.code(for: .failure(.executionFailed(.axPressFailed(reason: "private")))),
            "execution_failed"
        )
    }
}
