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
        XCTAssertTrue(sut.isTargetPanelVisible)
        XCTAssertTrue(sut.isCommandBarPanelVisible)

        sut.close()
        XCTAssertEqual(keyboardEventTap.stopCallCount, 1)
    }

    func test_show는_capture준비후_panel을_공개한다() {
        // given
        let keyboardEventTap = FakeOverlayKeyboardEventTap(startResult: true)
        let sut = OverlayWindowController(
            displayInfoProvider: { _ in
                OverlayDisplayInfo(scaleFactor: 1, visibleFrame: nil)
            },
            keyboardEventTapFactory: { _ in
                keyboardEventTap
            }
        )
        var presentationEvents: [OverlayPresentationEvent] = []

        // when
        let captureMode = sut.show(
            layout: makeLayout(),
            initialStatus: OverlayInteractionStatus(),
            onPresentationEvent: { event in
                presentationEvents.append(event)
            }
        )

        // then
        XCTAssertEqual(captureMode, .eventTap)
        XCTAssertEqual(
            Array(presentationEvents.prefix(2)),
            [.captureReady(.eventTap), .panelsOrdered]
        )

        sut.close()
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

    func test_updateStatus는_기존HostingView를_재사용한다() {
        // given
        let sut = OverlayWindowController(
            displayInfoProvider: { _ in
                OverlayDisplayInfo(scaleFactor: 1, visibleFrame: nil)
            },
            keyboardEventTapFactory: { _ in
                FakeOverlayKeyboardEventTap(startResult: true)
            }
        )
        sut.show(layout: makeLayout())
        let targetIdentifier = sut.targetHostingViewIdentifier
        let commandIdentifier = sut.commandBarHostingViewIdentifier

        // when
        sut.updateStatus(
            OverlayInteractionStatus(
                focusedLabel: "AA",
                hasExplicitFocus: true
            )
        )

        // then
        XCTAssertEqual(sut.targetHostingViewIdentifier, targetIdentifier)
        XCTAssertEqual(sut.commandBarHostingViewIdentifier, commandIdentifier)

        sut.close()
    }

    func test_show는_target교차면적이큰화면의_visibleFrame에_commandPanel을배치한다() {
        // given
        let leftScreen = OverlayScreenDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 760),
            scaleFactor: 2
        )
        let rightScreen = OverlayScreenDescriptor(
            frame: CGRect(x: 1_000, y: 0, width: 1_000, height: 800),
            visibleFrame: CGRect(x: 1_000, y: 40, width: 1_000, height: 760),
            scaleFactor: 1
        )
        let sut = OverlayWindowController(
            screenFrameProvider: { [leftScreen.frame, rightScreen.frame] },
            screenDescriptorProvider: { [leftScreen, rightScreen] },
            keyboardEventTapFactory: { _ in
                FakeOverlayKeyboardEventTap(startResult: true)
            }
        )
        let layout = makeLayout(targetFrame: CGRect(x: 850, y: 100, width: 500, height: 400))

        // when
        sut.show(layout: layout)

        // then
        XCTAssertEqual(sut.commandBarPanelFrame, CGRect(x: 1_160, y: 56, width: 680, height: 72))

        sut.close()
    }

    func test_show는_하단입력label과겹치면_commandPanel을상단으로옮긴다() {
        // given
        let screen = OverlayScreenDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            scaleFactor: 2
        )
        let sut = OverlayWindowController(
            screenFrameProvider: { [screen.frame] },
            screenDescriptorProvider: { [screen] },
            keyboardEventTapFactory: { _ in
                FakeOverlayKeyboardEventTap(startResult: true)
            }
        )
        let layout = makeLayout(
            targetFrame: screen.frame,
            localBounds: CGRect(x: 0, y: 0, width: 1440, height: 900),
            labelFrame: CGRect(x: 700, y: 820, width: 32, height: 22)
        )

        // when
        sut.show(layout: layout)

        // then
        XCTAssertEqual(sut.commandBarPanelFrame, CGRect(x: 380, y: 812, width: 680, height: 72))

        sut.close()
    }

    func test_show는_initialStatus가_failure이면_message높이로배치한다() {
        // given
        let screen = OverlayScreenDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            scaleFactor: 2
        )
        let sut = OverlayWindowController(
            screenFrameProvider: { [screen.frame] },
            screenDescriptorProvider: { [screen] },
            keyboardEventTapFactory: { _ in
                FakeOverlayKeyboardEventTap(startResult: true)
            }
        )

        // when
        sut.show(
            layout: makeLayout(),
            initialStatus: OverlayInteractionStatus(phase: .failure),
            onPresentationEvent: { _ in }
        )

        // then
        XCTAssertEqual(sut.commandBarPanelFrame, CGRect(x: 380, y: 16, width: 680, height: 88))

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

    func test_OverlayKeyboardEventTapContext_연속입력은_FIFO순서로_전달한다() {
        // given
        let expectation = expectation(description: "keyboard commands delivered")
        expectation.expectedFulfillmentCount = 2
        var receivedCommands: [FocusKeyboardCommand] = []
        let sut = OverlayKeyboardEventTapContext { command in
            receivedCommands.append(command)
            expectation.fulfill()
        }
        let labelEvent = CGEvent(keyboardEventSource: nil, virtualKey: 3, keyDown: true)!
        let confirmEvent = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true)!

        // when
        _ = sut.handle(type: .keyDown, event: labelEvent)
        _ = sut.handle(type: .keyDown, event: confirmEvent)
        wait(for: [expectation], timeout: 1)

        // then
        XCTAssertEqual(receivedCommands, [.typeLabel("F"), .dryRunConfirm])
    }

    func test_OverlayKeyboardEventTapContext_stop후_대기중인입력을_전달하지않는다() {
        // given
        let expectation = expectation(description: "keyboard command is not delivered")
        expectation.isInverted = true
        let sut = OverlayKeyboardEventTapContext { _ in
            expectation.fulfill()
        }
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 3, keyDown: true)!

        // when
        _ = sut.handle(type: .keyDown, event: event)
        sut.stopAcceptingCommands()
        wait(for: [expectation], timeout: 0.1)
    }

    func test_OverlayKeyboardCommandRouter_두번째_bareLabel도_label명령으로_유지한다() {
        // given
        var sut = OverlayKeyboardCommandRouter()

        // when
        let first = sut.command(for: FocusKeyboardInput(keyCode: 3, charactersIgnoringModifiers: "F"))
        let second = sut.command(for: FocusKeyboardInput(keyCode: 0, charactersIgnoringModifiers: "A"))

        // then
        XCTAssertEqual(first, .typeLabel("F"))
        XCTAssertEqual(second, .typeLabel("A"))
    }

    func test_OverlayKeyboardCommandRouter_scopePin후_query를_유지한다() {
        // given
        var sut = OverlayKeyboardCommandRouter()

        // when
        let pin = sut.command(for: FocusKeyboardInput(keyCode: 41, charactersIgnoringModifiers: "/"))
        let first = sut.command(for: FocusKeyboardInput(keyCode: 3, charactersIgnoringModifiers: "f"))
        let second = sut.command(for: FocusKeyboardInput(keyCode: 2, charactersIgnoringModifiers: "d"))

        // then
        XCTAssertEqual(pin, .pinScope(.elements))
        XCTAssertEqual(first, .appendQuery("f"))
        XCTAssertEqual(second, .appendQuery("d"))
    }

    func test_OverlayKeyboardCommandRouter_windowScopePin후_query를_유지한다() {
        // given
        var sut = OverlayKeyboardCommandRouter()

        // when
        let pin = sut.command(for: FocusKeyboardInput(keyCode: 41, charactersIgnoringModifiers: ";"))
        let first = sut.command(for: FocusKeyboardInput(keyCode: 8, charactersIgnoringModifiers: "c"))
        let second = sut.command(for: FocusKeyboardInput(keyCode: 31, charactersIgnoringModifiers: "o"))

        // then
        XCTAssertEqual(pin, .pinScope(.windows))
        XCTAssertEqual(first, .appendQuery("c"))
        XCTAssertEqual(second, .appendQuery("o"))
    }

    func test_OverlayKeyboardCommandRouter_두_capture경로는_동일한_commandSequence를_만든다() {
        // given
        let inputs = [
            FocusKeyboardInput(keyCode: 3, charactersIgnoringModifiers: "F"),
            FocusKeyboardInput(keyCode: 0, charactersIgnoringModifiers: "A"),
            FocusKeyboardInput(keyCode: 36)
        ]
        var eventTapRouter = OverlayKeyboardCommandRouter()
        var panelRouter = OverlayKeyboardCommandRouter()

        // when
        let eventTapCommands = inputs.compactMap { eventTapRouter.command(for: $0) }
        let panelCommands = inputs.compactMap { panelRouter.command(for: $0) }

        // then
        XCTAssertEqual(eventTapCommands, [.typeLabel("F"), .typeLabel("A"), .dryRunConfirm])
        XCTAssertEqual(panelCommands, eventTapCommands)
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

    func test_OverlayKeyboardEventTap_start는_inputMonitoring권한이_없으면_요청하지않고_false() {
        // given
        let sut = OverlayKeyboardEventTap(
            isSecureEventInputEnabled: { false },
            hasListenEventAccess: { false },
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

    func test_OverlayKeyboardCommandRouter_syncKeyboardState는_범위상태를_교체한다() {
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

    private func makeLayout(
        targetFrame: CGRect = CGRect(x: 0, y: 0, width: 200, height: 120),
        localBounds: CGRect = CGRect(x: 0, y: 0, width: 200, height: 120),
        labelFrame: CGRect = CGRect(x: 20, y: 20, width: 32, height: 22)
    ) -> OverlayLayout {
        OverlayLayout(
            targetFrame: targetFrame,
            localBounds: localBounds,
            labels: [
                OverlayLabel(
                    id: 0,
                    text: "AA",
                    candidateFrame: CGRect(x: 20, y: 20, width: 30, height: 20),
                    labelFrame: labelFrame,
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
