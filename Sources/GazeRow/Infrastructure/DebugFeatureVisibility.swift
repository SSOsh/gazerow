import Foundation

/// 로컬 MVP에서 debug 전용 기능 노출 여부를 관리한다.
///
/// 기본값은 숨김이다. 개발 중 필요할 때만 UserDefaults 값을 켜서 debug export
/// 컨트롤을 노출한다.
///
/// @author suho.do
/// @since 2026-07-02
struct DebugFeatureVisibility {

    /// debug export UI 노출 여부를 저장하는 UserDefaults 키.
    static let debugExportVisibleKey = "debug.export.visible"

    /// 설정 저장소.
    private let defaults: UserDefaults

    /// - Parameter defaults: debug flag 저장소. 기본값 `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// debug export UI 노출 여부. 기본값 false.
    var isDebugExportVisible: Bool {
        defaults.bool(forKey: Self.debugExportVisibleKey)
    }
}
