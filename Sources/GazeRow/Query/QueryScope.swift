/// Query Overlay가 해석한 현재 입력 범위.
///
/// @author suho.do
/// @since 2026-07-09
enum QueryScope: String, Equatable, CaseIterable {
    case windows
    case elements
    case labels

    /// 화면 좌표로 겨냥할 수 있는(공간) scope인지 여부.
    ///
    /// labels·elements는 화면 위에 대상 frame이 있어 시선/포인터로 겨냥할 수 있고,
    /// windows는 의미 검색 전용이라 겨냥할 공간 대상이 없다.
    var isSpatial: Bool {
        switch self {
        case .labels, .elements:
            true
        case .windows:
            false
        }
    }
}
