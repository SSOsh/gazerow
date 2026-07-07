/// overlay label 문자열 생성 전략.
///
/// @author suho.do
/// @since 2026-07-07
enum LabelStrategy: String, CaseIterable {
    /// 배치 단위 고정폭 label. (현행 기본, `LabelGenerator`)
    case fixedWidth
    /// prefix-free 가변폭 hint. 대부분 1글자, 일부만 2글자. (`HintLabelGenerator`)
    case prefixFree
}
