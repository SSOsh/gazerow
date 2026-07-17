import CoreGraphics
import Foundation
import XCTest
@testable import GazeRow

/// 직렬 AX scan runtime의 Sendable event 경계를 검증한다.
///
/// @author suho.do
/// @since 2026-07-17
final class AccessibilityScanRuntimeTests: XCTestCase {

    func test_events는_progress다음_activationID가같은완료응답을전달한다() async {
        // given
        let expectedProgress = AccessibilityScanProgress(
            candidates: [candidate(title: "Open")],
            nodesVisited: 12
        )
        let expectedResult = scanResult(candidates: expectedProgress.candidates)
        let runtime = AccessibilityScanRuntime { _, onProgress in
            onProgress(expectedProgress)
            return .success(expectedResult)
        }
        let request = makeRequest()
        var events: [AccessibilityScanRuntimeEvent] = []

        // when
        for await event in runtime.events(for: request) {
            events.append(event)
        }

        // then
        XCTAssertEqual(
            events,
            [
                .progress(expectedProgress),
                .completed(
                    AccessibilityScanResponse(
                        activationID: request.activationID,
                        outcome: .success(expectedResult)
                    )
                )
            ]
        )
    }

    @MainActor
    func test_AXRuntimeScanner는_runtime부분결과와최종결과를_MainActor에서전달한다() async {
        // given
        let expectedProgress = AccessibilityScanProgress(
            candidates: [candidate(title: "Partial")],
            nodesVisited: 32
        )
        let expectedResult = scanResult(candidates: [candidate(title: "Final")])
        let runtime = AccessibilityScanRuntime { _, onProgress in
            onProgress(expectedProgress)
            return .success(expectedResult)
        }
        let sut = AXRuntimeScanner(runtime: runtime)
        var receivedProgress: [AccessibilityScanProgress] = []

        // when
        let result = await sut.scanProgressively(context: targetContext) { progress in
            MainActor.preconditionIsolated()
            receivedProgress.append(progress)
        }

        // then
        XCTAssertEqual(receivedProgress, [expectedProgress])
        XCTAssertEqual(result, .success(expectedResult))
    }

    private var targetContext: TargetContext {
        TargetContext(
            application: TargetApplication(
                localizedName: "Finder",
                bundleIdentifier: "com.apple.finder",
                processIdentifier: 100
            ),
            window: TargetWindow(
                frame: CGRect(x: 0, y: 0, width: 800, height: 600),
                title: "Finder"
            ),
            resolvedAt: Date(timeIntervalSince1970: 1_788_748_400)
        )
    }

    private func makeRequest() -> AccessibilityScanRequest {
        AccessibilityScanRequest(
            activationID: UUID(),
            context: targetContext
        )
    }

    private func candidate(title: String) -> ClickableCandidate {
        ClickableCandidate(
            role: AccessibilityRole.button,
            subrole: nil,
            title: title,
            frame: CGRect(x: 10, y: 10, width: 80, height: 24),
            actions: [AccessibilityAction.press]
        )
    }

    private func scanResult(candidates: [ClickableCandidate]) -> AccessibilityScanResult {
        AccessibilityScanResult(
            candidates: candidates,
            nodesVisited: 64,
            scanDuration: 0.1,
            didHitDepthLimit: false,
            didHitNodeLimit: false,
            didTimeout: false,
            failedChildReadCount: 0
        )
    }
}
