import Foundation

/// window overview 라벨 입력의 순수 해석 결과.
///
/// @author suho.do
/// @since 2026-07-26
enum OverlayWindowLabelSelection: Equatable {
    case partial(buffer: String)
    case exact(index: Int)
    case noMatch
}

/// window overview 라벨을 검색 query와 분리해 해석한다.
///
/// @author suho.do
/// @since 2026-07-26
struct OverlayWindowLabelSelector {
    func select(
        appending grapheme: String,
        to currentBuffer: String,
        labels: [String]
    ) -> OverlayWindowLabelSelection {
        guard grapheme.count == 1,
              let character = grapheme.uppercased().first,
              character.isASCII,
              character.isLetter else {
            return .noMatch
        }

        let candidate = currentBuffer.uppercased() + String(character)
        if let index = labels.firstIndex(of: candidate) {
            return .exact(index: index)
        }

        return labels.contains(where: { $0.hasPrefix(candidate) })
            ? .partial(buffer: candidate)
            : .noMatch
    }
}

/// window overview의 행·열 기준 keyboard focus 이동을 계산한다.
///
/// @author suho.do
/// @since 2026-07-26
struct OverlayWindowOverviewNavigation {
    func index(
        after command: FocusMoveCommand,
        currentIndex: Int,
        itemCount: Int
    ) -> Int {
        guard itemCount > 0 else {
            return 0
        }

        let safeIndex = min(max(0, currentIndex), itemCount - 1)
        let columnCount = preferredColumnCount(itemCount: itemCount)
        switch command {
        case .next, .right:
            return (safeIndex + 1) % itemCount
        case .previous, .left:
            return (safeIndex - 1 + itemCount) % itemCount
        case .up:
            return max(0, safeIndex - columnCount)
        case .down:
            return min(itemCount - 1, safeIndex + columnCount)
        }
    }

    private func preferredColumnCount(itemCount: Int) -> Int {
        min(itemCount, itemCount <= 6 ? 3 : 4)
    }
}
