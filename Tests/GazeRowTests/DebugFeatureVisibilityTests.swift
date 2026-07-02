import XCTest
@testable import GazeRow

/// `DebugFeatureVisibility`의 debug UI 기본 숨김 정책 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class DebugFeatureVisibilityTests: XCTestCase {

    /// 테스트마다 격리된 임시 UserDefaults를 만든다.
    private func makeDefaults() -> UserDefaults {
        let suiteName = "DebugFeatureVisibilityTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    func test_기본상태_debugExport는_숨김() {
        // given
        let sut = DebugFeatureVisibility(defaults: makeDefaults())

        // then
        XCTAssertFalse(sut.isDebugExportVisible)
    }

    func test_defaults값이_true면_debugExport를_노출() {
        // given
        let defaults = makeDefaults()
        defaults.set(true, forKey: DebugFeatureVisibility.debugExportVisibleKey)

        // when
        let sut = DebugFeatureVisibility(defaults: defaults)

        // then
        XCTAssertTrue(sut.isDebugExportVisible)
    }
}
