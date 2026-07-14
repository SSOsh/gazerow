import XCTest
@testable import GazeRow

/// QueryScope의 공간/의미 구분 로직을 검증한다.
///
/// @author suho.do
/// @since 2026-07-12
final class QueryScopeTests: XCTestCase {

    func test_isSpatial_labels와elements는_공간겨냥_scope다() {
        // when & then
        XCTAssertTrue(QueryScope.labels.isSpatial)
        XCTAssertTrue(QueryScope.elements.isSpatial)
    }

    func test_isSpatial_windows는_공간겨냥이_아니다() {
        // when & then
        XCTAssertFalse(QueryScope.windows.isSpatial)
    }
}
