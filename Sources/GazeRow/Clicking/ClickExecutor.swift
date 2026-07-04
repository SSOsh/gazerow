/// keyboard-confirmed click을 실행한다.
///
/// 기본적으로 AXPress를 우선 사용한다.
/// 오버레이 확정 클릭은 AXPress 성공 후에도 실제 UI 반응이 없는 앱을 위해 좌표 클릭을 우선할 수 있다.
///
/// @author suho.do
/// @since 2026-07-02
struct ClickExecutor<Client: ClickExecutionClient> {
    private let client: Client
    private let configuration: ClickExecutionConfiguration
    private let riskClassifier: ClickRiskClassifier

    init(
        client: Client,
        configuration: ClickExecutionConfiguration = ClickExecutionConfiguration(),
        riskClassifier: ClickRiskClassifier = ClickRiskClassifier()
    ) {
        self.client = client
        self.configuration = configuration
        self.riskClassifier = riskClassifier
    }

    func execute(
        _ request: ClickExecutionRequest<Client.Element>
    ) -> Result<ClickExecutionSuccess, ClickExecutionFailure> {
        let target = request.target

        let riskClass = riskClassifier.classify(target)

        guard let action = preferredAccessibilityAction(for: target) else {
            guard configuration.isCoordinateFallbackEnabled else {
                return .failure(.missingPressAction)
            }

            return executeCoordinateClick(target: target, riskClass: riskClass)
        }

        if configuration.requiresSecondConfirmForRiskyAction,
           riskClass.requiresSecondConfirm,
           !request.isSecondConfirmProvided {
            return .failure(.secondConfirmRequired(riskClass: riskClass))
        }

        if shouldPreferCoordinateClick(for: target) {
            return executeCoordinateClick(target: target, riskClass: riskClass)
        }

        switch client.performAXAction(action, on: target.element) {
        case .success:
            return .success(
                ClickExecutionSuccess(
                    method: executionMethod(for: action),
                    riskClass: riskClass,
                    fallbackUsed: false
                )
            )
        case .failure(let reason):
            return handleAXPressFailure(reason: reason, target: target, riskClass: riskClass)
        }
    }

    private func preferredAccessibilityAction(for target: ClickTarget<Client.Element>) -> String? {
        if target.actions.contains(AccessibilityAction.press) {
            return AccessibilityAction.press
        }

        if target.actions.contains(AccessibilityAction.confirm) {
            return AccessibilityAction.confirm
        }

        if target.actions.contains(AccessibilityAction.open) {
            return AccessibilityAction.open
        }

        if target.actions.contains(AccessibilityAction.showDefaultUI) {
            return AccessibilityAction.showDefaultUI
        }

        return nil
    }

    private func executionMethod(for action: String) -> ClickExecutionMethod {
        if action == AccessibilityAction.press {
            return .axPress
        }

        return .accessibilityAction(action)
    }

    private func handleAXPressFailure(
        reason: String,
        target: ClickTarget<Client.Element>,
        riskClass: ClickRiskClass
    ) -> Result<ClickExecutionSuccess, ClickExecutionFailure> {
        guard configuration.isCoordinateFallbackEnabled else {
            return .failure(.coordinateFallbackDisabled(axFailureReason: reason))
        }

        return executeCoordinateClick(target: target, riskClass: riskClass)
    }

    private func shouldPreferCoordinateClick(for target: ClickTarget<Client.Element>) -> Bool {
        if configuration.prefersCoordinateClickForAllTargets,
           configuration.isCoordinateFallbackEnabled {
            return true
        }

        return configuration.prefersCoordinateClickForUntitledSmallButtons
            && configuration.isCoordinateFallbackEnabled
            && target.role == AccessibilityRole.button
            && (target.title == nil || target.title?.isEmpty == true)
            && target.frame.width <= 44
            && target.frame.height <= 44
            && target.actions.contains(AccessibilityAction.press)
    }

    private func executeCoordinateClick(
        target: ClickTarget<Client.Element>,
        riskClass: ClickRiskClass
    ) -> Result<ClickExecutionSuccess, ClickExecutionFailure> {
        switch client.performCoordinateClick(at: target.centerPoint) {
        case .success:
            return .success(
                ClickExecutionSuccess(
                    method: .coordinateFallback,
                    riskClass: riskClass,
                    fallbackUsed: true
                )
            )
        case .failure(let fallbackReason):
            return .failure(.coordinateFallbackFailed(reason: fallbackReason))
        }
    }
}
