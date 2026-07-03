import ApplicationServices

/// 고정키로 실행하는 표준 윈도우 컨트롤 동작.
///
/// 각 case는 focused window의 표준 AX 버튼 attribute에 매핑되며,
/// 실행 시 해당 버튼 element에 `AXPress` action을 보낸다.
/// overlay 라벨 클릭과 달리 라벨 스캔 없이 창의 title-bar 버튼을 직접 누른다.
///
/// @author suho.do
/// @since 2026-07-02
enum WindowControlAction: Equatable, CaseIterable {
    /// 창 닫기 (red 버튼). `AXCloseButton`.
    case close
    /// 창 최소화 (yellow 버튼). `AXMinimizeButton`.
    case minimize
    /// 창 zoom/최대화 (green 버튼). `AXZoomButton`.
    case zoom

    /// 동작이 누를 title-bar 버튼의 AX attribute 이름.
    var axButtonAttribute: String {
        switch self {
        case .close:
            return kAXCloseButtonAttribute as String
        case .minimize:
            return kAXMinimizeButtonAttribute as String
        case .zoom:
            return kAXZoomButtonAttribute as String
        }
    }

    /// 로그/문서용 사람이 읽는 이름.
    var displayName: String {
        switch self {
        case .close:
            return "Close Window"
        case .minimize:
            return "Minimize Window"
        case .zoom:
            return "Zoom Window"
        }
    }

    /// 로그 코드용 짧은 식별자(원문 저장 없음).
    var logCode: String {
        switch self {
        case .close:
            return "close"
        case .minimize:
            return "minimize"
        case .zoom:
            return "zoom"
        }
    }
}
