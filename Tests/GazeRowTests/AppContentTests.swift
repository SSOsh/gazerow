import XCTest
@testable import GazeRow

/// 사용자 노출 정적 콘텐츠의 평가 결과 반영을 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
final class AppContentTests: XCTestCase {

    func test_appSupport_Ticket010제한앱을_limited로_표시한다() {
        // given
        let supportByName = Dictionary(
            uniqueKeysWithValues: AppContent.appSupport.map { ($0.name, $0.tier) }
        )

        // when & then
        XCTAssertEqual(supportByName["Finder"], .limited)
        XCTAssertEqual(supportByName["VS Code"], .limited)
        XCTAssertEqual(supportByName["Safari"], .supported)
        XCTAssertEqual(supportByName["Chrome"], .supported)
        XCTAssertEqual(supportByName["System Settings"], .supported)
    }

    func test_knownLimitations_Ticket010실패사유를_포함한다() {
        // given
        let limitations = AppContent.knownLimitations.joined(separator: "\n")

        // when & then
        XCTAssertTrue(limitations.contains("Finder sidebar rows need fixed-task reevaluation"))
        XCTAssertTrue(limitations.contains("VS Code Activity Bar items need fixed-task reevaluation"))
    }
}
