import Foundation

/// 앱별 overlay 후보 품질 baseline.
///
/// 실제 평가를 통과한 앱은 최소 후보 수를 코드로 고정해 no-candidate 상황을
/// 일반 미지원 화면과 구분한다.
///
/// @author suho.do
/// @since 2026-07-12
struct AppCandidateQualityBaseline: Equatable {
    let bundleIdentifier: String
    let displayName: String
    let minimumCandidateCount: Int

    static let defaults: [AppCandidateQualityBaseline] = [
        AppCandidateQualityBaseline(
            bundleIdentifier: "com.apple.finder",
            displayName: "Finder",
            minimumCandidateCount: 1
        ),
        AppCandidateQualityBaseline(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            minimumCandidateCount: 1
        ),
        AppCandidateQualityBaseline(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Chrome",
            minimumCandidateCount: 1
        ),
        AppCandidateQualityBaseline(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "VS Code",
            minimumCandidateCount: 1
        ),
        AppCandidateQualityBaseline(
            bundleIdentifier: "com.apple.systempreferences",
            displayName: "System Settings",
            minimumCandidateCount: 1
        ),
        AppCandidateQualityBaseline(
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            displayName: "Slack",
            minimumCandidateCount: 1
        ),
        AppCandidateQualityBaseline(
            bundleIdentifier: "notion.id",
            displayName: "Notion",
            minimumCandidateCount: 1
        )
    ]

    static func baseline(for bundleIdentifier: String) -> AppCandidateQualityBaseline? {
        defaults.first { $0.bundleIdentifier == bundleIdentifier }
    }

    func isBelowBaseline(candidateCount: Int) -> Bool {
        candidateCount < minimumCandidateCount
    }
}
