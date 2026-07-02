import Foundation

/// scanner root window element 선택 규칙.
///
/// focused window를 우선 사용하고, 실패하면 main window와 usable windows fallback을
/// 순서대로 시도한다.
///
/// @author suho.do
/// @since 2026-07-02
struct AccessibilityRootElementSelector<Element> {

    func select(
        focusedWindow: Result<Element, AccessibilityScanFailure>,
        mainWindow: Result<Element, AccessibilityScanFailure>,
        windows: [Element],
        isUsable: (Element) -> Bool
    ) -> Result<Element, AccessibilityScanFailure> {
        switch focusedWindow {
        case .success(let element):
            return .success(element)
        case .failure(let focusedFailure):
            if case .success(let element) = mainWindow {
                return .success(element)
            }

            if let element = windows.first(where: isUsable) {
                return .success(element)
            }

            return .failure(focusedFailure)
        }
    }
}
