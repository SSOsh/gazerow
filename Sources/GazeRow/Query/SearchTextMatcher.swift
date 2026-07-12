import Foundation

/// Query Overlay 검색 문자열 정규화와 느슨한 매칭.
///
/// exact/prefix/contains를 우선하고, 약어(acronym)와 순서 기반(subsequence)
/// 매칭은 낮은 점수로만 사용해 기존 정확 매칭의 우선순위를 유지한다.
///
/// @author suho.do
/// @since 2026-07-12
enum SearchTextMatchKind: Equatable {
    case exact
    case prefix
    case contains
    case acronym
    case subsequence
}

enum SearchTextMatcher {

    static func normalized(_ value: String) -> String {
        value
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    static func match(value: String, query: String) -> SearchTextMatchKind? {
        let normalizedValue = normalized(value)
        let normalizedQuery = normalized(query)
        guard !normalizedValue.isEmpty, !normalizedQuery.isEmpty else {
            return nil
        }

        if normalizedValue == normalizedQuery {
            return .exact
        }
        if normalizedValue.hasPrefix(normalizedQuery) {
            return .prefix
        }
        if normalizedValue.contains(normalizedQuery) {
            return .contains
        }

        let compactValue = compact(normalizedValue)
        let compactQuery = compact(normalizedQuery)
        guard !compactValue.isEmpty, !compactQuery.isEmpty else {
            return nil
        }

        if compactValue.hasPrefix(compactQuery) || compactValue.contains(compactQuery) {
            return .contains
        }
        if acronym(normalizedValue) == compactQuery {
            return .acronym
        }
        if compactValue.isSubsequence(matching: compactQuery) {
            return .subsequence
        }

        return nil
    }

    private static func compact(_ value: String) -> String {
        value.filter { $0.isLetter || $0.isNumber }
    }

    private static func acronym(_ value: String) -> String {
        value
            .split { !$0.isLetter && !$0.isNumber }
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }
}

private extension String {
    func isSubsequence(matching query: String) -> Bool {
        var currentIndex = startIndex

        for character in query {
            guard let foundIndex = self[currentIndex...].firstIndex(of: character) else {
                return false
            }
            currentIndex = index(after: foundIndex)
        }

        return true
    }
}
