import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Query Overlay windows scope의 검색 대상 창.
///
/// @author suho.do
/// @since 2026-07-09
struct WindowEntry: Equatable, Identifiable {
    let id: Int
    let appName: String
    let bundleID: String
    let windowTitle: String?
    let windowTitleHash: String?
    let pid: pid_t
    let axWindow: AXUIElement?
    let appIcon: NSImage?
    /// 동일 앱 그룹에서 대표 창을 고를 때 쓰는 최근 사용(z-order) 순위. 낮을수록 최근/전면 창이며, 알 수 없으면 `Int.max`.
    let recencyRank: Int

    init(
        id: Int,
        appName: String,
        bundleID: String,
        windowTitle: String?,
        windowTitleHash: String?,
        pid: pid_t,
        axWindow: AXUIElement?,
        appIcon: NSImage?,
        recencyRank: Int = Int.max
    ) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.windowTitle = windowTitle
        self.windowTitleHash = windowTitleHash
        self.pid = pid
        self.axWindow = axWindow
        self.appIcon = appIcon
        self.recencyRank = recencyRank
    }

    static func == (lhs: WindowEntry, rhs: WindowEntry) -> Bool {
        lhs.id == rhs.id
            && lhs.appName == rhs.appName
            && lhs.bundleID == rhs.bundleID
            && lhs.windowTitle == rhs.windowTitle
            && lhs.windowTitleHash == rhs.windowTitleHash
            && lhs.pid == rhs.pid
    }
}

/// Query Overlay windows scope 검색 결과.
///
/// @author suho.do
/// @since 2026-07-09
struct WindowMatch: Equatable {
    let entryID: Int
    let score: Int
    let displayLine: String
}

/// 실행 중인 앱/창 검색 index.
///
/// @author suho.do
/// @since 2026-07-09
struct WindowSearchIndex: Equatable {
    let entries: [WindowEntry]
    let builtAt: Date

    init(entries: [WindowEntry], builtAt: Date = Date()) {
        self.entries = entries
        self.builtAt = builtAt
    }

    static func build(
        excludingBundleIDs: Set<String> = ["dev.local.gazerow", "io.github.ssosh.gazerow"],
        workspace: NSWorkspace = .shared,
        titleHasher: WindowTitleHasher = WindowTitleHasher(salt: SessionSalt()),
        recencyRanker: WindowRecencyRanker = WindowRecencyRanker(),
        now: Date = Date()
    ) -> WindowSearchIndex {
        var nextID = 0
        var entries: [WindowEntry] = []
        let recencyRanks = recencyRanker.ranks()

        for app in workspace.runningApplications
            where app.activationPolicy == .regular
                && !excludingBundleIDs.contains(app.bundleIdentifier ?? "") {
            let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
            let bundleID = app.bundleIdentifier ?? ""
            let windows = Self.windowElements(for: app.processIdentifier)

            if windows.isEmpty {
                entries.append(
                    WindowEntry(
                        id: nextID,
                        appName: appName,
                        bundleID: bundleID,
                        windowTitle: nil,
                        windowTitleHash: nil,
                        pid: app.processIdentifier,
                        axWindow: nil,
                        appIcon: app.icon
                    )
                )
                nextID += 1
                continue
            }

            for window in windows {
                let title = Self.windowTitle(window)
                let recencyRank = Self.windowFrame(window).flatMap { frame in
                    recencyRanks[WindowRecencyKey(pid: app.processIdentifier, frame: frame)]
                } ?? Int.max
                entries.append(
                    WindowEntry(
                        id: nextID,
                        appName: appName,
                        bundleID: bundleID,
                        windowTitle: title,
                        windowTitleHash: titleHasher.hash(title),
                        pid: app.processIdentifier,
                        axWindow: window,
                        appIcon: app.icon,
                        recencyRank: recencyRank
                    )
                )
                nextID += 1
            }
        }

        return WindowSearchIndex(entries: entries, builtAt: now)
    }

    func search(_ query: String) -> [WindowMatch] {
        let normalizedQuery = SearchTextMatcher.normalized(query)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        return entries.compactMap { entry in
            match(entry: entry, normalizedQuery: normalizedQuery)
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }

            let lhsEntry = entry(id: lhs.entryID)
            let rhsEntry = entry(id: rhs.entryID)
            return (lhsEntry?.appName ?? lhs.displayLine) < (rhsEntry?.appName ?? rhs.displayLine)
        }
    }

    func entry(id: Int) -> WindowEntry? {
        entries.first { $0.id == id }
    }

    func isStale(now: Date = Date(), maxAge: TimeInterval = 30) -> Bool {
        now.timeIntervalSince(builtAt) > maxAge
    }

    private func match(entry: WindowEntry, normalizedQuery: String) -> WindowMatch? {
        let title = entry.windowTitle
        let appName = entry.appName
        let bundleID = entry.bundleID
        var score = 0

        if let title,
           let matchKind = SearchTextMatcher.match(value: title, query: normalizedQuery) {
            score = max(score, titleScore(for: matchKind))
        }

        if let matchKind = SearchTextMatcher.match(value: appName, query: normalizedQuery) {
            score = max(score, appNameScore(for: matchKind))
        }

        if SearchTextMatcher.match(value: bundleID, query: normalizedQuery) != nil {
            score = max(score, 40)
        }

        guard score > 0 else {
            return nil
        }

        return WindowMatch(entryID: entry.id, score: score, displayLine: displayLine(for: entry))
    }

    private func displayLine(for entry: WindowEntry) -> String {
        guard let title = entry.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return entry.appName
        }

        return "\(entry.appName) — \(title)"
    }

    private static func windowElements(for pid: pid_t) -> [AXUIElement] {
        guard AXIsProcessTrusted() else {
            return []
        }

        let appElement = AXUIElementCreateApplication(pid)
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &value
        )
        guard error == .success,
              let values = value as? [AnyObject] else {
            return []
        }

        return values.compactMap { value in
            guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
                return nil
            }
            return (value as! AXUIElement)
        }
    }

    private static func windowTitle(_ window: AXUIElement) -> String? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            window,
            kAXTitleAttribute as CFString,
            &value
        )
        guard error == .success else {
            return nil
        }
        return value as? String
    }

    private static func windowFrame(_ window: AXUIElement) -> CGRect? {
        guard let origin = axPoint(window, attribute: kAXPositionAttribute as String),
              let size = axSize(window, attribute: kAXSizeAttribute as String) else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    private static func axPoint(_ window: AXUIElement, attribute: String) -> CGPoint? {
        guard let axValue = axValue(window, attribute: attribute) else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else {
            return nil
        }
        return point
    }

    private static func axSize(_ window: AXUIElement, attribute: String) -> CGSize? {
        guard let axValue = axValue(window, attribute: attribute) else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else {
            return nil
        }
        return size
    }

    private static func axValue(_ window: AXUIElement, attribute: String) -> AXValue? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(window, attribute as CFString, &value)
        guard error == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return (value as! AXValue)
    }

    private func titleScore(for matchKind: SearchTextMatchKind) -> Int {
        switch matchKind {
        case .exact:
            200
        case .prefix:
            150
        case .contains:
            100
        case .acronym:
            90
        case .subsequence:
            70
        }
    }

    private func appNameScore(for matchKind: SearchTextMatchKind) -> Int {
        switch matchKind {
        case .exact:
            80
        case .prefix, .contains:
            60
        case .acronym:
            55
        case .subsequence:
            45
        }
    }
}
