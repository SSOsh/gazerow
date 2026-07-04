import Foundation

/// AX snapshot을 overlay/click 후보로 볼 수 있는지 판정한다.
///
/// Finder sidebar와 VS Code Activity Bar처럼 AXPress 없이 row/cell/image로만
/// 노출되는 UI도 label 후보로 수집하되, 실제 click 실행 정책은 별도로 둔다.
///
/// @author suho.do
/// @since 2026-07-02
struct AccessibilityClickabilityPolicy {

    func isClickable(_ snapshot: AccessibilityElementSnapshot) -> Bool {
        if hasClickAction(snapshot.actions) {
            return true
        }

        if snapshot.role == AccessibilityRole.image {
            return hasSemanticText(
                title: snapshot.title,
                value: snapshot.value,
                help: snapshot.help
            )
        }

        return isClickableRole(snapshot.role)
    }

    func hasClickAction(_ actions: [String]) -> Bool {
        actions.contains(AccessibilityAction.press)
            || actions.contains(AccessibilityAction.confirm)
            || actions.contains(AccessibilityAction.open)
            || actions.contains(AccessibilityAction.showDefaultUI)
    }

    func hasSemanticText(title: String?, value: String?, help: String?) -> Bool {
        hasText(title)
            || hasText(value)
            || hasText(help)
    }

    func isClickableRole(_ role: String?) -> Bool {
        clickableRoles.contains(role ?? "")
    }

    private func hasText(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var clickableRoles: Set<String> {
        [
            AccessibilityRole.button,
            AccessibilityRole.cell,
            AccessibilityRole.checkBox,
            AccessibilityRole.comboBox,
            AccessibilityRole.disclosureTriangle,
            AccessibilityRole.image,
            AccessibilityRole.link,
            AccessibilityRole.menuButton,
            AccessibilityRole.popUpButton,
            AccessibilityRole.radioButton,
            AccessibilityRole.row,
            AccessibilityRole.slider,
            AccessibilityRole.tabGroup,
            AccessibilityRole.textField
        ]
    }
}
