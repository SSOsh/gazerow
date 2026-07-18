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

    func test_frontmost가_ControlCenter이면_직전앱을_유지한다() {
        // given
        let finder = makeApplication(bundleIdentifier: "com.apple.finder")
        let controlCenter = makeApplication(bundleIdentifier: "com.apple.controlcenter")
        let provider = StubFrontmostApplicationProvider(application: controlCenter)
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
        XCTAssertEqual(sut.lastNonSelfApplication, finder)
    }

    func test_주기적_재확인_tick만으로도_notification없이_캐시가_스스로_복구된다() {
        // given: notification 없이, 스케줄러가 캡처한 action을 수동으로 호출해 tick을 흉내낸다
        var capturedAction: (@MainActor () -> Void)?
        let provider = StubFrontmostApplicationProvider(application: nil)
        let sut = RecentNonSelfApplicationProvider(
            ownBundleIdentifier: "dev.local.gazerow",
            currentApplicationProvider: provider,
            notificationCenter: NotificationCenter(),
            scheduleRepeatingTask: { _, action in
                capturedAction = action
                return {}
            }
        )
        XCTAssertNil(sut.lastNonSelfApplication)

        // when: 캐시가 오래된 사이 사용자가 Finder로 전환했다고 가정하고 주기적 tick만 실행한다
        let finder = makeApplication(bundleIdentifier: "com.apple.finder")
        provider.application = finder
        capturedAction?()

        // then
        XCTAssertEqual(sut.lastNonSelfApplication, finder)
    }

    func test_주기적_재확인이_ControlCenter_같은_무시대상은_캐시를_덮어쓰지_않는다() {
        // given
        var capturedAction: (@MainActor () -> Void)?
        let finder = makeApplication(bundleIdentifier: "com.apple.finder")
        let provider = StubFrontmostApplicationProvider(application: finder)
        let sut = RecentNonSelfApplicationProvider(
            ownBundleIdentifier: "dev.local.gazerow",
            currentApplicationProvider: provider,
            notificationCenter: NotificationCenter(),
            scheduleRepeatingTask: { _, action in
                capturedAction = action
                return {}
            }
        )
        XCTAssertEqual(sut.lastNonSelfApplication, finder)

        // when
        provider.application = makeApplication(bundleIdentifier: "com.apple.controlcenter")
        capturedAction?()

        // then
        XCTAssertEqual(sut.lastNonSelfApplication, finder)
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
