import Foundation

/// AX child-like attribute를 순서대로 읽어 traversal 목록을 찾는다.
///
/// 일부 Electron/WebView 앱은 `AXChildren` 외 attribute에 실제 콘텐츠 트리를 노출한다.
///
/// @author suho.do
/// @since 2026-07-03
struct AccessibilityChildAttributeCollector<Element> {
    private let attributes: [String]

    init(attributes: [String] = AccessibilityChildAttributeCollector.defaultAttributes) {
        self.attributes = attributes
    }

    func collect(
        readElements: (String) -> Result<[Element], AccessibilityScanFailure>
    ) -> Result<[Element], AccessibilityScanFailure> {
        var firstFailure: AccessibilityScanFailure?

        for attribute in attributes {
            switch readElements(attribute) {
            case .success(let elements):
                if !elements.isEmpty {
                    return .success(elements)
                }
            case .failure(let failure):
                if firstFailure == nil {
                    firstFailure = failure
                }
            }
        }

        if let firstFailure {
            return .failure(firstFailure)
        }

        return .success([])
    }

    private static var defaultAttributes: [String] {
        [
            "AXChildren",
            "AXVisibleChildren",
            "AXContents",
            "AXRows"
        ]
    }
}
