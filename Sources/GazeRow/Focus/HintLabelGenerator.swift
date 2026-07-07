/// Vimium/Homerow식 prefix-free 가변폭 hint label을 생성한다.
///
/// 홈로우 우선 키셋에서 앞쪽 키를 짧은(1글자) label로, 뒤쪽 키를 2글자 prefix로
/// 써서 대부분의 후보에 1글자를 배정하고 일부만 2글자로 확장한다. 어떤 label도
/// 다른 label의 prefix가 되지 않으므로(prefix-free), 1글자 label은 즉시 확정되고
/// type-to-filter(FocusEngine)와 정합한다.
///
/// @author suho.do
/// @since 2026-07-07
struct HintLabelGenerator: Equatable {
    private let keys: [Character]

    /// 기본 키셋은 홈로우(ASDFGHJKL) → 상단(QWERTYUIOP) → 하단(ZXCVBNM) 순이다.
    init(keys: String = "ASDFGHJKLQWERTYUIOPZXCVBNM") {
        self.keys = Self.normalize(keys)
    }

    func labels(count: Int) -> [String] {
        guard count > 0 else {
            return []
        }

        let k = keys.count

        // 키가 1개뿐이면 prefix-free가 불가능하므로 균일 폭으로만 처리한다.
        guard k >= 2 else {
            return uniformWidthLabels(count: count)
        }

        if count <= k {
            return (0..<count).map { String(keys[$0]) }
        }

        if count <= k * k {
            return mixedWidthLabels(count: count, k: k)
        }

        return uniformWidthLabels(count: count)
    }

    /// 앞쪽 키를 1글자 label로, 뒤쪽 키를 2글자 prefix로 쓰는 혼합 폭 생성.
    ///
    /// `count <= k*k`가 보장되면 `singleCount >= 0`, prefix key가 최소 1개 존재한다.
    private func mixedWidthLabels(count: Int, k: Int) -> [String] {
        let prefixesNeeded = Int((Double(count - k) / Double(k - 1)).rounded(.up))
        let singleCount = k - prefixesNeeded

        var result: [String] = (0..<singleCount).map { String(keys[$0]) }

        for prefixIndex in singleCount..<k {
            for suffix in keys {
                result.append(String(keys[prefixIndex]) + String(suffix))
                if result.count == count {
                    return result
                }
            }
        }

        return result
    }

    /// 모든 label을 같은 길이로 만드는 균일 폭 생성. 동일 길이라 prefix-free다.
    private func uniformWidthLabels(count: Int) -> [String] {
        let k = keys.count

        // 단일 키는 prefix-free가 수학적으로 불가능하므로, 길이를 늘려 고유성만
        // 보장한다. (capacity *= 1이 정체돼 발생하던 무한 루프를 차단)
        guard k >= 2 else {
            return (0..<count).map { String(repeating: keys[0], count: $0 + 1) }
        }

        var width = 1
        var capacity = k

        while capacity < count {
            width += 1
            capacity *= k
        }

        return (0..<count).map { fixedWidthLabel(for: $0, width: width, k: k) }
    }

    private func fixedWidthLabel(for index: Int, width: Int, k: Int) -> String {
        var value = index
        var characters = Array(repeating: keys[0], count: width)

        for position in stride(from: width - 1, through: 0, by: -1) {
            characters[position] = keys[value % k]
            value /= k
        }

        return String(characters)
    }

    private static func normalize(_ raw: String) -> [Character] {
        var seen = Set<Character>()
        var unique: [Character] = []

        for character in raw.uppercased() where character.isLetter && !seen.contains(character) {
            seen.insert(character)
            unique.append(character)
        }

        return unique.isEmpty ? Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ") : unique
    }
}
