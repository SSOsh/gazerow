import XCTest
@testable import GazeRow

/// AccessibilityRootElementSelector 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
final class AccessibilityRootElementSelectorTests: XCTestCase {

    func test_select_focusedWindow가_성공하면_우선_반환() {
        // given
        let sut = AccessibilityRootElementSelector<Int>()

        // when
        let result = sut.select(
            focusedWindow: .success(1),
            mainWindow: .success(2),
            windows: [3],
            isUsable: { _ in true }
        )

        // then
        XCTAssertEqual(try result.get(), 1)
    }

    func test_select_focusedWindow가_실패하면_mainWindow를_반환() {
        // given
        let sut = AccessibilityRootElementSelector<Int>()

        // when
        let result = sut.select(
            focusedWindow: .failure(.focusedWindowUnavailable("focused missing")),
            mainWindow: .success(2),
            windows: [3],
            isUsable: { _ in true }
        )

        // then
        XCTAssertEqual(try result.get(), 2)
    }

    func test_select_mainWindow도_실패하면_첫번째_usableWindow를_반환() {
        // given
        let sut = AccessibilityRootElementSelector<Int>()

        // when
        let result = sut.select(
            focusedWindow: .failure(.focusedWindowUnavailable("focused missing")),
            mainWindow: .failure(.focusedWindowUnavailable("main missing")),
            windows: [1, 2, 3],
            isUsable: { $0 > 1 }
        )

        // then
        XCTAssertEqual(try result.get(), 2)
    }

    func test_select_fallback이_없으면_focusedWindow_실패를_반환() {
        // given
        let sut = AccessibilityRootElementSelector<Int>()

        // when
        let result = sut.select(
            focusedWindow: .failure(.focusedWindowUnavailable("focused missing")),
            mainWindow: .failure(.focusedWindowUnavailable("main missing")),
            windows: [1],
            isUsable: { _ in false }
        )

        // then
        XCTAssertEqual(result.failureValue, .focusedWindowUnavailable("focused missing"))
    }
}

private extension Result where Failure == AccessibilityScanFailure {
    var failureValue: AccessibilityScanFailure? {
        if case .failure(let failure) = self {
            return failure
        }
        return nil
    }
}
