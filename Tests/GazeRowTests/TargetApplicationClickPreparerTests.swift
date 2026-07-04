import XCTest
@testable import GazeRow

/// TargetApplicationClickPreparer 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-04
final class TargetApplicationClickPreparerTests: XCTestCase {

    func test_prepareForClick은_pid로_대상앱을_activate하고_짧게_대기한다() {
        // given
        var activatedPIDs: [pid_t] = []
        var sleepIntervals: [TimeInterval] = []
        let sut = TargetApplicationClickPreparer(
            activationDelay: 0.06,
            activateApplication: { processIdentifier in
                activatedPIDs.append(processIdentifier)
                return true
            },
            sleep: { interval in
                sleepIntervals.append(interval)
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
        XCTAssertEqual(sleepIntervals, [0.06])
    }

    func test_prepareForClick은_activate실패시_대기하지_않는다() {
        // given
        var sleepIntervals: [TimeInterval] = []
        let sut = TargetApplicationClickPreparer(
            activationDelay: 0.06,
            activateApplication: { _ in false },
            sleep: { interval in
                sleepIntervals.append(interval)
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
        XCTAssertTrue(sleepIntervals.isEmpty)
    }
}
