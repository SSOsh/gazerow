import AppKit
import Observation

/// 확인 대상 브라우저 1개(스크립팅 정보 + 사용자에게 보여줄 표시 이름).
///
/// @author suho.do
/// @since 2026-07-18
struct BrowserAutomationTarget: Equatable {
    let profile: BrowserTabCountFetcher.BrowserProfile
    let displayName: String
}

/// 브라우저 탭 개수 조회에 필요한 Automation(Apple Events) 권한 상태를 조회/재확인한다.
///
/// Settings 화면에서 "탭 개수가 안 보여요" 문의에 대응하기 위해, 실행 중인 브라우저 중
/// 권한이 거부된 것이 있으면 이름을 모아 안내하고 System Settings로 보낼 수 있게 한다.
///
/// @author suho.do
/// @since 2026-07-18
@MainActor
@Observable
final class BrowserAutomationPermissionManager {

    /// 권한이 거부된 것으로 확인된 브라우저의 표시 이름. 없으면 비어있다.
    private(set) var deniedBrowserNames: [String] = []
    private(set) var isChecking = false
    /// `refresh()`가 한 번이라도 끝난 적이 있는지. 이 값으로 "아직 확인 안 함"과
    /// "확인했고 문제 없음"을 구분한다.
    private(set) var hasCheckedOnce = false

    private let statusProvider: @Sendable (BrowserTabCountFetcher.BrowserProfile) -> BrowserAutomationPermissionStatus
    private let runningTargetsProvider: () -> [BrowserAutomationTarget]

    init(
        statusProvider: @escaping @Sendable (BrowserTabCountFetcher.BrowserProfile) -> BrowserAutomationPermissionStatus = {
            BrowserAutomationPermissionChecker().status(for: $0)
        },
        runningTargetsProvider: @escaping () -> [BrowserAutomationTarget] = BrowserAutomationPermissionManager.defaultRunningTargets
    ) {
        self.statusProvider = statusProvider
        self.runningTargetsProvider = runningTargetsProvider
    }

    /// 실행 중인 브라우저들의 권한 상태를 다시 확인한다.
    ///
    /// AppleScript probe는 브라우저마다 최초 1회 권한 팝업 응답을 기다리며 블로킹될 수 있어
    /// 백그라운드 태스크에서 실행하고, 완료 후 MainActor에서 결과만 반영한다.
    func refresh() async {
        isChecking = true
        defer {
            isChecking = false
            hasCheckedOnce = true
        }

        let targets = runningTargetsProvider()
        let statusProvider = self.statusProvider
        deniedBrowserNames = await Task.detached(priority: .utility) {
            targets.filter { statusProvider($0.profile) == .denied }.map(\.displayName)
        }.value
    }

    /// System Settings의 Automation 개인정보 보호 창을 연다.
    func openAutomationSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    nonisolated private static func defaultRunningTargets() -> [BrowserAutomationTarget] {
        var appByBundleID: [String: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleID = app.bundleIdentifier, appByBundleID[bundleID] == nil else {
                continue
            }
            appByBundleID[bundleID] = app
        }

        return BrowserTabCountFetcher.knownBrowsers.compactMap { profile in
            guard let app = appByBundleID[profile.bundleID] else {
                return nil
            }
            return BrowserAutomationTarget(profile: profile, displayName: app.localizedName ?? profile.bundleID)
        }
    }
}
