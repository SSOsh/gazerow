import Foundation

/// 한 타깃을 응시하는 dwell 시간을 누적해 캡처 시점을 판정하는 순수 값 타입.
///
/// UI 타이머가 매 tick마다 경과 시간을 넣으면, dwell 임계값을 넘는 순간 캡처
/// 신호(`true`)를 낸다. 캡처가 실패(feature 미검출)하면 `retry()`로 임계값 직전
/// 상태로 되돌려 다음 tick에 곧바로 재시도하게 한다.
///
/// @author suho.do
/// @since 2026-07-03
struct GazeCalibrationDwellClock {

    let dwellSeconds: TimeInterval
    private(set) var elapsed: TimeInterval

    init(dwellSeconds: TimeInterval = 1.2) {
        self.dwellSeconds = dwellSeconds
        self.elapsed = 0
    }

    /// 남은 dwell 진행률(0...1).
    var progress: Double {
        guard dwellSeconds > 0 else {
            return 1
        }
        return min(elapsed / dwellSeconds, 1)
    }

    /// 경과 시간을 누적하고, dwell 임계값에 도달했으면 `true`(캡처 시점)를 반환한다.
    ///
    /// 캡처 시점을 반환할 때 경과 시간을 0으로 리셋한다.
    mutating func advance(by delta: TimeInterval) -> Bool {
        elapsed += max(delta, 0)
        guard elapsed >= dwellSeconds else {
            return false
        }
        elapsed = 0
        return true
    }

    /// 다음 타깃을 위해 경과 시간을 초기화한다.
    mutating func reset() {
        elapsed = 0
    }

    /// 캡처가 실패했을 때 임계값 직전 상태로 되돌려 즉시 재시도하게 한다.
    mutating func retry() {
        elapsed = dwellSeconds
    }
}
