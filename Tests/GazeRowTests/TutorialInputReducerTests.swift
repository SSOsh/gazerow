import XCTest
@testable import GazeRow

/// `TutorialInputReducer`의 안전한 모의 입력 전이 단위 테스트.
///
/// @author suho.do
/// @since 2026-07-13
final class TutorialInputReducerTests: XCTestCase {

    func test_label연습_F를확인하면_mode연습으로이동한다() {
        // given
        let progress = TutorialProgress(step: .labelPractice)
        let sut = TutorialInputReducer()

        // when
        let focused = sut.reduce(progress: progress, command: .typeLabel("F"))
        let result = sut.reduce(progress: focused, command: .dryRunConfirm)

        // then
        XCTAssertEqual(result.focusedDemoLabel, "F")
        XCTAssertTrue(result.didConfirmDemoLabel)
        XCTAssertEqual(result.step, .modePractice)
    }

    func test_mode연습에서_두모드를사용하면_완료단계로이동한다() {
        // given
        let progress = TutorialProgress(step: .modePractice)
        let sut = TutorialInputReducer()

        // when
        let elementSearch = sut.reduce(progress: progress, command: .pinScope(.elements))
        let result = sut.reduce(progress: elementSearch, command: .pinScope(.windows))

        // then
        XCTAssertTrue(result.didTryElementSearch)
        XCTAssertTrue(result.didTryWindowSwitch)
        XCTAssertEqual(result.step, .finish)
    }

    func test_한글물리키입력이_F라벨을자동선택한다() {
        // given
        let mapper = FocusKeyboardCommandMapper()
        let command = mapper.command(for: FocusKeyboardInput(
            keyCode: 3,
            charactersIgnoringModifiers: "ㄹ"
        ))
        let progress = TutorialProgress(step: .labelPractice)

        // when
        let result = command.map {
            TutorialInputReducer().reduce(progress: progress, command: $0)
        }

        // then
        XCTAssertEqual(result?.focusedDemoLabel, "F")
        XCTAssertEqual(result?.step, .labelPractice)
    }

    func test_tutorial명령은실제실행명령을생성하지않는다() {
        // given
        let progress = TutorialProgress(step: .labelPractice)

        // when
        let result = TutorialInputReducer().reduce(progress: progress, command: .closeOverlay)

        // then
        XCTAssertEqual(result, progress)
    }
}
