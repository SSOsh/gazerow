import XCTest
@testable import GazeRow

/// `MVPDefaultPolicy`의 freeze 기본값 감사 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class MVPDefaultPolicyTests: XCTestCase {

    /// 테스트마다 격리된 임시 UserDefaults를 만든다.
    private func makeDefaults() -> UserDefaults {
        let suiteName = "MVPDefaultPolicyTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    func test_기본정책은_freeze_자동검증을_통과() {
        // given
        let defaults = makeDefaults()
        let sut = MVPDefaultPolicy(
            interactionLogStore: InteractionLogStore(defaults: defaults),
            debugFeatureVisibility: DebugFeatureVisibility(defaults: defaults)
        )

        // then
        XCTAssertTrue(sut.isGazeDisabled)
        XCTAssertTrue(sut.isCoordinateFallbackDisabled)
        XCTAssertTrue(sut.requiresSecondConfirmForRiskyAction)
        XCTAssertTrue(sut.isInteractionLogOptInDisabled)
        XCTAssertTrue(sut.isDebugExportHidden)
        XCTAssertTrue(sut.passesAutomatedFreezeDefaults)
    }

    func test_coordinateFallback이_켜지면_freeze_자동검증_실패() {
        // given
        let defaults = makeDefaults()
        let sut = MVPDefaultPolicy(
            clickConfiguration: ClickExecutionConfiguration(isCoordinateFallbackEnabled: true),
            interactionLogStore: InteractionLogStore(defaults: defaults),
            debugFeatureVisibility: DebugFeatureVisibility(defaults: defaults)
        )

        // then
        XCTAssertFalse(sut.isCoordinateFallbackDisabled)
        XCTAssertFalse(sut.passesAutomatedFreezeDefaults)
    }

    func test_interactionLogOptIn이_켜지면_freeze_자동검증_실패() {
        // given
        let defaults = makeDefaults()
        defaults.set(true, forKey: InteractionLogStore.optInKey)

        let sut = MVPDefaultPolicy(
            interactionLogStore: InteractionLogStore(defaults: defaults),
            debugFeatureVisibility: DebugFeatureVisibility(defaults: defaults)
        )

        // then
        XCTAssertFalse(sut.isInteractionLogOptInDisabled)
        XCTAssertFalse(sut.passesAutomatedFreezeDefaults)
    }

    func test_debugExport가_노출되면_freeze_자동검증_실패() {
        // given
        let defaults = makeDefaults()
        defaults.set(true, forKey: DebugFeatureVisibility.debugExportVisibleKey)

        let sut = MVPDefaultPolicy(
            interactionLogStore: InteractionLogStore(defaults: defaults),
            debugFeatureVisibility: DebugFeatureVisibility(defaults: defaults)
        )

        // then
        XCTAssertFalse(sut.isDebugExportHidden)
        XCTAssertFalse(sut.passesAutomatedFreezeDefaults)
    }
}
