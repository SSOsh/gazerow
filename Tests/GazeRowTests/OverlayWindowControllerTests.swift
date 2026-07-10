import CoreGraphics
import XCTest
@testable import GazeRow

/// OverlayWindowController 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-03
@MainActor
final class OverlayWindowControllerTests: XCTestCase {

    func test_OverlayScreenFrameMapper_AX좌표를_AppKit좌표로_변환한다() {
        // given
        let sut = OverlayScreenFrameMapper(
            screenFrames: [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        )

        // when
        let appKitFrame = sut.appKitFrame(
            fromAXFrame: CGRect(x: 100, y: 120, width: 400, height: 300)
        )

        // then
        XCTAssertEqual(appKitFrame, CGRect(x: 100, y: 480, width: 400, height: 300))
        XCTAssertEqual(
            sut.axFrame(fromAppKitFrame: appKitFrame),
            CGRect(x: 100, y: 120, width: 400, height: 300)
        )
    }

    func test_OverlayScreenFrameMapper_위쪽_보조화면도_union_maxY로_변환한다() {
        // given
        let sut = OverlayScreenFrameMapper(
            screenFrames: [
                CGRect(x: 0, y: 0, width: 1440, height: 900),
                CGRect(x: 0, y: 900, width: 1440, height: 900)
            ]
        )

        // when
        let appKitFrame = sut.appKitFrame(
            fromAXFrame: CGRect(x: 20, y: 100, width: 300, height: 200)
        )

        // then
        XCTAssertEqual(appKitFrame, CGRect(x: 20, y: 1500, width: 300, height: 200))
    }

    func test_OverlayScreenFrameMapper_오른쪽_외장모니터_roundTrip을_유지한다() {
        // given
        let sut = OverlayScreenFrameMapper(
            screenFrames: [
                CGRect(x: 0, y: 0, width: 1440, height: 900),
                CGRect(x: 1440, y: 0, width: 1920, height: 1080)
            ]
        )
        let axFrame = CGRect(x: 1500, y: 100, width: 400, height: 240)

        // when
        let appKitFrame = sut.appKitFrame(fromAXFrame: axFrame)

        // then
        XCTAssertEqual(appKitFrame, CGRect(x: 1500, y: 740, width: 400, height: 240))
        XCTAssertEqual(sut.axFrame(fromAppKitFrame: appKitFrame), axFrame)
    }

    func test_OverlayScreenFrameMapper_왼쪽_외장모니터_roundTrip을_유지한다() {
        // given
        let sut = OverlayScreenFrameMapper(
            screenFrames: [
                CGRect(x: -1280, y: 0, width: 1280, height: 800),
                CGRect(x: 0, y: 0, width: 1440, height: 900)
            ]
        )
        let axFrame = CGRect(x: -1200, y: 50, width: 500, height: 250)

        // when
        let appKitFrame = sut.appKitFrame(fromAXFrame: axFrame)

        // then
        XCTAssertEqual(appKitFrame, CGRect(x: -1200, y: 600, width: 500, height: 250))
        XCTAssertEqual(sut.axFrame(fromAppKitFrame: appKitFrame), axFrame)
    }

    func test_OverlayScreenFrameMapper_아래쪽_외장모니터_roundTrip을_유지한다() {
        // given
        let sut = OverlayScreenFrameMapper(
            screenFrames: [
                CGRect(x: 0, y: 0, width: 1440, height: 900),
                CGRect(x: 0, y: -900, width: 1440, height: 900)
            ]
        )
        let appKitFrame = CGRect(x: 100, y: -760, width: 360, height: 220)

        // when
        let axFrame = sut.axFrame(fromAppKitFrame: appKitFrame)

        // then
        XCTAssertEqual(axFrame, CGRect(x: 100, y: 1440, width: 360, height: 220))
        XCTAssertEqual(sut.appKitFrame(fromAXFrame: axFrame), appKitFrame)
    }

    func test_show는_keyboardEventTap이_성공하면_application을_activate하지_않음() {
        // given
        var activateCallCount = 0
        let keyboardEventTap = FakeOverlayKeyboardEventTap(startResult: true)
        let sut = OverlayWindowController(
            displayInfoProvider: { _ in
                OverlayDisplayInfo(scaleFactor: 1, visibleFrame: nil)
            },
            applicationActivator: {
                activateCallCount += 1
            },
            keyboardEventTapFactory: { _ in
                keyboardEventTap
            }
        )

        // when
        sut.show(layout: makeLayout())

        // then
        XCTAssertEqual(activateCallCount, 0)
        XCTAssertEqual(keyboardEventTap.startCallCount, 1)
        XCTAssertTrue(sut.isVisible)

        sut.close()
        XCTAssertEqual(keyboardEventTap.stopCallCount, 1)
    }

    func test_show는_keyboardEventTap이_실패하면_application을_activate한다() {
        // given
        var activateCallCount = 0
        let keyboardEventTap = FakeOverlayKeyboardEventTap(startResult: false)
        let sut = OverlayWindowController(
            displayInfoProvider: { _ in
                OverlayDisplayInfo(scaleFactor: 1, visibleFrame: nil)
            },
            applicationActivator: {
                activateCallCount += 1
            },
            keyboardEventTapFactory: { _ in
                keyboardEventTap
            }
        )

        // when
        sut.show(layout: makeLayout())

        // then
        XCTAssertEqual(activateCallCount, 1)
        XCTAssertEqual(keyboardEventTap.startCallCount, 1)
        XCTAssertTrue(sut.isVisible)

        sut.close()
    }

    func test_show는_panel이_앱_비활성시_숨겨지지_않도록_설정한다() {
        // given: LSUIElement 앱은 overlay 표시 시 앱을 활성화하지 않으므로,
        // panel이 hidesOnDeactivate로 자동 숨김되면 화면에 나타나지 않는다.
        let sut = OverlayWindowController(
            displayInfoProvider: { _ in
                OverlayDisplayInfo(scaleFactor: 1, visibleFrame: nil)
            },
            keyboardEventTapFactory: { _ in
                FakeOverlayKeyboardEventTap(startResult: true)
            }
        )

        // when
        sut.show(layout: makeLayout())

        // then: 앱 비활성 상태에서도 overlay가 유지되어야 한다.
        XCTAssertTrue(sut.persistsWhileAppInactive)

        sut.close()
    }

    func test_show는_scopeChip_click을_위해_mouseInput을_허용한다() {
        // given
        let sut = OverlayWindowController(
            displayInfoProvider: { _ in
                OverlayDisplayInfo(scaleFactor: 1, visibleFrame: nil)
            },
            keyboardEventTapFactory: { _ in
                FakeOverlayKeyboardEventTap(startResult: true)
            }
        )

        // when
        sut.show(layout: makeLayout())

        // then
        XCTAssertTrue(sut.acceptsMouseInput)

        sut.close()
    }

    func test_show는_render시_appearanceProvider를_조회한다() {
        // given: appearanceProvider는 렌더 시점마다 최신 설정을 읽어야 한다.
        var appearanceCallCount = 0
        let sut = OverlayWindowController(
            displayInfoProvider: { _ in
                OverlayDisplayInfo(scaleFactor: 1, visibleFrame: nil)
            },
            keyboardEventTapFactory: { _ in
                FakeOverlayKeyboardEventTap(startResult: true)
            },
            appearanceProvider: {
                appearanceCallCount += 1
                return OverlayAppearance(labelBackgroundOpacity: 0.5)
            }
        )

        // when
        sut.show(layout: makeLayout())

        // then
        XCTAssertGreaterThanOrEqual(appearanceCallCount, 1)

        sut.close()
    }

    func test_OverlayKeyboardEventTapContext_매핑되지_않는_keyDown은_통과시킨다() {
        // given
        let sut = OverlayKeyboardEventTapContext { _ in }
        let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 49,
            keyDown: true
        )!

        // when
        let result = sut.handle(type: .keyDown, event: event)

        // then
        XCTAssertNotNil(result)
    }

