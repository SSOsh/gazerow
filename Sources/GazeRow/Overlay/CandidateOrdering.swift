import CoreGraphics

/// clickable candidate를 화면 공간 순서(좌상→우하)로 정렬한다.
///
/// AX DFS 스캔 순서 대신 읽기 순서에 가까운 label 배정을 위해, 후보 중심점을
/// (row band, x) 기준으로 정렬한 원본 index 순열을 만든다. 프레임과 후보 자체는
/// 바꾸지 않고 순서(index)만 다루므로 click 실행/로그 파이프라인에 영향이 없다.
///
/// @author suho.do
/// @since 2026-07-07
struct CandidateOrdering: Equatable {
    /// 세로 방향 양자화 밴드 높이. 미세한 y 차이로 같은 행의 좌우 순서가
    /// 뒤집히지 않도록 midY를 밴드 단위로 묶는다.
    let rowBandHeight: CGFloat

    init(rowBandHeight: CGFloat = 24) {
        self.rowBandHeight = max(1, rowBandHeight)
    }

    /// 공간 순으로 정렬된 원본 index 순열을 반환한다.
    ///
    /// 정렬 키는 `(floor(midY / rowBandHeight), midX)`이며, 동률은 원본 index로
    /// stable 하게 유지한다.
    func ordered(_ candidates: [ClickableCandidate]) -> [Int] {
        candidates.indices.sorted { lhs, rhs in
            let left = sortKey(for: candidates[lhs])
            let right = sortKey(for: candidates[rhs])

            if left.band != right.band {
                return left.band < right.band
            }

            if left.x != right.x {
                return left.x < right.x
            }

            return lhs < rhs
        }
    }

    private func sortKey(for candidate: ClickableCandidate) -> (band: Int, x: CGFloat) {
        let band = Int((candidate.frame.midY / rowBandHeight).rounded(.down))
        return (band, candidate.frame.midX)
    }
}
