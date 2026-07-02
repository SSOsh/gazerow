import CoreGraphics
import Foundation
import XCTest
@testable import GazeRow

/// TargetResolver 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class TargetResolverTests: XCTestCase {

    func resolve_NoFrontmostApplication_ReturnsFailure() {
        // given
        let resolver = TargetResolver(
            frontmostApplicationProvider: StubFrontmostApplicationProvider(application: nil),
            accessibilityClient: StubAccessibilityTargetClient(result: .failure(.permissionDenied))
        )

        // when
        let result = resolver.resolve()

        // then
        XCTAssertEqual(result, .failure(.noFrontmostApplication))
    }

    func resolve_InvalidProcessIdentifier_ReturnsFailure() {
        // given
        let resolver = TargetResolver(
            frontmostApplicationProvider: StubFrontmostApplicationProvider(
                application: TargetApplication(
                    localizedName: "Finder",
                    bundleIdentifier: "com.apple.finder",
                    processIdentifier: 0
                )
            ),
            accessibilityClient: StubAccessibilityTargetClient(result: .failure(.permissionDenied))
        )

        // when
        let result = resolver.resolve()

        // then
        XCTAssertEqual(result, .failure(.invalidProcessIdentifier(0)))
    }

    func resolve_AccessibilityPermissionDenied_ReturnsFailure() {
        // given
        let resolver = TargetResolver(
            frontmostApplicationProvider: StubFrontmostApplicationProvider(application: finderApplication),
            accessibilityClient: StubAccessibilityTargetClient(result: .failure(.permissionDenied))
        )

        // when
        let result = resolver.resolve()

        // then
        XCTAssertEqual(result, .failure(.accessibilityPermissionDenied))
    }

    func resolve_FocusedWindowUnavailable_ReturnsBundleScopedFailure() {
        // given
        let resolver = TargetResolver(
            frontmostApplicationProvider: StubFrontmostApplicationProvider(application: finderApplication),
            accessibilityClient: StubAccessibilityTargetClient(
                result: .failure(.focusedWindowUnavailable("no value"))
            )
        )

        // when
        let result = resolver.resolve()

        // then
        XCTAssertEqual(
            result,
            .failure(
                .focusedWindowUnavailable(
                    bundleIdentifier: "com.apple.finder",
                    reason: "no value"
                )
            )
        )
    }

    func resolve_WindowFrameUnavailable_ReturnsBundleScopedFailure() {
        // given
        let resolver = TargetResolver(
            frontmostApplicationProvider: StubFrontmostApplicationProvider(application: finderApplication),
            accessibilityClient: StubAccessibilityTargetClient(
                result: .failure(.frameUnavailable("missing size"))
            )
        )

        // when
        let result = resolver.resolve()

        // then
        XCTAssertEqual(
            result,
            .failure(
                .windowFrameUnavailable(
                    bundleIdentifier: "com.apple.finder",
                    reason: "missing size"
                )
            )
        )
    }

    func resolve_InvalidWindowFrame_ReturnsFailure() {
        // given
        let frame = CGRect(x: 10, y: 20, width: 0, height: 120)
        let resolver = TargetResolver(
            frontmostApplicationProvider: StubFrontmostApplicationProvider(application: finderApplication),
            accessibilityClient: StubAccessibilityTargetClient(
                result: .success(TargetWindow(frame: frame, title: "Finder"))
            )
        )

        // when
        let result = resolver.resolve()

        // then
        XCTAssertEqual(
            result,
            .failure(
                .invalidWindowFrame(
                    bundleIdentifier: "com.apple.finder",
                    frame: frame
                )
            )
        )
    }

    func resolve_ValidTarget_ReturnsContext() {
        // given
        let resolvedAt = Date(timeIntervalSince1970: 1_788_748_400)
        let window = TargetWindow(
            frame: CGRect(x: 10, y: 20, width: 300, height: 200),
            title: "Finder"
        )
        let resolver = TargetResolver(
            frontmostApplicationProvider: StubFrontmostApplicationProvider(application: finderApplication),
            accessibilityClient: StubAccessibilityTargetClient(result: .success(window)),
            dateProvider: { resolvedAt }
        )

        // when
        let result = resolver.resolve()

        // then
        guard case .success(let context) = result else {
            XCTFail("Expected success, got \(result).")
            return
        }
        XCTAssertEqual(context.application, finderApplication)
        XCTAssertEqual(context.window, window)
        XCTAssertEqual(context.resolvedAt, resolvedAt)
    }

    private var finderApplication: TargetApplication {
        TargetApplication(
            localizedName: "Finder",
            bundleIdentifier: "com.apple.finder",
            processIdentifier: 100
        )
    }
}

@MainActor
private struct StubFrontmostApplicationProvider: FrontmostApplicationProviding {
    let application: TargetApplication?

    func frontmostApplication() -> TargetApplication? {
        application
    }
}

@MainActor
private struct StubAccessibilityTargetClient: AccessibilityTargetClient {
    let result: Result<TargetWindow, AccessibilityReadFailure>

    func focusedWindow(for application: TargetApplication) -> Result<TargetWindow, AccessibilityReadFailure> {
        result
    }
}
