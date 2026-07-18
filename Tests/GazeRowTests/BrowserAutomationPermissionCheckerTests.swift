import XCTest
@testable import GazeRow

/// BrowserAutomationPermissionChecker 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-18
final class BrowserAutomationPermissionCheckerTests: XCTestCase {

    func test_status_probe성공하면_authorized() {
        // given
        let sut = BrowserAutomationPermissionChecker()

        // when
        let status = sut.status(for: .init(bundleID: "com.google.Chrome")) { _ in .success }

        // then
        XCTAssertEqual(status, .authorized)
    }

    func test_status_notPermitted이면_denied() {
        // given
        let sut = BrowserAutomationPermissionChecker()

        // when
        let status = sut.status(for: .init(bundleID: "com.google.Chrome")) { _ in .notPermitted }

        // then
        XCTAssertEqual(status, .denied)
    }

    func test_status_notDetermined이면_notDetermined() {
        // given
        let sut = BrowserAutomationPermissionChecker()

        // when
        let status = sut.status(for: .init(bundleID: "com.google.Chrome")) { _ in .notDetermined }

        // then
        XCTAssertEqual(status, .notDetermined)
    }

    func test_status_그외에러는_unavailable() {
        // given
        let sut = BrowserAutomationPermissionChecker()

        // when
        let status = sut.status(for: .init(bundleID: "org.mozilla.firefox")) { _ in .other }

        // then
        XCTAssertEqual(status, .unavailable)
    }
}
