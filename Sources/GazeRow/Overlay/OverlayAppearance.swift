import Foundation

/// overlay label/marker의 투명도(opacity) 설정.
///
/// 사용자가 오버레이가 뒤 콘텐츠를 가리는 정도를 조절할 수 있게 한다. 각 값은
/// 안전 범위로 clamp 되며, 기본값은 현행 하드코딩 렌더 값과 일치해 설정을
/// 건드리지 않는 한 시각적 회귀가 없다.
///
/// @author suho.do
/// @since 2026-07-07
struct OverlayAppearance: Equatable {
    /// label 배경 투명도의 기본값 겸 허용 범위. 설정 UI와 저장소가 SSOT로 참조한다.
    static let defaultLabelBackgroundOpacity = 0.62
    static let labelBackgroundOpacityRange: ClosedRange<Double> = 0.4...1.0

    /// unfocused label 배경 투명도. 범위 0.4...1.0.
    let labelBackgroundOpacity: Double
    /// label 텍스트 투명도. 범위 0.6...1.0.
    let labelTextOpacity: Double
    /// unfocused candidate marker 채움 투명도. 범위 0.0...0.4.
    let markerFillOpacity: Double
    /// target boundary 테두리 투명도. 범위 0.0...1.0.
    let boundaryOpacity: Double

    init(
        labelBackgroundOpacity: Double = OverlayAppearance.defaultLabelBackgroundOpacity,
        labelTextOpacity: Double = 1.0,
        markerFillOpacity: Double = 0.06,
        boundaryOpacity: Double = 0.75
    ) {
        self.labelBackgroundOpacity = Self.clamp(
            labelBackgroundOpacity,
            lower: Self.labelBackgroundOpacityRange.lowerBound,
            upper: Self.labelBackgroundOpacityRange.upperBound
        )
        self.labelTextOpacity = Self.clamp(labelTextOpacity, lower: 0.6, upper: 1.0)
        self.markerFillOpacity = Self.clamp(markerFillOpacity, lower: 0.0, upper: 0.4)
        self.boundaryOpacity = Self.clamp(boundaryOpacity, lower: 0.0, upper: 1.0)
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
