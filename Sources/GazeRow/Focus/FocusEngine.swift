import CoreGraphics
import Foundation

/// candidate focus 이동과 label jump 상태를 관리한다.
///
/// 실제 click 실행은 TICKET-007에서만 연결한다.
///
/// @author suho.do
/// @since 2026-07-02
struct FocusEngine: Equatable {
    private(set) var items: [FocusItem]
    private(set) var focusedItemID: Int?
    private(set) var labelBuffer = ""

    init(items: [FocusItem], initialFocusedItemID: Int? = nil) {
        self.items = items
        self.focusedItemID = Self.initialFocusID(
            items: items,
            requestedID: initialFocusedItemID
        )
    }

    init(layout: OverlayLayout, initialFocusedItemID: Int? = nil) {
        self.init(
            items: layout.labels.map {
                FocusItem(id: $0.id, label: $0.text, frame: $0.candidateFrame)
            },
            initialFocusedItemID: initialFocusedItemID
        )
    }

    mutating func move(_ command: FocusMoveCommand) -> FocusEngineEvent? {
        guard !items.isEmpty else {
            focusedItemID = nil
            return nil
        }

        let previousID = focusedItemID
        let nextID = nextFocusID(for: command)
        focusedItemID = nextID
        labelBuffer = ""

        return .focusChanged(
            from: previousID,
            to: nextID,
            method: method(for: command)
        )
    }

    mutating func typeLabelCharacter(_ character: Character) -> LabelTypingResult {
        let normalized = String(character).uppercased()

        guard normalized.rangeOfCharacter(from: CharacterSet.letters) != nil else {
            return LabelTypingResult(
                buffer: labelBuffer,
                matchedItemID: nil,
                isExactMatch: false,
                event: nil
            )
        }

        labelBuffer += normalized

        guard let match = exactMatch(for: labelBuffer) else {
            let hasPrefixMatch = items.contains { $0.label.hasPrefix(labelBuffer) }
            if !hasPrefixMatch,
               let suffixMatch = suffixShortcutMatch(for: labelBuffer) {
                focusedItemID = suffixMatch.id
                let typedLabel = labelBuffer
                labelBuffer = ""

                return LabelTypingResult(
                    buffer: labelBuffer,
                    matchedItemID: suffixMatch.id,
                    isExactMatch: true,
                    event: .labelJump(typedLabel: typedLabel, matched: true, to: suffixMatch.id)
                )
            }

            let event: FocusEngineEvent? = hasPrefixMatch
                ? nil
                : .labelJump(typedLabel: labelBuffer, matched: false, to: nil)

            if !hasPrefixMatch {
                labelBuffer = ""
            }

            return LabelTypingResult(
                buffer: labelBuffer,
                matchedItemID: nil,
                isExactMatch: false,
                event: event
            )
        }

        focusedItemID = match.id
        let typedLabel = labelBuffer
        labelBuffer = ""

        return LabelTypingResult(
            buffer: labelBuffer,
            matchedItemID: match.id,
            isExactMatch: true,
            event: .labelJump(typedLabel: typedLabel, matched: true, to: match.id)
        )
    }

    mutating func clearLabelBuffer() {
        labelBuffer = ""
    }

    mutating func focusNearest(to point: CGPoint) -> FocusEngineEvent? {
        guard let nearestItem = GazeFocusController().nearestItem(to: point, in: items) else {
            focusedItemID = nil
            labelBuffer = ""
            return nil
        }

        let previousID = focusedItemID
        focusedItemID = nearestItem.id
        labelBuffer = ""

        return .focusChanged(
            from: previousID,
            to: nearestItem.id,
            method: .gaze
        )
    }

    func dryRunConfirm() -> DryRunConfirmResult {
        DryRunConfirmResult(
            focusedItemID: focusedItemID,
            event: .dryRunConfirm(index: focusedItemID)
        )
    }

    private static func initialFocusID(items: [FocusItem], requestedID: Int?) -> Int? {
        if let requestedID, items.contains(where: { $0.id == requestedID }) {
            return requestedID
        }

        return items.first?.id
    }

    private func nextFocusID(for command: FocusMoveCommand) -> Int {
        switch command {
        case .next:
            return relativeFocusID(step: 1)
        case .previous:
            return relativeFocusID(step: -1)
        case .up:
            return verticalFocusID(searchingDown: false)
        case .down:
            return verticalFocusID(searchingDown: true)
        }
    }

    private func relativeFocusID(step: Int) -> Int {
        guard let focusedIndex = focusedIndex else {
            return items[0].id
        }

        let nextIndex = (focusedIndex + step + items.count) % items.count
        return items[nextIndex].id
    }

    private func verticalFocusID(searchingDown: Bool) -> Int {
        guard let focusedItem else {
            return items[0].id
        }

        let candidates = items.filter { item in
            searchingDown
                ? item.frame.midY > focusedItem.frame.midY
                : item.frame.midY < focusedItem.frame.midY
        }

        guard let best = candidates.min(by: { lhs, rhs in
            verticalDistanceScore(lhs, from: focusedItem) < verticalDistanceScore(rhs, from: focusedItem)
        }) else {
            return focusedItem.id
        }

        return best.id
    }

    private func verticalDistanceScore(_ item: FocusItem, from focusedItem: FocusItem) -> CGFloat {
        let verticalDistance = abs(item.frame.midY - focusedItem.frame.midY)
        let horizontalDistance = abs(item.frame.midX - focusedItem.frame.midX)
        return verticalDistance * 1_000 + horizontalDistance
    }

    private func exactMatch(for buffer: String) -> FocusItem? {
        items.first { $0.label == buffer }
    }

    private func suffixShortcutMatch(for buffer: String) -> FocusItem? {
        guard buffer.count == 1,
              let shortcut = buffer.first else {
            return nil
        }

        return items.first { item in
            item.label.count > 1 && item.label.last == shortcut
        }
    }

    private func method(for command: FocusMoveCommand) -> FocusChangeMethod {
        switch command {
        case .next:
            .tab
        case .previous:
            .shiftTab
        case .up:
            .arrowUp
        case .down:
            .arrowDown
        }
    }

    private var focusedIndex: Int? {
        guard let focusedItemID else {
            return nil
        }

        return items.firstIndex { $0.id == focusedItemID }
    }

    private var focusedItem: FocusItem? {
        guard let focusedItemID else {
            return nil
        }

        return items.first { $0.id == focusedItemID }
    }
}
