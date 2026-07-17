import Foundation

/// 인앱 튜토리얼의 단계.
///
/// @author suho.do
/// @since 2026-07-13
enum TutorialStep: Int, CaseIterable, Equatable {
    case introduction
    case labelPractice
    case modePractice
    case finish
}

/// 인앱 튜토리얼에서만 사용하는 모의 입력 진행 상태.
///
/// @author suho.do
/// @since 2026-07-13
struct TutorialProgress: Equatable {
    var step: TutorialStep = .introduction
    var focusedDemoLabel: Character?
    var didConfirmDemoLabel: Bool = false
    var didTryElementSearch: Bool = false
    var didTryWindowSwitch: Bool = false
}

/// 튜토리얼 키보드 입력을 순수한 진행 상태로 환원한다.
///
/// 실제 overlay session, 접근성 API, 창 활성화에는 접근하지 않는다.
///
/// @author suho.do
/// @since 2026-07-13
struct TutorialInputReducer {

    func reduce(
        progress: TutorialProgress,
        command: FocusKeyboardCommand
    ) -> TutorialProgress {
        var next = progress

        switch progress.step {
        case .introduction, .finish:
            return next
        case .labelPractice:
            reduceLabelPractice(progress: &next, command: command)
        case .modePractice:
            reduceModePractice(progress: &next, command: command)
        }

        return next
    }

    private func reduceLabelPractice(
        progress: inout TutorialProgress,
        command: FocusKeyboardCommand
    ) {
        switch command {
        case .typeLabel(let label):
            progress.focusedDemoLabel = label
        case .dryRunConfirm where progress.focusedDemoLabel == "F":
            progress.didConfirmDemoLabel = true
            progress.step = .modePractice
        default:
            break
        }
    }

    private func reduceModePractice(
        progress: inout TutorialProgress,
        command: FocusKeyboardCommand
    ) {
        switch command {
        case .pinScope(.elements):
            progress.didTryElementSearch = true
        case .pinScope(.windows):
            progress.didTryWindowSwitch = true
        default:
            break
        }

        if progress.didTryElementSearch && progress.didTryWindowSwitch {
            progress.step = .finish
        }
    }
}