    func test_OverlayKeyboardEventTapContext_매핑되는_keyDown은_소비한다() {
        // given
        let sut = OverlayKeyboardEventTapContext { _ in }
        let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 36,
            keyDown: true
        )!

        // when
        let result = sut.handle(type: .keyDown, event: event)

        // then
        XCTAssertNil(result)
    }

    func test_OverlayKeyboardEventTap_start는_secureEventInput이면_false() {
        // given
        let sut = OverlayKeyboardEventTap(
            isSecureEventInputEnabled: { true },
            onKeyboardCommand: { _ in }
        )

        // when
        let result = sut.start()

        // then
        XCTAssertFalse(result)
    }

    func test_OverlayKeyboardEventTap_start는_inputMonitoring권한이_없고_요청거절이면_false() {
        // given
        let sut = OverlayKeyboardEventTap(
            isSecureEventInputEnabled: { false },
            hasListenEventAccess: { false },
            requestListenEventAccess: { false },
            onKeyboardCommand: { _ in }
        )

        // when
        let result = sut.start()

        // then
        XCTAssertFalse(result)
    }

    func test_OverlayKeyboardCommandRouter_syncKeyboardState는_scopeChip선택후_문자를_query로_입력한다() {
        // given
        var sut = OverlayKeyboardCommandRouter()

        // when
        sut.syncKeyboardState(QueryInputState(pinnedScope: .windows, lastScope: .windows))
        let command = sut.command(
            for: FocusKeyboardInput(keyCode: 1, charactersIgnoringModifiers: "s")
        )

        // then
        XCTAssertEqual(command, .appendQuery("s"))
    }

    func test_OverlayKeyboardCommandRouter_syncKeyboardState는_pendingLabelPrimer를_초기화한다() {
        // given
        var sut = OverlayKeyboardCommandRouter()
        _ = sut.command(
            for: FocusKeyboardInput(keyCode: 0, charactersIgnoringModifiers: "a")
        )

        // when
        sut.syncKeyboardState(QueryInputState(pinnedScope: .elements, lastScope: .elements))
        let command = sut.command(
            for: FocusKeyboardInput(keyCode: 1, charactersIgnoringModifiers: "s")
        )

        // then
        XCTAssertEqual(command, .appendQuery("s"))
    }

    private func makeLayout() -> OverlayLayout {
        OverlayLayout(
            targetFrame: CGRect(x: 0, y: 0, width: 200, height: 120),
            localBounds: CGRect(x: 0, y: 0, width: 200, height: 120),
            labels: [
                OverlayLabel(
                    id: 0,
                    text: "AA",
                    candidateFrame: CGRect(x: 20, y: 20, width: 30, height: 20),
                    labelFrame: CGRect(x: 20, y: 20, width: 32, height: 22),
                    anchorPoint: CGPoint(x: 35, y: 30)
                )
            ],
            metrics: OverlayLayoutMetrics(
                labelCount: 1,
                collisionCount: 0,
                occlusionCount: 0,
                displayScaleFactor: 1
            ),
            displayInfo: OverlayDisplayInfo(scaleFactor: 1, visibleFrame: nil)
        )
    }
}

@MainActor
private final class FakeOverlayKeyboardEventTap: OverlayKeyboardEventTapping {
    private let startResult: Bool
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    init(startResult: Bool) {
        self.startResult = startResult
    }

    func start() -> Bool {
        startCallCount += 1
        return startResult
    }

    func stop() {
        stopCallCount += 1
    }
}
