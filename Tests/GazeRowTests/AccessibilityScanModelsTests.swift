import XCTest
@testable import GazeRow

/// AccessibilityScanConfiguration 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-12
final class AccessibilityScanModelsTests: XCTestCase {

    func test_ScanConfiguration_기본값은_넓은_AX트리를_수집할_여유를_둔다() {
        // given
        let sut = AccessibilityScanConfiguration()

        // then
        XCTAssertEqual(sut.maxDepth, 28)
        XCTAssertEqual(sut.maxNodes, 4_000)
        XCTAssertEqual(sut.timeout, 1.5)
    }

    func test_ScanConfiguration_음수값은_안전범위로_clamp한다() {
        // given
        let sut = AccessibilityScanConfiguration(maxDepth: -1, maxNodes: -1, timeout: -1)

        // then
        XCTAssertEqual(sut.maxDepth, 0)
        XCTAssertEqual(sut.maxNodes, 1)
        XCTAssertEqual(sut.timeout, 0)
    }
}
