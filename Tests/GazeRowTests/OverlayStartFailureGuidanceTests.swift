import CoreGraphics
import XCTest
@testable import GazeRow

/// OverlayStartFailureGuidance 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-05
final class OverlayStartFailureGuidanceTests: XCTestCase {

    func test_focusedWindowUnavailable_한국어는_대상창_클릭후_재시도를_안내한다() {
        // given
        let failure = OverlaySessionStartFailure.targetResolutionFailed(
            .focusedWindowUnavailable(bundleIdentifier: "com.apple.controlcenter", reason: "no window")
        )

        // when
        let sut = OverlayStartFailureGuidance(failure: failure, language: .korean)

        // then
        XCTAssertEqual(sut.title, "오버레이를 띄울 창을 찾지 못했습니다")
        XCTAssertTrue(sut.message.contains("클릭하려는 앱 창을 한 번 클릭"))
        XCTAssertTrue(sut.message.contains("Control Center"))
    }

    func test_sessionDisabled_영어는_Enable_GazeRow를_안내한다() {
        // given
        let failure = OverlaySessionStartFailure.sessionDisabled

        // when
        let sut = OverlayStartFailureGuidance(failure: failure, language: .english)

        // then
        XCTAssertEqual(sut.title, "GazeRow is disabled")
        XCTAssertTrue(sut.message.contains("Enable GazeRow"))
    }

    func test_noCandidates_한국어는_클릭가능요소_없음을_설명한다() {
        // given
        let failure = OverlaySessionStartFailure.noCandidates(
            context: TargetContext(
                application: TargetApplication(
                    localizedName: "Finder",
                    bundleIdentifier: "com.apple.finder",
                    processIdentifier: 100
                ),
                window: TargetWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100), title: nil),
                resolvedAt: Date(timeIntervalSince1970: 0)
            ),
            scanResult: AccessibilityScanResult(
                candidates: [],
                nodesVisited: 1,
                scanDuration: 0.01,
                didHitDepthLimit: false,
                didHitNodeLimit: false,
                didTimeout: false,
                failedChildReadCount: 0
            )
        )

        // when
        let sut = OverlayStartFailureGuidance(failure: failure, language: .korean)

        // then
        XCTAssertEqual(sut.title, "선택 가능한 요소가 없습니다")
        XCTAssertTrue(sut.message.contains("클릭 가능한 UI 요소"))
    }
}
