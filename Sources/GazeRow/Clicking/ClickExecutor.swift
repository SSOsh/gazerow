/// keyboard-confirmed click을 실행한다.
///
/// AXPress를 우선 사용하고, 지원 AX action 실패 시 좌표 fallback은 configuration에서 명시적으로 켠 경우에만 사용한다.
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

        guard let action = preferredAccessibilityAction(for: target) else {
            return .failure(.missingPressAction)
        }

        let riskClass = riskClassifier.classify(target)

        if configuration.requiresSecondConfirmForRiskyAction,
           riskClass.requiresSecondConfirm,
           !request.isSecondConfirmProvided {
            return .failure(.secondConfirmRequired(riskClass: riskClass))
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
