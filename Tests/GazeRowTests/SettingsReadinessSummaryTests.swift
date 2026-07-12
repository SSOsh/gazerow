import XCTest
@testable import GazeRow

/// Settings 기본 사용 가능 상태 요약 테스트.
///
/// @author suho.do
/// @since 2026-07-12
final class SettingsReadinessSummaryTests: XCTestCase {

    func test_init_accessibility권한이없으면_permissionRequired를_우선한다() {
        // given
        let isAccessibilityGranted = false
        let isSessionEnabled = false

        // when
        let sut = SettingsReadinessSummary(
            isAccessibilityGranted: isAccessibilityGranted,
            isSessionEnabled: isSessionEnabled
        )

        // then
        XCTAssertEqual(sut.state, .permissionRequired)
    }

    func test_init_권한은있지만_세션이꺼져있으면_sessionDisabled를_반환한다() {
        // given
        let isAccessibilityGranted = true
        let isSessionEnabled = false

        // when
        let sut = SettingsReadinessSummary(
            isAccessibilityGranted: isAccessibilityGranted,
            isSessionEnabled: isSessionEnabled
        )

        // then
        XCTAssertEqual(sut.state, .sessionDisabled)
    }

    func test_init_권한과세션이_모두준비되면_ready를_반환한다() {
        // given
        let isAccessibilityGranted = true
        let isSessionEnabled = true

        // when
        let sut = SettingsReadinessSummary(
            isAccessibilityGranted: isAccessibilityGranted,
            isSessionEnabled: isSessionEnabled
        )

        // then
        XCTAssertEqual(sut.state, .ready)
    }
}
