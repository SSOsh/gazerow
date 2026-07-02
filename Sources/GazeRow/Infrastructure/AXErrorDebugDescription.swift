import ApplicationServices

/// AXError debug용 설명.
///
/// @author suho.do
/// @since 2026-07-02
extension AXError {
    var localizedDebugDescription: String {
        switch self {
        case .success:
            "success"
        case .failure:
            "failure"
        case .illegalArgument:
            "illegal argument"
        case .invalidUIElement:
            "invalid UI element"
        case .invalidUIElementObserver:
            "invalid UI element observer"
        case .cannotComplete:
            "cannot complete"
        case .attributeUnsupported:
            "attribute unsupported"
        case .actionUnsupported:
            "action unsupported"
        case .notificationUnsupported:
            "notification unsupported"
        case .notImplemented:
            "not implemented"
        case .notificationAlreadyRegistered:
            "notification already registered"
        case .notificationNotRegistered:
            "notification not registered"
        case .apiDisabled:
            "api disabled"
        case .noValue:
            "no value"
        case .parameterizedAttributeUnsupported:
            "parameterized attribute unsupported"
        case .notEnoughPrecision:
            "not enough precision"
        @unknown default:
            "unknown AX error \(rawValue)"
        }
    }
}
