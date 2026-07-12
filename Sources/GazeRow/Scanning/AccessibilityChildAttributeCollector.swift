import Foundation

/// AX child-like attribute를 순서대로 읽어 traversal 목록을 찾는다.
///
/// 일부 Electron/WebView 앱은 `AXChildren`에 toolbar/sidebar를, `AXContents`나
/// `AXVisibleChildren`에 실제 콘텐츠 트리를 따로 노출한다. 그래서 content 계열
/// attribute를 먼저 읽고, 첫 non-empty attribute에서 멈추지 않고 성공한
/// child-like attribute를 모두 합친다.
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
        var collectedElements: [Element] = []

        for attribute in attributes {
            switch readElements(attribute) {
            case .success(let elements):
                collectedElements.append(contentsOf: elements)
            case .failure(let failure):
                if firstFailure == nil {
                    firstFailure = failure
                }
            }
        }

        if !collectedElements.isEmpty {
            return .success(collectedElements)
        }

        if let firstFailure {
            return .failure(firstFailure)
        }

        return .success([])
    }

    private static var defaultAttributes: [String] {
        [
            "AXContents",
            "AXVisibleChildren",
            "AXChildren",
            "AXRows"
        ]
    }
}
