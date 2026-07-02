import Foundation

/// click target의 위험도를 분류한다.
///
/// 원문 title은 저장하지 않고 런타임 분류에만 사용한다.
///
/// @author suho.do
/// @since 2026-07-02
struct ClickRiskClassifier {

    func classify<Element>(_ target: ClickTarget<Element>) -> ClickRiskClass {
        if target.actions.isEmpty {
            return .unknownRisk
        }

        let normalizedTitle = target.title?.lowercased() ?? ""

        if containsAnyKeyword(normalizedTitle, keywords: destructiveKeywords) {
            return .destructive
        }

        if containsAnyKeyword(normalizedTitle, keywords: externalEffectKeywords) {
            return .externalEffect
        }

        if target.role == AccessibilityRole.checkBox
            || target.role == AccessibilityRole.radioButton
            || target.role == AccessibilityRole.slider
            || target.actions.contains(AccessibilityAction.increment)
            || target.actions.contains(AccessibilityAction.decrement) {
            return .stateChange
        }

        if target.actions.contains(AccessibilityAction.press)
            || target.actions.contains(AccessibilityAction.confirm)
            || target.actions.contains(AccessibilityAction.open) {
            return .safeNavigation
        }

        return .unknownRisk
    }

    private func containsAnyKeyword(_ value: String, keywords: [String]) -> Bool {
        keywords.contains { value.contains($0) }
    }

    private var destructiveKeywords: [String] {
        [
            "delete",
            "remove",
            "clear",
            "reset",
            "destroy",
            "erase"
        ]
    }

    private var externalEffectKeywords: [String] {
        [
            "purchase",
            "pay",
            "send",
            "submit",
            "confirm",
            "sign out",
            "logout",
            "log out"
        ]
    }
}
