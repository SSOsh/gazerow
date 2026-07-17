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

    /// child-like 속성을 한 번에 읽고, batch 호출 자체가 실패할 때만 속성별 조회로 폴백한다.
    ///
    /// AX API는 지원하지 않는 개별 속성을 결과 배열의 error value로 돌려줄 수 있으므로,
    /// production batch reader가 유효한 element 배열만 추려 성공으로 반환한다. 전체 batch
    /// 호출을 지원하지 않는 앱에서는 기존 속성별 수집 경로로 coverage를 유지한다.
    func collect(
        readBatch: ([String]) -> Result<[Element], AccessibilityScanFailure>,
        fallbackReadElements: (String) -> Result<[Element], AccessibilityScanFailure>
    ) -> Result<[Element], AccessibilityScanFailure> {
        switch readBatch(attributes) {
        case .success(let elements):
            return .success(elements)
        case .failure:
            return collect(readElements: fallbackReadElements)
        }
    }

    private static var defaultAttributes: [String] {
        [
            "AXContents",
            "AXVisibleChildren",
            "AXChildren",
            "AXChildrenInNavigationOrder",
            "AXVisibleRows",
            "AXRows",
            "AXColumns",
            "AXTabs",
            "AXSelectedChildren",
            "AXSelectedRows"
        ]
    }
}
