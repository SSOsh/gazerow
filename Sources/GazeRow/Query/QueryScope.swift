/// Query Overlay가 해석한 현재 입력 범위.
///
/// @author suho.do
/// @since 2026-07-09
enum QueryScope: String, Equatable, CaseIterable {
    case windows
    case elements
    case labels
}
