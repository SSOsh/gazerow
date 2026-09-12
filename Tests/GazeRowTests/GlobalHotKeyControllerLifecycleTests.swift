import Carbon
import XCTest
@testable import GazeRow

/// GlobalHotKeyController의 실제 Carbon 등록/해제 lifecycle 테스트.
///
/// `RegisterEventHotKey`/`InstallEventHandler`는 WindowServer 세션이 필요해 headless CI에서는
/// 신뢰할 수 없으므로, CI 환경에서는 명시적 사유와 함께 skip하고 로컬 GUI 세션에서만 실행한다.
/// 실제 사용자 단축키 하이재킹을 피하려 앱이 쓰지 않는 고유 signature와 네 modifier + 드문
/// keyCode 조합을 쓰고, 각 테스트는 tearDown에서 반드시 unregister 한다.
///
/// @author suho.do
/// @since 2026-09-12
@MainActor
final class GlobalHotKeyControllerLifecycleTests: XCTestCase {

    private var controllers: [GlobalHotKeyController] = []

    override func tearDown() {
        controllers.forEach { $0.unregister() }
        controllers.removeAll()
        super.tearDown()
    }

    func test_register는_유효한_정의에_noErr를_반환한다() throws {
        try skipInUnsupportedEnvironment()

        // given
        let sut = makeController(identifier: 9001)

        // when
        let status = sut.register()

        // then
        XCTAssertEqual(status, noErr)
    }

    func test_register_unregister_후_다시_register해도_noErr() throws {
        try skipInUnsupportedEnvironment()

        // given
        let sut = makeController(identifier: 9002)
        XCTAssertEqual(sut.register(), noErr)

        // when
        sut.unregister()

        // then: unregister가 ref를 정리했으므로 재등록이 다시 성공해야 한다
        XCTAssertEqual(sut.register(), noErr)
    }

    func test_unregister는_register없이_호출해도_안전하고_이후_register가능() throws {
        try skipInUnsupportedEnvironment()

        // given
        let sut = makeController(identifier: 9003)

        // when: register 전에 호출 — no-op이어야 한다
        sut.unregister()

        // then
        XCTAssertEqual(sut.register(), noErr)
    }

    func test_같은_정의를_중복_등록하면_두번째는_eventHotKeyExistsErr() throws {
        try skipInUnsupportedEnvironment()

        // given: 동일한 keyCode+modifier 조합을 쓰는 두 controller
        let definition = makeDefinition(identifier: 9004)
        let first = makeController(definition: definition)
        let second = makeController(definition: definition)

        // when
        let firstStatus = first.register()
        let secondStatus = second.register()

        // then: 이미 등록된 동일 hotkey는 중복 등록 시 eventHotKeyExistsErr를 반환한다
        XCTAssertEqual(firstStatus, noErr)
        XCTAssertEqual(secondStatus, OSStatus(eventHotKeyExistsErr))
    }

    // MARK: - Helpers

    private func skipInUnsupportedEnvironment() throws {
        if ProcessInfo.processInfo.environment["CI"] != nil {
            throw XCTSkip(
                "실제 Carbon hotkey 등록은 WindowServer 세션이 필요해 headless CI에서 건너뜀 (로컬 GUI 세션 전용)"
            )
        }
    }

    private func makeDefinition(identifier: UInt32) -> GlobalHotKeyDefinition {
        // 앱 기본 signature("GzRw")와 겹치지 않는 테스트 전용 signature + 네 modifier + 드문 keyCode로
        // 실제 사용자 단축키 충돌 가능성을 없앤다.
        GlobalHotKeyDefinition(
            keyCode: 0x6E,
            requiredModifiers: [.control, .option, .command, .shift],
            signature: GlobalHotKeyDefinition.fourCharacterCode("GzTt"),
            identifier: identifier
        )
    }

    private func makeController(identifier: UInt32) -> GlobalHotKeyController {
        makeController(definition: makeDefinition(identifier: identifier))
    }

    private func makeController(definition: GlobalHotKeyDefinition) -> GlobalHotKeyController {
        let controller = GlobalHotKeyController(definition: definition) {}
        controllers.append(controller)
        return controller
    }
}
