import XCTest
@testable import GazeRow

/// `OverlaySessionStartFailure`의 권한 복구 필요 여부를 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class OverlaySessionStartFailureTests: XCTestCase {

    func test_requiresAccessibilityPermission_targetResolutionPermissionDenied이면_true() {
        // given
        let failure = OverlaySessionStartFailure.targetResolutionFailed(.accessibilityPermissionDenied)

        // when & then
        XCTAssertTrue(failure.requiresAccessibilityPermission)
    }

    func test_requiresAccessibilityPermission_scanPermissionDenied이면_true() {
        // given
        let failure = OverlaySessionStartFailure.scanFailed(.accessibilityPermissionDenied)

        // when & then
        XCTAssertTrue(failure.requiresAccessibilityPermission)
    }

    func test_requiresAccessibilityPermission_다른실패는_false() {
        // given
        let failures: [OverlaySessionStartFailure] = [
            .sessionDisabled,
            .targetResolutionFailed(.noFrontmostApplication),
            .scanFailed(.childrenUnavailable("notAvailable"))
        ]

        // when & then
        XCTAssertTrue(failures.allSatisfy { !$0.requiresAccessibilityPermission })
    }
}
