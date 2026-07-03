import SwiftUI

/// calibration 진행 화면이 읽는 관찰 가능한 상태.
///
/// window controller가 dwell/진행 상황을 갱신하면 뷰가 응시 타깃 점과 진행률을
/// 다시 그린다.
///
/// @author suho.do
/// @since 2026-07-03
@MainActor
@Observable
final class GazeCalibrationViewState {
    /// 현재 응시할 타깃의 정규화 좌표(0...1). 완료 시 nil.
    var normalizedTarget: CGPoint?

    /// 현재 타깃 dwell 진행률(0...1).
    var dwellProgress: Double = 0

    /// 진행 단계(1-based)와 전체 단계.
    var currentStep: Int = 0
    var totalSteps: Int = 0
}

/// full-screen calibration overlay 본문.
///
/// 어두운 배경 위에 현재 타깃 점을 표시하고, dwell 진행률을 링으로 보여준다.
/// 사용자는 점을 응시하면 자동으로 다음 점으로 넘어가며, Escape로 취소한다.
///
/// @author suho.do
/// @since 2026-07-03
struct GazeCalibrationView: View {

    let state: GazeCalibrationViewState

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.88)
                    .ignoresSafeArea()

                if let target = state.normalizedTarget {
                    targetDot
                        .position(
                            x: target.x * geometry.size.width,
                            y: target.y * geometry.size.height
                        )
                }

                instructionPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 48)
            }
        }
    }

    /// dwell 진행 링을 두른 응시 타깃 점.
    private var targetDot: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 4)
                .frame(width: 44, height: 44)

            Circle()
                .trim(from: 0, to: state.dwellProgress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 44, height: 44)

            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
        }
    }

    /// 상단 안내/진행 텍스트.
    private var instructionPanel: some View {
        VStack(spacing: 8) {
            Text("Look at the dot")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text("Step \(state.currentStep) / \(state.totalSteps)")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))

            Text("Press Esc to cancel")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
