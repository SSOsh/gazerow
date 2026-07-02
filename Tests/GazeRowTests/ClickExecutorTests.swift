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

    func test_execute_위험_action은_secondConfirm_요구() {
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
        let sut = ClickExecutor(client: FakeClickExecutionClient(axPressResult: .success))

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
    private let axPressResult: ClickClientResult
    private let coordinateClickResult: ClickClientResult
    private(set) var didCoordinateClick = false
    private(set) var clickedPoint: CGPoint?

    init(
        axPressResult: ClickClientResult,
        coordinateClickResult: ClickClientResult = .success
    ) {
        self.axPressResult = axPressResult
        self.coordinateClickResult = coordinateClickResult
    }

    func performAXPress(on element: Int) -> ClickClientResult {
        axPressResult
    }

    func performCoordinateClick(at point: CGPoint) -> ClickClientResult {
        didCoordinateClick = true
        clickedPoint = point
        return coordinateClickResult
    }
}
