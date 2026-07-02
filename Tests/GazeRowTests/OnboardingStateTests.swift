import XCTest
@testable import GazeRow

/// `OnboardingState`의 첫 실행 판정/완료 처리 단위 테스트.
///
/// 실제 `.standard`를 오염시키지 않도록 임시 suite `UserDefaults`를 주입한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class OnboardingStateTests: XCTestCase {

    /// 테스트마다 격리된 임시 UserDefaults를 만든다.
    private func makeDefaults() -> UserDefaults {
        let suiteName = "OnboardingStateTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    func test_최초상태_미완료() {
        // given
        let sut = OnboardingState(defaults: makeDefaults())

        // then
        XCTAssertFalse(sut.hasCompleted)
        XCTAssertFalse(sut.isPresenting)
    }

    func test_presentIfNeeded_미완료면_시트표시() {
        // given
        let sut = OnboardingState(defaults: makeDefaults())

        // when
        sut.presentIfNeeded()

        // then
        XCTAssertTrue(sut.isPresenting)
    }

    func test_complete_완료저장_및_시트닫힘() {
        // given
        let sut = OnboardingState(defaults: makeDefaults())
        sut.presentIfNeeded()

        // when
        sut.complete()

        // then
        XCTAssertTrue(sut.hasCompleted)
        XCTAssertFalse(sut.isPresenting)
    }

    func test_presentIfNeeded_완료후에는_시트미표시() {
        // given
        let defaults = makeDefaults()
        let first = OnboardingState(defaults: defaults)
        first.complete()

        // when: 같은 저장소를 쓰는 새 인스턴스(재실행 상황)
        let second = OnboardingState(defaults: defaults)
        second.presentIfNeeded()

        // then
        XCTAssertTrue(second.hasCompleted)
        XCTAssertFalse(second.isPresenting)
    }
}
