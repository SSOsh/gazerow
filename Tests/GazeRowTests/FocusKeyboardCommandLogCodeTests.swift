import XCTest
@testable import GazeRow

/// keyboard command trace code를 검증한다.
///
/// @author suho.do
/// @since 2026-07-17
final class FocusKeyboardCommandLogCodeTests: XCTestCase {

    func test_logCode는_associatedValue원문없이_command종류만반환한다() {
        // given
        let cases: [(FocusKeyboardCommand, String)] = [
            (.move(.next), "move"),
            (.typeLabel("Z"), "type_label"),
            (.appendQuery("private-query"), "append_query"),
            (.deleteQueryCharacter, "delete_query_character"),
            (.clearQueryBuffer, "clear_query_buffer"),
            (.clearLabelBuffer, "clear_label_buffer"),
            (.pinScope(.elements), "pin_scope"),
            (.selectScope(.windows), "select_scope"),
            (.cycleMatch(forward: true), "cycle_match"),
            (.dryRunConfirm, "confirm"),
            (.closeOverlay, "close_overlay")
        ]

        // when
        let codes = cases.map { ($0.0.logCode, $0.1) }

        // then
        for (actual, expected) in codes {
            XCTAssertEqual(actual, expected)
        }
        XCTAssertFalse(codes.map(\.0).contains("private-query"))
    }
}
