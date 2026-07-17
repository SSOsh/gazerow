import Foundation

/// keyboard command를 입력 원문 없는 trace code로 변환한다.
///
/// @author suho.do
/// @since 2026-07-17
extension FocusKeyboardCommand {
    var logCode: String {
        switch self {
        case .move:
            "move"
        case .typeLabel:
            "type_label"
        case .appendQuery:
            "append_query"
        case .deleteQueryCharacter:
            "delete_query_character"
        case .clearQueryBuffer:
            "clear_query_buffer"
        case .clearLabelBuffer:
            "clear_label_buffer"
        case .pinScope:
            "pin_scope"
        case .selectScope:
            "select_scope"
        case .cycleMatch:
            "cycle_match"
        case .dryRunConfirm:
            "confirm"
        case .closeOverlay:
            "close_overlay"
        }
    }
}
