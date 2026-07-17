import CoreGraphics
import Foundation
import XCTest
@testable import GazeRow

/// AX scan 실행 경계의 값 모델을 검증한다.
///
/// @author suho.do
/// @since 2026-07-17
final class AccessibilityScanExecutionTests: XCTestCase {

    func test_request는_AX객체와원문앱명창제목없이_대상식별값만_보관한다() {
        // given
        let activationID = UUID()
        let context = TargetContext(
            application: TargetApplication(
                localizedName: "Private App Name",
                bundleIdentifier: "com.example.target",
                processIdentifier: 123
            ),
            window: TargetWindow(
                frame: CGRect(x: 10, y: 20, width: 300, height: 200),
                title: "Private Window Title"
            ),
            resolvedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        // when
        let sut = AccessibilityScanRequest(
            activationID: activationID,
            context: context,
            configuration: AccessibilityScanConfiguration(maxDepth: 12, maxNodes: 500, timeout: 0.8)
        )

        // then
        XCTAssertEqual(sut.activationID, activationID)
        XCTAssertEqual(sut.target.processIdentifier, 123)
        XCTAssertEqual(sut.target.bundleIdentifier, "com.example.target")
        XCTAssertEqual(sut.target.windowFrame, context.window.frame)
        XCTAssertEqual(sut.configuration, AccessibilityScanConfiguration(maxDepth: 12, maxNodes: 500, timeout: 0.8))
        XCTAssertFalse(String(describing: sut).contains("Private"))
    }

    func test_response는_activationID와_성공결과를_함께보존한다() {
        // given
        let activationID = UUID()
        let result = AccessibilityScanResult(
            candidates: [],
            nodesVisited: 42,
            scanDuration: 0.2,
            didHitDepthLimit: false,
            didHitNodeLimit: false,
            didTimeout: false,
            failedChildReadCount: 0
        )

        // when
        let sut = AccessibilityScanResponse(
            activationID: activationID,
            outcome: .success(result)
        )

        // then
        XCTAssertEqual(sut.activationID, activationID)
        XCTAssertEqual(sut.outcome, .success(result))
    }
}
