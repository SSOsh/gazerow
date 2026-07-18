import Foundation

/// 브라우저 탭 개수 조회 결과를 백그라운드에서 갱신하고 마지막 스냅샷을 캐싱한다.
///
/// AppleScript(Apple Event) 호출은 사용자가 Automation 권한을 아직 승인하지 않았다면
/// 시스템 권한 팝업에 응답할 때까지 블로킹될 수 있다. `WindowSearchIndex.build()`는
/// windows scope 진입 시 MainActor에서 동기로 실행되므로, 이 호출을 직접 하면 사용자가
/// 팝업에 응답하기 전까지 전체 overlay가 멈춘다. 그래서 조회는 항상 백그라운드 큐에서
/// 하고, `build()`는 마지막으로 갱신된 스냅샷만 즉시(non-blocking) 읽는다.
///
/// @author suho.do
/// @since 2026-07-18
final class BrowserTabCountCache: @unchecked Sendable {
    static let shared = BrowserTabCountCache()

    private let lock = NSLock()
    private let fetchTabCounts: (BrowserTabCountFetcher.BrowserProfile) -> [String: Int]
    private let scheduleBackgroundWork: (@escaping () -> Void) -> Void
    private var snapshot: [String: [String: Int]] = [:]
    private var isRefreshing = false

    init(
        fetchTabCounts: @escaping (BrowserTabCountFetcher.BrowserProfile) -> [String: Int] = { profile in
            BrowserTabCountFetcher().tabCounts(for: profile)
        },
        scheduleBackgroundWork: @escaping (@escaping () -> Void) -> Void = { work in
            DispatchQueue.global(qos: .utility).async(execute: work)
        }
    ) {
        self.fetchTabCounts = fetchTabCounts
        self.scheduleBackgroundWork = scheduleBackgroundWork
    }

    /// bundleID → (창 제목 → 탭 개수). 마지막으로 갱신된 결과를 즉시 반환하며 절대 블로킹되지 않는다.
    func currentSnapshot() -> [String: [String: Int]] {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }

    /// 주어진 브라우저들의 탭 개수를 백그라운드에서 갱신한다.
    /// 이미 갱신이 진행 중이면 중복으로 새 Apple Event 호출을 쌓지 않는다.
    func refreshInBackground(profiles: [BrowserTabCountFetcher.BrowserProfile]) {
        lock.lock()
        if isRefreshing || profiles.isEmpty {
            lock.unlock()
            return
        }
        isRefreshing = true
        lock.unlock()

        scheduleBackgroundWork { [self] in
            var next: [String: [String: Int]] = [:]
            for profile in profiles {
                next[profile.bundleID] = fetchTabCounts(profile)
            }

            lock.lock()
            snapshot = next
            isRefreshing = false
            lock.unlock()
        }
    }
}
