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
        hasClickAction(snapshot)
            || clickableRoles.contains(snapshot.role ?? "")
    }

    private func hasClickAction(_ snapshot: AccessibilityElementSnapshot) -> Bool {
        snapshot.actions.contains(AccessibilityAction.press)
            || snapshot.actions.contains(AccessibilityAction.confirm)
            || snapshot.actions.contains(AccessibilityAction.open)
            || snapshot.actions.contains(AccessibilityAction.showDefaultUI)
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
