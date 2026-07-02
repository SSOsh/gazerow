import AppKit
import XCTest
@testable import GazeRow

/// `BundleIdentifierApplicationProvider`의 bundle id 기반 앱 선택을 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
final class BundleIdentifierApplicationProviderTests: XCTestCase {

    func test_frontmostApplication_bundleId가_일치하는_앱을_반환() throws {
        // given
        let runningApplication = try XCTUnwrap(
            NSWorkspace.shared.runningApplications.first {
                $0.bundleIdentifier != nil && $0.processIdentifier > 0
            }
        )
        let bundleIdentifier = try XCTUnwrap(runningApplication.bundleIdentifier)
        let sut = BundleIdentifierApplicationProvider(
            bundleIdentifier: bundleIdentifier,
            runningApplications: { [runningApplication] }
        )

        // when
        let result = sut.frontmostApplication()

        // then
        XCTAssertEqual(result?.bundleIdentifier, bundleIdentifier)
        XCTAssertEqual(result?.processIdentifier, runningApplication.processIdentifier)
    }

    func test_frontmostApplication_일치하는_앱이_없으면_nil() {
        // given
        let sut = BundleIdentifierApplicationProvider(
            bundleIdentifier: "missing.bundle",
            runningApplications: { [NSRunningApplication.current] }
        )

        // when
        let result = sut.frontmostApplication()

        // then
        XCTAssertNil(result)
    }
}
