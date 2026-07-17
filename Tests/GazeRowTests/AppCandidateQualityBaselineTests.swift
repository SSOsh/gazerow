import XCTest
@testable import GazeRow

/// AppCandidateQualityBaseline 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-12
final class AppCandidateQualityBaselineTests: XCTestCase {

    func test_defaults는_지원앱_bundle_baseline을_포함한다() {
        // given
        let bundleIDs = Set(AppCandidateQualityBaseline.defaults.map(\.bundleIdentifier))

        // then
        XCTAssertTrue(bundleIDs.contains("com.apple.finder"))
        XCTAssertTrue(bundleIDs.contains("com.apple.Safari"))
        XCTAssertTrue(bundleIDs.contains("com.google.Chrome"))
        XCTAssertTrue(bundleIDs.contains("com.microsoft.VSCode"))
        XCTAssertTrue(bundleIDs.contains("com.tinyspeck.slackmacgap"))
    }

    func test_baseline은_bundleIdentifier로_조회한다() throws {
        // when
        let sut = try XCTUnwrap(
            AppCandidateQualityBaseline.baseline(for: "com.microsoft.VSCode")
        )

        // then
        XCTAssertEqual(sut.displayName, "VS Code")
        XCTAssertEqual(sut.minimumCandidateCount, 1)
    }

    func test_isBelowBaseline은_최소후보수_미만일때_true다() {
        // given
        let sut = AppCandidateQualityBaseline(
            bundleIdentifier: "test.bundle",
            displayName: "Test",
            minimumCandidateCount: 2
        )

        // when & then
        XCTAssertTrue(sut.isBelowBaseline(candidateCount: 1))
        XCTAssertFalse(sut.isBelowBaseline(candidateCount: 2))
    }
}
