/// Query Overlay 입력 버퍼와 scope pin 상태.
///
/// @author suho.do
/// @since 2026-07-09
struct QueryInputState: Equatable {
    var buffer: String
    var pinnedScope: QueryScope?
    var lastScope: QueryScope

    init(
        buffer: String = "",
        pinnedScope: QueryScope? = nil,
        lastScope: QueryScope = .labels
    ) {
        self.buffer = buffer
        self.pinnedScope = pinnedScope
        self.lastScope = lastScope
    }
}
