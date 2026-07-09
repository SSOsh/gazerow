import Foundation

/// overlay label 배경 투명도 사용자 설정을 UserDefaults에 저장한다.
///
/// 사용자가 오버레이 라벨이 뒤 콘텐츠를 가리는 정도를 조절할 수 있게 한다.
/// 저장된 값이 없으면 `OverlayAppearance` 기본값을 사용해 설정을 건드리지 않는 한
/// 시각적 회귀가 없다. 최종 clamp는 `OverlayAppearance`가 담당하므로 저장소는
/// 원시 Double만 다룬다.
///
/// @author suho.do
/// @since 2026-07-07
struct OverlayAppearanceSettings {
    static let labelBackgroundOpacityKey = "GazeRow.overlayLabelBackgroundOpacity"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 저장된 label 배경 투명도. 미설정 시 기본값을 반환한다.
    var labelBackgroundOpacity: Double {
        get {
            guard defaults.object(forKey: Self.labelBackgroundOpacityKey) != nil else {
                return OverlayAppearance.defaultLabelBackgroundOpacity
            }

            return defaults.double(forKey: Self.labelBackgroundOpacityKey)
        }
        nonmutating set {
            defaults.set(newValue, forKey: Self.labelBackgroundOpacityKey)
        }
    }

    /// 저장된 설정을 반영한 렌더용 appearance.
    var appearance: OverlayAppearance {
        OverlayAppearance(labelBackgroundOpacity: labelBackgroundOpacity)
    }
}
