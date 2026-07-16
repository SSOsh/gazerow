import AppKit
import ApplicationServices
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
        now: Date = Date()
    ) -> WindowSearchIndex {
        var nextID = 0
        var entries: [WindowEntry] = []

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
                entries.append(
                    WindowEntry(
                        id: nextID,
                        appName: appName,
                        bundleID: bundleID,
                        windowTitle: title,
                        windowTitleHash: titleHasher.hash(title),
                        pid: app.processIdentifier,
                        axWindow: window,
                        appIcon: app.icon
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
