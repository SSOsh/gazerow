import CoreGraphics
import XCTest
@testable import GazeRow

/// ClickExecutor 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class ClickExecutorTests: XCTestCase {

    func test_execute_AXPress_성공() {
        // given
        let client = FakeClickExecutionClient(axPressResult: .success)
        let sut = ClickExecutor(client: client)

        // when
        let result = sut.execute(ClickExecutionRequest(target: safeTarget))

        // then
        assertSuccess(
            result,
            method: .axPress,
            riskClass: .safeNavigation,
            fallbackUsed: false
        )
        XCTAssertEqual(client.performedActions, [AccessibilityAction.press])
    }

    func test_execute_AXOpen_action만_있으면_AXOpen으로_성공() {
        // given
        let target = ClickTarget(
            element: 1,
            role: AccessibilityRole.cell,
            title: "Downloads",
            frame: CGRect(x: 10, y: 20, width: 30, height: 40),
            actions: [AccessibilityAction.open]
        )
        let client = FakeClickExecutionClient(actionResults: [AccessibilityAction.open: .success])
        let sut = ClickExecutor(client: client)

        // when
        let result = sut.execute(ClickExecutionRequest(target: target))

        // then
        assertSuccess(
            result,
            method: .accessibilityAction(AccessibilityAction.open),
            riskClass: .safeNavigation,
            fallbackUsed: false
        )
        XCTAssertEqual(client.performedActions, [AccessibilityAction.open])
    }

    func test_execute_AXConfirm_action만_있으면_AXConfirm으로_성공() {
        // given
        let target = ClickTarget(
            element: 1,
            role: AccessibilityRole.button,
            title: "OK",
            frame: CGRect(x: 10, y: 20, width: 30, height: 40),
            actions: [AccessibilityAction.confirm]
        )
        let client = FakeClickExecutionClient(actionResults: [AccessibilityAction.confirm: .success])
        let sut = ClickExecutor(client: client)

        // when
        let result = sut.execute(ClickExecutionRequest(target: target))

        // then
        assertSuccess(
            result,
            method: .accessibilityAction(AccessibilityAction.confirm),
            riskClass: .safeNavigation,
            fallbackUsed: false
        )
        XCTAssertEqual(client.performedActions, [AccessibilityAction.confirm])
    }

    func test_execute_AXShowDefaultUI_action만_있으면_AXShowDefaultUI로_성공() {
        // given
        let target = ClickTarget(
            element: 1,
            role: AccessibilityRole.row,
            title: "Downloads",
            frame: CGRect(x: 10, y: 20, width: 30, height: 40),
            actions: [AccessibilityAction.showDefaultUI]
        )
        let client = FakeClickExecutionClient(actionResults: [AccessibilityAction.showDefaultUI: .success])
        let sut = ClickExecutor(client: client)

        // when
        let result = sut.execute(ClickExecutionRequest(target: target))

        // then
        assertSuccess(
            result,
            method: .accessibilityAction(AccessibilityAction.showDefaultUI),
            riskClass: .safeNavigation,
            fallbackUsed: false
        )
        XCTAssertEqual(client.performedActions, [AccessibilityAction.showDefaultUI])
    }

    func test_execute_AXPress와_AXOpen이_함께_있으면_AXPress를_우선한다() {
        // given
        let target = ClickTarget(
            element: 1,
            role: AccessibilityRole.cell,
            title: "Downloads",
            frame: CGRect(x: 10, y: 20, width: 30, height: 40),
            actions: [AccessibilityAction.open, AccessibilityAction.press]
        )
        let client = FakeClickExecutionClient(
            actionResults: [
                AccessibilityAction.press: .success,
                AccessibilityAction.open: .failure("should not be used")
            ]
        )
        let sut = ClickExecutor(client: client)

        // when
        let result = sut.execute(ClickExecutionRequest(target: target))

        // then
        assertSuccess(
            result,
            method: .axPress,
            riskClass: .safeNavigation,
            fallbackUsed: false
        )
        XCTAssertEqual(client.performedActions, [AccessibilityAction.press])
    }

    func test_execute_overlayConfirm설정은_작은_무제목_button을_좌표클릭으로_실행() {
        // given
        let target = ClickTarget(
            element: 1,
            role: AccessibilityRole.button,
            title: nil,
            frame: CGRect(x: 82, y: 47, width: 28, height: 28),
            actions: [AccessibilityAction.press, AccessibilityAction.showDefaultUI]
        )
        let client = FakeClickExecutionClient(
            axPressResult: .success,
            coordinateClickResult: .success
        )
        let sut = ClickExecutor(
            client: client,
            configuration: .overlayConfirmedClick
        )

        // when
        let result = sut.execute(ClickExecutionRequest(target: target))

        // then
        assertSuccess(
            result,
            method: .coordinateFallback,
            riskClass: .safeNavigation,
            fallbackUsed: true
        )
        XCTAssertEqual(client.performedActions, [])
        XCTAssertEqual(client.clickedPoint, target.centerPoint)
    }

    func test_execute_overlayConfirm설정도_title있는_button은_AXPress를_우선한다() {
        // given
        let client = FakeClickExecutionClient(axPressResult: .success)
        let sut = ClickExecutor(
            client: client,
            configuration: .overlayConfirmedClick
        )

        // when
        let result = sut.execute(ClickExecutionRequest(target: safeTarget))

        // then
        assertSuccess(
            result,
            method: .axPress,
            riskClass: .safeNavigation,
            fallbackUsed: false
        )
        XCTAssertEqual(client.performedActions, [AccessibilityAction.press])
        XCTAssertFalse(client.didCoordinateClick)
    }

    func test_execute_AXPress_action이_없으면_missingPressAction() {
        // given
        let target = ClickTarget(
            element: 1,
            role: AccessibilityRole.button,
            title: "Open",
            frame: CGRect(x: 10, y: 20, width: 30, height: 40),
            actions: []
        )
        let sut = ClickExecutor(client: FakeClickExecutionClient(axPressResult: .success))

        // when
        let result = sut.execute(ClickExecutionRequest(target: target))

        // then
        XCTAssertEqual(result, .failure(.missingPressAction))
    }

    func test_execute_기본설정은_위험_action도_1회로_AXPress_실행() {
        // given
        let target = ClickTarget(
            element: 1,
            role: AccessibilityRole.button,
            title: "Delete Project",
            frame: CGRect(x: 10, y: 20, width: 30, height: 40),
            actions: [AccessibilityAction.press]
        )
        let sut = ClickExecutor(client: FakeClickExecutionClient(axPressResult: .success))

        // when
        let result = sut.execute(ClickExecutionRequest(target: target))

        // then
        assertSuccess(
            result,
            method: .axPress,
            riskClass: .destructive,
            fallbackUsed: false
        )
    }

    func test_execute_secondConfirm설정이_켜지면_위험_action은_secondConfirm_요구() {
        // given
        let target = ClickTarget(
            element: 1,
            role: AccessibilityRole.button,
            title: "Delete Project",
            frame: CGRect(x: 10, y: 20, width: 30, height: 40),
            actions: [AccessibilityAction.press]
        )
        let sut = ClickExecutor(
            client: FakeClickExecutionClient(axPressResult: .success),
            configuration: ClickExecutionConfiguration(requiresSecondConfirmForRiskyAction: true)
        )

        // when
        let result = sut.execute(ClickExecutionRequest(target: target))

        // then
        XCTAssertEqual(result, .failure(.secondConfirmRequired(riskClass: .destructive)))
    }

    func test_execute_secondConfirm이_있으면_위험_action도_AXPress_실행() {
        // given
        let target = ClickTarget(
            element: 1,
            role: AccessibilityRole.button,
            title: "Delete Project",
            frame: CGRect(x: 10, y: 20, width: 30, height: 40),
            actions: [AccessibilityAction.press]
        )
        let sut = ClickExecutor(
            client: FakeClickExecutionClient(axPressResult: .success),
            configuration: ClickExecutionConfiguration(requiresSecondConfirmForRiskyAction: true)
        )

        // when
        let result = sut.execute(
            ClickExecutionRequest(target: target, isSecondConfirmProvided: true)
        )

        // then
        assertSuccess(
            result,
            method: .axPress,
            riskClass: .destructive,
            fallbackUsed: false
        )
    }

    func test_execute_AXPress_실패하고_fallback_off이면_좌표클릭하지_않음() {
        // given
        let client = FakeClickExecutionClient(axPressResult: .failure("cannot complete"))
        let sut = ClickExecutor(client: client)

        // when
        let result = sut.execute(ClickExecutionRequest(target: safeTarget))

        // then
        XCTAssertEqual(
            result,
            .failure(.coordinateFallbackDisabled(axFailureReason: "cannot complete"))
        )
        XCTAssertFalse(client.didCoordinateClick)
    }

    func test_execute_fallback_on이면_AXPress_실패후_좌표클릭_실행() {
        // given
        let client = FakeClickExecutionClient(
            axPressResult: .failure("cannot complete"),
            coordinateClickResult: .success
        )
        let sut = ClickExecutor(
            client: client,
            configuration: ClickExecutionConfiguration(isCoordinateFallbackEnabled: true)
        )

        // when
        let result = sut.execute(ClickExecutionRequest(target: safeTarget))

        // then
        assertSuccess(
            result,
            method: .coordinateFallback,
            riskClass: .safeNavigation,
            fallbackUsed: true
        )
        XCTAssertTrue(client.didCoordinateClick)
        XCTAssertEqual(client.clickedPoint, safeTarget.centerPoint)
    }

    func test_execute_fallback_on이어도_좌표클릭_실패를_반환() {
        // given
        let client = FakeClickExecutionClient(
            axPressResult: .failure("cannot complete"),
            coordinateClickResult: .failure("event creation failed")
        )
        let sut = ClickExecutor(
            client: client,
            configuration: ClickExecutionConfiguration(isCoordinateFallbackEnabled: true)
        )

        // when
        let result = sut.execute(ClickExecutionRequest(target: safeTarget))

        // then
        XCTAssertEqual(
            result,
            .failure(.coordinateFallbackFailed(reason: "event creation failed"))
        )
    }

    private var safeTarget: ClickTarget<Int> {
        ClickTarget(
            element: 1,
            role: AccessibilityRole.button,
            title: "Open",
            frame: CGRect(x: 10, y: 20, width: 30, height: 40),
            actions: [AccessibilityAction.press]
        )
    }

    private func assertSuccess(
        _ result: Result<ClickExecutionSuccess, ClickExecutionFailure>,
        method: ClickExecutionMethod,
        riskClass: ClickRiskClass,
        fallbackUsed: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .success(let success) = result else {
            XCTFail("Expected success, got \(result).", file: file, line: line)
            return
        }

        XCTAssertEqual(success.method, method, file: file, line: line)
        XCTAssertEqual(success.riskClass, riskClass, file: file, line: line)
        XCTAssertEqual(success.fallbackUsed, fallbackUsed, file: file, line: line)
    }
}

private final class FakeClickExecutionClient: ClickExecutionClient {
    private let actionResults: [String: ClickClientResult]
    private let coordinateClickResult: ClickClientResult
    private(set) var performedActions: [String] = []
    private(set) var didCoordinateClick = false
    private(set) var clickedPoint: CGPoint?

    init(
        axPressResult: ClickClientResult,
        coordinateClickResult: ClickClientResult = .success
    ) {
        self.actionResults = [AccessibilityAction.press: axPressResult]
        self.coordinateClickResult = coordinateClickResult
    }

    init(
        actionResults: [String: ClickClientResult],
        coordinateClickResult: ClickClientResult = .success
    ) {
        self.actionResults = actionResults
        self.coordinateClickResult = coordinateClickResult
    }

    func performAXPress(on element: Int) -> ClickClientResult {
        performAXAction(AccessibilityAction.press, on: element)
    }

    func performAXAction(_ action: String, on element: Int) -> ClickClientResult {
        performedActions.append(action)
        return actionResults[action] ?? .failure("Unsupported AX action.")
    }

    func performCoordinateClick(at point: CGPoint) -> ClickClientResult {
        didCoordinateClick = true
        clickedPoint = point
        return coordinateClickResult
    }
}
