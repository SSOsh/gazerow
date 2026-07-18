import Foundation

/// 브라우저 창별 열린 탭 개수를 AppleScript로 조회한다.
///
/// Chromium 계열(Chrome, Brave, Edge, Vivaldi, Opera 등)과 Safari는 탭 바를
/// Accessibility 트리로 안정적으로 노출하지 않아, 별도 권한(Automation)이 필요한
/// AppleScript(`tell application id ...`)로 조회한다. Firefox는 탭을 다루는
/// 스크립팅 딕셔너리를 제공하지 않아 지원 대상에서 제외한다.
///
/// @author suho.do
/// @since 2026-07-18
struct BrowserTabCountFetcher {

    /// 지원 브라우저의 AppleScript 스크립팅 정보.
    struct BrowserProfile: Equatable {
        let bundleID: String
        /// `tell application id`에 쓰는 식별자. 대부분 bundleID와 같다.
        let scriptingID: String
        /// 창의 "제목"에 해당하는 AppleScript 프로퍼티명. Chromium 계열은 `title`, Safari는 `name`.
        let windowTitleProperty: String

        init(bundleID: String, scriptingID: String? = nil, windowTitleProperty: String = "title") {
            self.bundleID = bundleID
            self.scriptingID = scriptingID ?? bundleID
            self.windowTitleProperty = windowTitleProperty
        }
    }

    /// 탭 개수 조회를 지원하는 것으로 확인된 브라우저 목록.
    static let knownBrowsers: [BrowserProfile] = [
        BrowserProfile(bundleID: "com.google.Chrome"),
        BrowserProfile(bundleID: "com.google.Chrome.canary"),
        BrowserProfile(bundleID: "com.brave.Browser"),
        BrowserProfile(bundleID: "com.microsoft.edgemac"),
        BrowserProfile(bundleID: "com.vivaldi.Vivaldi"),
        BrowserProfile(bundleID: "com.operasoftware.Opera"),
        BrowserProfile(bundleID: "com.apple.Safari", windowTitleProperty: "name")
    ]

    private static let recordSeparator = "\u{1E}"
    private static let fieldSeparator = "\u{1F}"

    /// 창 제목 → 탭 개수. 스크립팅 실패(미지원 브라우저 포함) 시 빈 결과를 반환한다.
    func tabCounts(
        for profile: BrowserProfile,
        scriptRunner: (String) -> String? = Self.runAppleScript
    ) -> [String: Int] {
        guard let output = scriptRunner(Self.script(for: profile)), !output.isEmpty else {
            return [:]
        }

        var counts: [String: Int] = [:]
        for record in output.components(separatedBy: Self.recordSeparator) where !record.isEmpty {
            let fields = record.components(separatedBy: Self.fieldSeparator)
            guard fields.count == 2, let count = Int(fields[1]) else {
                continue
            }
            counts[fields[0]] = count
        }
        return counts
    }

    private static func script(for profile: BrowserProfile) -> String {
        """
        tell application id "\(profile.scriptingID)"
            set output to ""
            repeat with w in windows
                set output to output & (\(profile.windowTitleProperty) of w) & "\(fieldSeparator)" & (count of tabs of w) & "\(recordSeparator)"
            end repeat
            return output
        end tell
        """
    }

    private static func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else {
            return nil
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else {
            return nil
        }
        return result.stringValue
    }
}
