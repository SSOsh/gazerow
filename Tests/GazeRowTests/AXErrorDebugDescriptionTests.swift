import ApplicationServices
import XCTest
@testable import GazeRow

/// AXError.localizedDebugDescription 매핑 단위 테스트.
///
/// production AX bridge의 오류 설명 문자열이 AXError case별로 정확히 매핑되는지,
/// 정의되지 않은 rawValue가 unknown 경로로 안전하게 떨어지는지 검증한다.
///
/// @author suho.do
/// @since 2026-09-12
final class AXErrorDebugDescriptionTests: XCTestCase {

    func test_정의된_모든_AXError_case가_고정_설명으로_매핑된다() {
        // given
        let expectations: [(AXError, String)] = [
            (.success, "success"),
            (.failure, "failure"),
            (.illegalArgument, "illegal argument"),
            (.invalidUIElement, "invalid UI element"),
            (.invalidUIElementObserver, "invalid UI element observer"),
            (.cannotComplete, "cannot complete"),
            (.attributeUnsupported, "attribute unsupported"),
            (.actionUnsupported, "action unsupported"),
            (.notificationUnsupported, "notification unsupported"),
            (.notImplemented, "not implemented"),
            (.notificationAlreadyRegistered, "notification already registered"),
            (.notificationNotRegistered, "notification not registered"),
            (.apiDisabled, "api disabled"),
            (.noValue, "no value"),
            (.parameterizedAttributeUnsupported, "parameterized attribute unsupported"),
            (.notEnoughPrecision, "not enough precision")
        ]

        // when & then
        for (error, expected) in expectations {
            XCTAssertEqual(error.localizedDebugDescription, expected)
        }
    }

    func test_정의되지_않은_rawValue는_unknown_설명과_rawValue를_포함한다() {
        // given: 정의된 어떤 AXError case에도 해당하지 않는 rawValue (실제 AXError는 0 또는 음수)
        guard let unknown = AXError(rawValue: 999) else {
            XCTFail("예상과 달리 rawValue 999로 AXError를 생성할 수 없었다")
            return
        }

        // when
        let description = unknown.localizedDebugDescription

        // then
        XCTAssertTrue(description.hasPrefix("unknown AX error"))
        XCTAssertTrue(description.contains("999"))
    }
}
