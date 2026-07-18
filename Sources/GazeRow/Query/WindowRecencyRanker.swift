import CoreGraphics
import Foundation

/// 화면에 보이는 창들의 front-to-back(z-order) 순서를 조회해 최근 사용 순위 근사치를 만든다.
///
/// `CGWindowListCopyWindowInfo`는 on-screen 창을 프론트 → 백 순서로 반환하는 특성이 있어
/// 그 순서를 "최근에 포커스된 순서"의 근사치로 사용한다. `kCGWindowName`(창 제목)은
/// Screen Recording 권한이 없으면 다른 앱 창에서 비어 있을 수 있어 매칭 키로 쓰지 않고,
/// 별도 권한이 필요 없는 pid + frame 조합으로 AX window와 매칭한다.
///
/// @author suho.do
/// @since 2026-07-18
struct WindowRecencyRanker {

    func ranks(
        onScreenWindowInfoProvider: () -> [[String: AnyObject]] = Self.defaultOnScreenWindowInfo
    ) -> [WindowRecencyKey: Int] {
        var ranks: [WindowRecencyKey: Int] = [:]

        for (rank, info) in onScreenWindowInfoProvider().enumerated() {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: boundsDict) else {
                continue
            }

            let key = WindowRecencyKey(pid: pid, frame: frame)
            if ranks[key] == nil {
                ranks[key] = rank
            }
        }

        return ranks
    }

    private static func defaultOnScreenWindowInfo() -> [[String: AnyObject]] {
        (CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: AnyObject]]) ?? []
    }
}

/// pid + window frame(반올림) 기준 recency 조회 키.
///
/// AX와 CGWindowList 양쪽의 좌표계 부동소수점 오차를 흡수하기 위해 정수로 반올림해서 비교한다.
///
/// @author suho.do
/// @since 2026-07-18
struct WindowRecencyKey: Hashable {
    let pid: pid_t
    private let roundedX: Int
    private let roundedY: Int
    private let roundedWidth: Int
    private let roundedHeight: Int

    init(pid: pid_t, frame: CGRect) {
        self.pid = pid
        self.roundedX = Int(frame.origin.x.rounded())
        self.roundedY = Int(frame.origin.y.rounded())
        self.roundedWidth = Int(frame.size.width.rounded())
        self.roundedHeight = Int(frame.size.height.rounded())
    }
}
