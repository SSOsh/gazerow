import AppKit
import XCTest
@testable import GazeRow

/// overlayActivationMonitorRoute 순수 함수 단위 테스트.
///
/// NSEvent monitor가 activation 입력을 Carbon로 일원화하기 위해 `showOverlay`를 직접
/// 호출하지 않고 소비(consume)만 하는지 검증한다.
///
/// @author suho.do
/// @since 2026-07-05
final class OverlayActivationMonitorRouteTests: XCTestCase {

    private let spaceInput = OverlayActivationShortcutInput(
        keyCode: OverlayActivationKeyCode.space,
        modifiers: []
    )

    func test_gaze_매칭이면_gaze_라우팅() {
        // given
        let input = spaceInput

        // when
        let route = overlayActivationMonitorRoute(
            for: input,
            gazeMatcher: { _ in true },
            overlayMatcher: { _ in false }
        )

        // then
        XCTAssertEqual(route, .gaze)
    }

    func test_overlay_activation_매칭이면_소비만_수행() {
        // given
        let input = spaceInput

        // when
        let route = overlayActivationMonitorRoute(
            for: input,
            gazeMatcher: { _ in false },
            overlayMatcher: { _ in true }
        )

        // then: showOverlay로 이어지지 않고 이벤트만 소비한다(중복 activation 제거).
        XCTAssertEqual(route, .consumeOverlayActivation)
    }

    func test_어느_activation에도_매칭되지_않으면_windowControl() {
        // given
        let input = spaceInput

        // when
        let route = overlayActivationMonitorRoute(
            for: input,
            gazeMatcher: { _ in false },
            overlayMatcher: { _ in false }
        )

        // then
        XCTAssertEqual(route, .windowControl)
    }

    func test_gaze와_overlay가_동시_매칭이면_gaze_우선() {
        // given
        let input = spaceInput

        // when
        let route = overlayActivationMonitorRoute(
            for: input,
            gazeMatcher: { _ in true },
            overlayMatcher: { _ in true }
        )

        // then
        XCTAssertEqual(route, .gaze)
    }

    func test_기본_matcher로_ControlOptionCommandSpace는_activation_소비() {
        // given
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.control, .option, .command]
        )

        // when
        let route = overlayActivationMonitorRoute(for: input)

        // then
        XCTAssertEqual(route, .consumeOverlayActivation)
    }

    func test_기본_matcher로_CommandShiftSpace는_activation_소비() {
        // given
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.command, .shift]
        )

        // when
        let route = overlayActivationMonitorRoute(for: input)

        // then
        XCTAssertEqual(route, .consumeOverlayActivation)
    }

    func test_기본_matcher로_ControlShiftSpace는_gaze() {
        // given
        let input = OverlayActivationShortcutInput(
            keyCode: OverlayActivationKeyCode.space,
            modifiers: [.control, .shift]
        )

        // when
        let route = overlayActivationMonitorRoute(for: input)

        // then
        XCTAssertEqual(route, .gaze)
    }

    func test_기본_matcher로_activation이_아닌_입력은_windowControl() {
        // given: Control+Option+C(윈도우 닫기 계열) 같은 비-activation 입력
        let input = OverlayActivationShortcutInput(
            keyCode: 8,
            modifiers: [.control, .option]
        )

        // when
        let route = overlayActivationMonitorRoute(for: input)

        // then
        XCTAssertEqual(route, .windowControl)
    }
}
