/// overlay label 문자열을 생성한다.
///
/// @author suho.do
/// @since 2026-07-02
struct LabelGenerator: Equatable {
    private let alphabet: [Character]

    init(alphabet: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ") {
        self.alphabet = Array(alphabet.isEmpty ? "ABCDEFGHIJKLMNOPQRSTUVWXYZ" : alphabet)
    }

    func labels(count: Int) -> [String] {
        guard count > 0 else {
            return []
        }

        let width = labelWidth(for: count)
        return (0..<count).map { fixedWidthLabel(for: $0, width: width) }
    }

    func label(for index: Int) -> String {
        guard index >= 0 else {
            return ""
        }

        var value = index
        var characters: [Character] = []

        repeat {
            characters.insert(alphabet[value % alphabet.count], at: 0)
            value = (value / alphabet.count) - 1
        } while value >= 0

        return String(characters)
    }

    private func labelWidth(for count: Int) -> Int {
        var capacity = alphabet.count
        var width = 1

        while count > capacity {
            width += 1
            capacity *= alphabet.count
        }

        return width
    }

    private func fixedWidthLabel(for index: Int, width: Int) -> String {
        var value = index
        var characters = Array(repeating: alphabet[0], count: width)

        for position in stride(from: width - 1, through: 0, by: -1) {
            characters[position] = alphabet[value % alphabet.count]
            value /= alphabet.count
        }

        return String(characters)
    }
}
