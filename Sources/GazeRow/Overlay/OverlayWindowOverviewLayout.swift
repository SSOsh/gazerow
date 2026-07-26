import CoreGraphics

/// 전체 화면 window overview의 adaptive grid 배치 값.
///
/// @author suho.do
/// @since 2026-07-26
struct OverlayWindowOverviewLayout: Equatable {
    let columnCount: Int
    let rowCount: Int
    let cardSize: CGSize
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
}

/// 화면 폭과 후보 수에 맞춰 window overview의 grid 크기를 계산한다.
///
/// @author suho.do
/// @since 2026-07-26
struct OverlayWindowOverviewLayoutEngine {
    private let minimumCardWidth: CGFloat
    private let maximumColumnCount: Int
    private let horizontalInset: CGFloat
    private let horizontalSpacing: CGFloat
    private let verticalSpacing: CGFloat
    private let cardAspectRatio: CGFloat

    init(
        minimumCardWidth: CGFloat = 260,
        maximumColumnCount: Int = 4,
        horizontalInset: CGFloat = 64,
        horizontalSpacing: CGFloat = 24,
        verticalSpacing: CGFloat = 22,
        cardAspectRatio: CGFloat = 1.56
    ) {
        self.minimumCardWidth = max(1, minimumCardWidth)
        self.maximumColumnCount = max(1, maximumColumnCount)
        self.horizontalInset = max(0, horizontalInset)
        self.horizontalSpacing = max(0, horizontalSpacing)
        self.verticalSpacing = max(0, verticalSpacing)
        self.cardAspectRatio = max(0.1, cardAspectRatio)
    }

    func makeLayout(itemCount: Int, availableSize: CGSize) -> OverlayWindowOverviewLayout {
        let safeItemCount = max(0, itemCount)
        let columnCount = columnCount(
            itemCount: safeItemCount,
            availableWidth: max(0, availableSize.width)
        )
        let contentWidth = max(0, availableSize.width - horizontalInset * 2)
        let totalSpacing = horizontalSpacing * CGFloat(max(0, columnCount - 1))
        let cardWidth = max(1, (contentWidth - totalSpacing) / CGFloat(columnCount))
        let rowCount = safeItemCount == 0
            ? 0
            : Int(ceil(Double(safeItemCount) / Double(columnCount)))

        return OverlayWindowOverviewLayout(
            columnCount: columnCount,
            rowCount: rowCount,
            cardSize: CGSize(width: cardWidth, height: cardWidth / cardAspectRatio),
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )
    }

    private func columnCount(itemCount: Int, availableWidth: CGFloat) -> Int {
        guard itemCount > 0 else {
            return 1
        }

        let usableWidth = max(1, availableWidth - horizontalInset * 2)
        let widthCapacity = max(
            1,
            Int((usableWidth + horizontalSpacing) / (minimumCardWidth + horizontalSpacing))
        )
        let preferredMaximum = itemCount <= 6 ? 3 : maximumColumnCount
        return min(itemCount, widthCapacity, preferredMaximum)
    }
}
