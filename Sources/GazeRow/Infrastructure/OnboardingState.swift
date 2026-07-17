import Foundation
import Observation

/// 첫 실행 안내(onboarding) 표시 여부를 관리한다.
///
/// 완료 여부는 `UserDefaults`에 영속 저장한다. 저장소를 주입할 수 있어
/// 단위 테스트에서는 임시 `UserDefaults`(suite)를 사용한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
@Observable
final class OnboardingState {

    /// onboarding 완료 여부를 저장하는 UserDefaults 키.
    private static let completedKey = "onboarding.completed"

    /// 마지막으로 완료한 tutorial 버전을 저장하는 UserDefaults 키.
    private static let tutorialVersionKey = "onboarding.tutorialVersion"

    /// 현재 tutorial의 데이터 버전.
    static let currentTutorialVersion = 1

    /// onboarding 시트 표시 여부. UI가 바인딩한다.
    var isPresenting: Bool = false

    /// 다시 보기로 열린 tutorial인지 여부.
    private(set) var isReplayingTutorial: Bool = false

    /// 현재 tutorial의 모의 입력 진행 상태.
    private(set) var tutorialProgress = TutorialProgress()

    /// tutorial 종료 전 확인 대화상자 표시 여부.
    var isExitConfirmationPresented: Bool = false

    /// 완료 여부 저장소.
    private let defaults: UserDefaults

    /// - Parameter defaults: 완료 여부를 저장할 UserDefaults. 기본값은 `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// onboarding을 이미 완료했는지 여부.
    var hasCompleted: Bool {
        defaults.bool(forKey: Self.completedKey)
    }

    /// 마지막으로 완료한 tutorial 버전.
    var completedTutorialVersion: Int {
        defaults.integer(forKey: Self.tutorialVersionKey)
    }

    /// 아직 완료하지 않았다면 시트를 표시하도록 `isPresenting`을 켠다.
    func presentIfNeeded() {
        if !hasCompleted {
            resetTutorial(isReplay: false)
            isPresenting = true
        }
    }

    /// Settings에서 사용자가 tutorial을 다시 연다.
    func replayTutorial() {
        resetTutorial(isReplay: true)
        isPresenting = true
    }

    /// 안내 화면 다음의 라벨 연습을 시작한다.
    func startTutorial() {
        tutorialProgress.step = .labelPractice
    }

    /// 이전 단계로 이동한다.
    func goBack() {
        switch tutorialProgress.step {
        case .introduction:
            break
        case .labelPractice:
            tutorialProgress.step = .introduction
            tutorialProgress.focusedDemoLabel = nil
        case .modePractice:
            tutorialProgress.step = .labelPractice
            tutorialProgress.didConfirmDemoLabel = false
        case .finish:
            tutorialProgress.step = .modePractice
        }
    }

    /// mapper가 만든 명령을 안전한 tutorial reducer에 전달한다.
    func handleTutorialCommand(_ command: FocusKeyboardCommand) {
        tutorialProgress = TutorialInputReducer().reduce(
            progress: tutorialProgress,
            command: command
        )
    }

    /// tutorial을 닫기 전에 확인을 요청한다.
    func requestExitConfirmation() {
        isExitConfirmationPresented = true
    }

    /// 종료 확인을 취소하고 tutorial로 돌아간다.
    func cancelExit() {
        isExitConfirmationPresented = false
    }

    /// 완료 상태를 변경하지 않고 tutorial 시트를 닫는다.
    func dismissTutorial() {
        isPresenting = false
        isExitConfirmationPresented = false
        isReplayingTutorial = false
    }

    /// 완료로 표시하고 시트를 닫는다.
    func complete() {
        completeTutorial()
    }

    /// tutorial 완료 또는 건너뛰기를 저장하고 시트를 닫는다.
    func completeTutorial() {
        defaults.set(true, forKey: Self.completedKey)
        defaults.set(Self.currentTutorialVersion, forKey: Self.tutorialVersionKey)
        isPresenting = false
        isExitConfirmationPresented = false
        isReplayingTutorial = false
    }

    private func resetTutorial(isReplay: Bool) {
        isReplayingTutorial = isReplay
        tutorialProgress = TutorialProgress()
        isExitConfirmationPresented = false
    }
}
