import XCTest
@testable import GazeRow

/// RecentNonSelfApplicationProvider 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
@MainActor
final class RecentNonSelfApplicationProviderTests: XCTestCase {

    func test_frontmost가_self가_아니면_현재앱을_반환하고_기록() {
        // given
        let finder = makeApplication(bundleIdentifier: "com.apple.finder")
        let provider = StubFrontmostApplicationProvider(application: finder)
        let sut = RecentNonSelfApplicationProvider(
            ownBundleIdentifier: "dev.local.gazerow",
            currentApplicationProvider: provider,
            notificationCenter: NotificationCenter()
        )

        // when
        let result = sut.frontmostApplication()

        // then
        XCTAssertEqual(result, finder)
        XCTAssertEqual(sut.lastNonSelfApplication, finder)
    }

    func test_frontmost가_self이면_직전_nonSelf앱을_반환() {
        // given
        let finder = makeApplication(bundleIdentifier: "com.apple.finder")
        let gazeRow = makeApplication(bundleIdentifier: "dev.local.gazerow")
        let provider = StubFrontmostApplicationProvider(application: gazeRow)
        let sut = RecentNonSelfApplicationProvider(
            ownBundleIdentifier: "dev.local.gazerow",
            currentApplicationProvider: provider,
            notificationCenter: NotificationCenter()
        )
        sut.recordIfNonSelf(finder)

        // when
        let result = sut.frontmostApplication()

        // then
        XCTAssertEqual(result, finder)
    }

    func test_frontmost가_self이고_직전앱이_없으면_nil() {
        // given
        let gazeRow = makeApplication(bundleIdentifier: "dev.local.gazerow")
        let provider = StubFrontmostApplicationProvider(application: gazeRow)
        let sut = RecentNonSelfApplicationProvider(
            ownBundleIdentifier: "dev.local.gazerow",
            currentApplicationProvider: provider,
            notificationCenter: NotificationCenter()
        )

        // when
        let result = sut.frontmostApplication()

        // then
        XCTAssertNil(result)
    }

    private func makeApplication(bundleIdentifier: String) -> TargetApplication {
        TargetApplication(
            localizedName: bundleIdentifier,
            bundleIdentifier: bundleIdentifier,
            processIdentifier: 100
        )
    }
}

@MainActor
private final class StubFrontmostApplicationProvider: FrontmostApplicationProviding {
    var application: TargetApplication?

    init(application: TargetApplication?) {
        self.application = application
    }

    func frontmostApplication() -> TargetApplication? {
        application
    }
}
