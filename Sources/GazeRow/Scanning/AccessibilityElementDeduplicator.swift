import Foundation

/// AX traversal 중 여러 child-like attribute에 중복 노출된 element를 제거한다.
///
/// @author suho.do
/// @since 2026-07-12
struct AccessibilityElementDeduplicator<Element> {
    private let keyProvider: (Element) -> AnyHashable

    init(keyProvider: @escaping (Element) -> AnyHashable) {
        self.keyProvider = keyProvider
    }

    func deduplicated(_ elements: [Element]) -> [Element] {
        var seenKeys = Set<AnyHashable>()
        var result: [Element] = []

        for element in elements {
            let key = keyProvider(element)
            guard seenKeys.insert(key).inserted else {
                continue
            }
            result.append(element)
        }

        return result
    }
}
