import Foundation

/// 확정 click의 개인정보 비포함 성능 측정값.
///
/// @author suho.do
/// @since 2026-07-14
struct OverlayClickPerformanceSample: Equatable {
    let rescanMilliseconds: Int
    let totalMilliseconds: Int
    let outcome: String
    let revalidationPath: OverlayClickRevalidationPath

    init(
        rescanMilliseconds: Int,
        totalMilliseconds: Int,
        outcome: String,
        revalidationPath: OverlayClickRevalidationPath
    ) {
        self.rescanMilliseconds = max(0, rescanMilliseconds)
        self.totalMilliseconds = max(0, totalMilliseconds)
        self.outcome = outcome
        self.revalidationPath = revalidationPath
    }
}

/// 최근 confirm 성능의 p50/p95 요약.
///
/// @author suho.do
/// @since 2026-07-14
struct OverlayClickPerformanceSummary: Equatable {
    let sampleCount: Int
    let rescanP50Milliseconds: Int
    let rescanP95Milliseconds: Int
    let totalP50Milliseconds: Int
    let totalP95Milliseconds: Int
    let selectiveSampleCount: Int
    let fullRescanSampleCount: Int

    init(samples: [OverlayClickPerformanceSample]) {
        let rescans = samples.map(\.rescanMilliseconds)
        let totals = samples.map(\.totalMilliseconds)
        sampleCount = samples.count
        rescanP50Milliseconds = Self.percentile(0.50, in: rescans)
        rescanP95Milliseconds = Self.percentile(0.95, in: rescans)
        totalP50Milliseconds = Self.percentile(0.50, in: totals)
        totalP95Milliseconds = Self.percentile(0.95, in: totals)
        selectiveSampleCount = samples.filter { $0.revalidationPath == .selective }.count
        fullRescanSampleCount = samples.filter { $0.revalidationPath == .fullRescan }.count
    }

    private static func percentile(_ percentile: Double, in samples: [Int]) -> Int {
        guard !samples.isEmpty else {
            return 0
        }

        let sorted = samples.sorted()
        let index = min(
            sorted.count - 1,
            max(0, Int((Double(sorted.count) * percentile).rounded(.up)) - 1)
        )
        return sorted[index]
    }
}

/// 확정 click 성능 측정값을 기록한다.
///
/// @author suho.do
/// @since 2026-07-14
@MainActor
protocol OverlayClickPerformanceRecording {
    func record(_ sample: OverlayClickPerformanceSample)
}

/// 최근 확정 click 성능을 rolling p50/p95로 OSLog에 남긴다.
///
/// title, label, 입력값, 좌표는 기록하지 않는다.
///
/// @author suho.do
/// @since 2026-07-14
@MainActor
final class OverlayClickPerformanceRecorder: OverlayClickPerformanceRecording {
    private let maximumSampleCount: Int
    private let onRecord: (OverlayClickPerformanceSample, OverlayClickPerformanceSummary) -> Void
    private(set) var samples: [OverlayClickPerformanceSample] = []

    init(
        maximumSampleCount: Int = 100,
        onRecord: @escaping (OverlayClickPerformanceSample, OverlayClickPerformanceSummary) -> Void = { sample, summary in
            AppLogger.interaction.info(
                "overlay confirm outcome=\(sample.outcome, privacy: .public) path=\(sample.revalidationPath.rawValue, privacy: .public) rescanMs=\(sample.rescanMilliseconds, privacy: .public) totalMs=\(sample.totalMilliseconds, privacy: .public) rescanP50Ms=\(summary.rescanP50Milliseconds, privacy: .public) rescanP95Ms=\(summary.rescanP95Milliseconds, privacy: .public) totalP50Ms=\(summary.totalP50Milliseconds, privacy: .public) totalP95Ms=\(summary.totalP95Milliseconds, privacy: .public) selectiveSamples=\(summary.selectiveSampleCount, privacy: .public) fullRescanSamples=\(summary.fullRescanSampleCount, privacy: .public) samples=\(summary.sampleCount, privacy: .public)"
            )
        }
    ) {
        self.maximumSampleCount = max(1, maximumSampleCount)
        self.onRecord = onRecord
    }

    func record(_ sample: OverlayClickPerformanceSample) {
        samples.append(sample)
        if samples.count > maximumSampleCount {
            samples.removeFirst(samples.count - maximumSampleCount)
        }

        onRecord(sample, OverlayClickPerformanceSummary(samples: samples))
    }
}

/// click 실행 결과를 원문 없이 성능 로그 code로 바꾼다.
///
/// @author suho.do
/// @since 2026-07-14
enum OverlayClickPerformanceOutcome {
    static func code(
        for result: Result<ClickExecutionSuccess, OverlaySessionClickFailure>
    ) -> String {
        switch result {
        case .success:
            "clicked"
        case .failure(.selectedTargetUnavailable):
            "target_unavailable"
        case .failure(.selectedTargetChanged):
            "target_changed"
        case .failure(.selectedTargetAmbiguous):
            "target_ambiguous"
        case .failure(.scanFailed):
            "scan_failed"
        case .failure(.missingFocusedTarget):
            "missing_target"
        case .failure(.executionFailed):
            "execution_failed"
        }
    }
}
