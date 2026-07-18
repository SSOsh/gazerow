import XCTest
@testable import GazeRow

/// BrowserAutomationPermissionManager 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-18
@MainActor
final class BrowserAutomationPermissionManagerTests: XCTestCase {

    func test_refresh_거부된_브라우저_이름만_deniedBrowserNames에_남는다() async {
        // given
        let chrome = BrowserAutomationTarget(profile: .init(bundleID: "com.google.Chrome"), displayName: "Google Chrome")
        let safari = BrowserAutomationTarget(profile: .init(bundleID: "com.apple.Safari"), displayName: "Safari")
        let sut = BrowserAutomationPermissionManager(
            statusProvider: { profile in
                profile.bundleID == "com.google.Chrome" ? .denied : .authorized
            },
            runningTargetsProvider: { [chrome, safari] }
        )

        // when
        await sut.refresh()

        // then
        XCTAssertEqual(sut.deniedBrowserNames, ["Google Chrome"])
    }

    func test_refresh_거부된_브라우저가_없으면_빈배열이다() async {
        // given
        let chrome = BrowserAutomationTarget(profile: .init(bundleID: "com.google.Chrome"), displayName: "Google Chrome")
        let sut = BrowserAutomationPermissionManager(
            statusProvider: { _ in .authorized },
            runningTargetsProvider: { [chrome] }
        )

        // when
        await sut.refresh()

        // then
        XCTAssertTrue(sut.deniedBrowserNames.isEmpty)
    }

    func test_refresh_실행중인_브라우저가_없으면_빈배열이다() async {
        // given
        let sut = BrowserAutomationPermissionManager(
            statusProvider: { _ in .denied },
            runningTargetsProvider: { [] }
        )

        // when
        await sut.refresh()

        // then
        XCTAssertTrue(sut.deniedBrowserNames.isEmpty)
    }

    func test_refresh_완료후에는_isChecking이_false다() async {
        // given
        let sut = BrowserAutomationPermissionManager(
            statusProvider: { _ in .authorized },
            runningTargetsProvider: { [] }
        )

        // when
        await sut.refresh()

        // then
        XCTAssertFalse(sut.isChecking)
    }

    func test_refresh_전에는_hasCheckedOnce가_false이고_이후에는_true다() async {
        // given
        let sut = BrowserAutomationPermissionManager(
            statusProvider: { _ in .authorized },
            runningTargetsProvider: { [] }
        )
        XCTAssertFalse(sut.hasCheckedOnce)

        // when
        await sut.refresh()

        // then
        XCTAssertTrue(sut.hasCheckedOnce)
    }
}
