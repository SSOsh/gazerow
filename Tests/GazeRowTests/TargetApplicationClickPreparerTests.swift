import XCTest
@testable import GazeRow

/// TargetApplicationClickPreparer 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-04
final class TargetApplicationClickPreparerTests: XCTestCase {

    func test_prepareForClick은_pid로_대상앱을_activate하고_대기하지않는다() {
        // given
        var activatedPIDs: [pid_t] = []
        let sut = TargetApplicationClickPreparer(
            activateApplication: { processIdentifier in
                activatedPIDs.append(processIdentifier)
                return true
            }
        )
        let application = TargetApplication(
            localizedName: "Codex",
            bundleIdentifier: "com.openai.codex",
            processIdentifier: 1234
        )

        // when
        sut.prepareForClick(application: application)

        // then
        XCTAssertEqual(activatedPIDs, [1234])
    }

    func test_prepareForClick은_activate실패시_즉시반환한다() {
        // given
        var activatedPIDs: [pid_t] = []
        let sut = TargetApplicationClickPreparer(
            activateApplication: { processIdentifier in
                activatedPIDs.append(processIdentifier)
                return false
            }
        )

        // when
        sut.prepareForClick(
            application: TargetApplication(
                localizedName: "Missing",
                bundleIdentifier: "missing",
                processIdentifier: 9999
            )
        )

        // then
        XCTAssertEqual(activatedPIDs, [9999])
    }
}
