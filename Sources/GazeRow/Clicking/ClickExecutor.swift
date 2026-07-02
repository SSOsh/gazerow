/// keyboard-confirmed click을 실행한다.
///
/// AXPress를 우선 사용하고, 좌표 fallback은 configuration에서 명시적으로 켠 경우에만 사용한다.
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

        guard target.actions.contains(AccessibilityAction.press) else {
            return .failure(.missingPressAction)
        }

        let riskClass = riskClassifier.classify(target)

        if configuration.requiresSecondConfirmForRiskyAction,
           riskClass.requiresSecondConfirm,
           !request.isSecondConfirmProvided {
            return .failure(.secondConfirmRequired(riskClass: riskClass))
        }

        switch client.performAXPress(on: target.element) {
        case .success:
            return .success(
                ClickExecutionSuccess(
                    method: .axPress,
                    riskClass: riskClass,
                    fallbackUsed: false
                )
            )
        case .failure(let reason):
            return handleAXPressFailure(reason: reason, target: target, riskClass: riskClass)
        }
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
