import CoreGraphics

/// focus engine 입력 item.
///
/// @author suho.do
/// @since 2026-07-02
struct FocusItem: Equatable, Identifiable {
    let id: Int
    let label: String
    let frame: CGRect

    init(id: Int, label: String, frame: CGRect) {
        self.id = id
        self.label = label.uppercased()
        self.frame = frame
    }
}

/// focus 이동 명령.
///
/// @author suho.do
/// @since 2026-07-02
enum FocusMoveCommand: Equatable {
    case next
    case previous
    case up
    case down
}

/// focus 이동 방식.
///
/// @author suho.do
/// @since 2026-07-02
enum FocusChangeMethod: Equatable {
    case initial
    case tab
    case shiftTab
    case arrowUp
    case arrowDown
    case labelJump
}

/// focus engine 이벤트. TICKET-008의 interaction log 입력으로 쓸 수 있다.
///
/// @author suho.do
/// @since 2026-07-02
enum FocusEngineEvent: Equatable {
    case focusChanged(from: Int?, to: Int, method: FocusChangeMethod)
    case labelJump(typedLabel: String, matched: Bool, to: Int?)
    case dryRunConfirm(index: Int?)
}

/// label typing 처리 결과.
///
/// @author suho.do
/// @since 2026-07-02
struct LabelTypingResult: Equatable {
    let buffer: String
    let matchedItemID: Int?
    let isExactMatch: Bool
    let event: FocusEngineEvent?
}

/// Return 처리 결과. TICKET-006에서는 실제 click 없이 dry-run만 반환한다.
///
/// @author suho.do
/// @since 2026-07-02
struct DryRunConfirmResult: Equatable {
    let focusedItemID: Int?
    let event: FocusEngineEvent
}
