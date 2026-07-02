/// 여러 target window 후보 중 실제 overlay 대상으로 쓸 수 있는 창을 고른다.
///
/// @author suho.do
/// @since 2026-07-02
struct TargetWindowCandidateSelector {

    func firstUsableWindow(from candidates: [TargetWindow]) -> TargetWindow? {
        candidates.first { $0.hasUsableFrame }
    }
}
