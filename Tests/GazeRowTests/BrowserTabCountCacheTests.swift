import XCTest
@testable import GazeRow

/// BrowserTabCountCache 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-18
final class BrowserTabCountCacheTests: XCTestCase {

    func test_currentSnapshot_초기상태는_비어있다() {
        // given
        let sut = BrowserTabCountCache(fetchTabCounts: { _ in [:] }) { $0() }

        // then
        XCTAssertTrue(sut.currentSnapshot().isEmpty)
    }

    func test_refreshInBackground_완료후_currentSnapshot에_결과가_반영된다() {
        // given: scheduleBackgroundWork를 동기 실행으로 주입해 결정론적으로 검증한다
        let sut = BrowserTabCountCache(
            fetchTabCounts: { profile in
                profile.bundleID == "com.google.Chrome" ? ["Gmail": 5] : [:]
            },
            scheduleBackgroundWork: { $0() }
        )

        // when
        sut.refreshInBackground(profiles: [.init(bundleID: "com.google.Chrome")])

        // then
        XCTAssertEqual(sut.currentSnapshot(), ["com.google.Chrome": ["Gmail": 5]])
    }

    func test_refreshInBackground_profiles가_비어있으면_아무_작업도_예약하지_않는다() {
        // given
        var scheduledWorkCount = 0
        let sut = BrowserTabCountCache(fetchTabCounts: { _ in [:] }) { work in
            scheduledWorkCount += 1
            work()
        }

        // when
        sut.refreshInBackground(profiles: [])

        // then
        XCTAssertEqual(scheduledWorkCount, 0)
    }

    func test_refreshInBackground_이미_진행중이면_중복으로_예약하지_않는다() {
        // given: scheduleBackgroundWork가 즉시 실행되지 않고 나중에 수동으로 실행되도록 캡처한다
        var pendingWork: (() -> Void)?
        var scheduledWorkCount = 0
        let sut = BrowserTabCountCache(fetchTabCounts: { _ in [:] }) { work in
            scheduledWorkCount += 1
            pendingWork = work
        }

        // when: 첫 refresh가 아직 끝나지 않은 상태에서 두 번째 refresh를 요청한다
        sut.refreshInBackground(profiles: [.init(bundleID: "com.google.Chrome")])
        sut.refreshInBackground(profiles: [.init(bundleID: "com.apple.Safari")])

        // then: 두 번째 요청은 무시되어 background work가 1번만 예약된다
        XCTAssertEqual(scheduledWorkCount, 1)

        // cleanup: 캡처된 work를 실행해 isRefreshing 플래그를 정리한다
        pendingWork?()
    }

    func test_refreshInBackground_완료후에는_다시_새_refresh를_예약할_수_있다() {
        // given
        var scheduledWorkCount = 0
        let sut = BrowserTabCountCache(fetchTabCounts: { _ in [:] }) { work in
            scheduledWorkCount += 1
            work()
        }

        // when: 첫 refresh가 동기적으로 즉시 끝나므로 isRefreshing이 풀린 뒤 두 번째를 요청한다
        sut.refreshInBackground(profiles: [.init(bundleID: "com.google.Chrome")])
        sut.refreshInBackground(profiles: [.init(bundleID: "com.apple.Safari")])

        // then
        XCTAssertEqual(scheduledWorkCount, 2)
    }
}
