/// windows scope 매칭 preview 중 동일 앱의 여러 창을 하나의 요약 row로 묶는다.
///
/// focus된 preview는 항상 단독으로 노출하고, 같은 앱의 나머지 창은
/// "<대표 창 제목> 외 N개 창" 형태의 요약 row 하나로 묶는다.
/// 대표 창은 `recencyRank`(낮을수록 최근/전면 창)가 가장 낮은 창을 고른다.
///
/// @author suho.do
/// @since 2026-07-18
struct OverlayWindowMatchGrouper {

    func grouped(from previews: [OverlayWindowMatchPreview]) -> [OverlayWindowMatchPreview] {
        var appearanceOrder: [String] = []
        var groupsByAppName: [String: [OverlayWindowMatchPreview]] = [:]

        for preview in previews {
            if groupsByAppName[preview.appName] == nil {
                appearanceOrder.append(preview.appName)
            }
            groupsByAppName[preview.appName, default: []].append(preview)
        }

        return appearanceOrder.flatMap { appName in
            rows(for: groupsByAppName[appName] ?? [])
        }
    }

    private func rows(for group: [OverlayWindowMatchPreview]) -> [OverlayWindowMatchPreview] {
        guard group.count > 1 else {
            return group
        }

        var rows: [OverlayWindowMatchPreview] = []
        if let focused = group.first(where: \.isFocused) {
            rows.append(focused)
        }

        let unfocused = group.filter { !$0.isFocused }
        if let representative = unfocused.min(by: { $0.recencyRank < $1.recencyRank }) {
            rows.append(summaryRow(representative: representative, additionalCount: unfocused.count - 1))
        }

        return rows
    }

    private func summaryRow(
        representative: OverlayWindowMatchPreview,
        additionalCount: Int
    ) -> OverlayWindowMatchPreview {
        guard additionalCount > 0 else {
            return representative
        }

        let suffix = " 외 \(additionalCount)개 창"
        let displayName = representative.detailText.isEmpty
            ? "\(representative.appName)\(suffix)"
            : "\(representative.appName) — \(representative.detailText)\(suffix)"

        return OverlayWindowMatchPreview(
            id: representative.id,
            appName: representative.appName,
            displayName: displayName,
            ordinal: representative.ordinal,
            isFocused: false,
            appIcon: representative.appIcon,
            additionalWindowCount: additionalCount
        )
    }
}
