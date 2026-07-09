import CoreGraphics
import Foundation

/// Query Overlay에서 AX node를 검색할 때 사용하는 field.
///
/// @author suho.do
/// @since 2026-07-09
enum SearchableField: String, CaseIterable {
    case title
    case value
    case help
    case description
    case role
}

/// Query Overlay element search 대상 node.
///
/// value는 생성 시점에 80자로 제한해 status 표시와 검색 입력 모두에서 과도한
/// 런타임 텍스트 노출을 줄인다.
///
/// @author suho.do
/// @since 2026-07-09
struct SearchableNode: Equatable, Identifiable {
    let id: Int
    let role: String?
    let subrole: String?
    let title: String?
    let value: String?
    let description: String?
    let help: String?
    let frame: CGRect
    let axPath: [Int]
    let parentID: Int?
    let childrenIDs: [Int]

    init(
        id: Int,
        role: String?,
        subrole: String? = nil,
        title: String? = nil,
        value: String? = nil,
        description: String? = nil,
        help: String? = nil,
        frame: CGRect,
        axPath: [Int] = [],
        parentID: Int? = nil,
        childrenIDs: [Int] = []
    ) {
        self.id = id
        self.role = role
        self.subrole = subrole
        self.title = title
        self.value = value.map { String($0.prefix(80)) }
        self.description = description
        self.help = help
        self.frame = frame
        self.axPath = axPath
        self.parentID = parentID
        self.childrenIDs = childrenIDs
    }
}

/// element search 결과.
///
/// @author suho.do
/// @since 2026-07-09
struct SearchMatch: Equatable {
    let nodeID: Int
    let score: Int
    let matchedFields: [SearchableField]
    let displayName: String
}

/// element search index 생성 계측값.
///
/// @author suho.do
/// @since 2026-07-09
struct SearchIndexMetrics: Equatable {
    let nodesVisited: Int
    let durationMs: Double
    let truncated: Bool
}

/// Query Overlay element 검색용 in-memory index.
///
/// @author suho.do
/// @since 2026-07-09
struct ElementSearchIndex: Equatable {
    let nodes: [SearchableNode]
    let buildMetrics: SearchIndexMetrics

    init(
        nodes: [SearchableNode],
        buildMetrics: SearchIndexMetrics? = nil,
        maxNodes: Int? = nil
    ) {
        let startedAt = Date()
        let limitedNodes: ArraySlice<SearchableNode>
        let truncated: Bool
        if let maxNodes, nodes.count > maxNodes {
            limitedNodes = nodes.prefix(maxNodes)
            truncated = true
        } else {
            limitedNodes = nodes[...]
            truncated = false
        }

        let indexedNodes = limitedNodes.filter(Self.isIndexable)
        self.nodes = indexedNodes
        self.buildMetrics = buildMetrics ?? SearchIndexMetrics(
            nodesVisited: limitedNodes.count,
            durationMs: Date().timeIntervalSince(startedAt) * 1_000,
            truncated: truncated
        )
    }

    func search(_ query: String) -> [SearchMatch] {
        let normalizedQuery = Self.normalized(query)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        return nodes.compactMap { node in
            match(node: node, normalizedQuery: normalizedQuery)
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }

            guard let lhsNode = node(id: lhs.nodeID),
                  let rhsNode = node(id: rhs.nodeID) else {
                return lhs.nodeID < rhs.nodeID
            }

            if lhsNode.frame.minY != rhsNode.frame.minY {
                return lhsNode.frame.minY < rhsNode.frame.minY
            }

            if lhsNode.frame.minX != rhsNode.frame.minX {
                return lhsNode.frame.minX < rhsNode.frame.minX
            }

            return lhs.nodeID < rhs.nodeID
        }
    }

    func node(id: Int) -> SearchableNode? {
        nodes.first { $0.id == id }
    }

    private func match(node: SearchableNode, normalizedQuery: String) -> SearchMatch? {
        var score = 0
        var matchedFields: [SearchableField] = []

        for field in SearchableField.allCases {
            guard let value = node.value(for: field) else {
                continue
            }

            let normalizedValue = Self.normalized(value)
            guard normalizedValue.contains(normalizedQuery) else {
                continue
            }

            matchedFields.append(field)
            let fieldScore = Self.score(
                field: field,
                normalizedValue: normalizedValue,
                normalizedQuery: normalizedQuery
            )
            score = max(score, fieldScore)
        }

        guard score > 0 else {
            return nil
        }

        return SearchMatch(
            nodeID: node.id,
            score: score,
            matchedFields: matchedFields,
            displayName: Self.displayName(for: node)
        )
    }

    private static func score(
        field: SearchableField,
        normalizedValue: String,
        normalizedQuery: String
    ) -> Int {
        let baseScore: Int
        switch field {
        case .title:
            baseScore = 100
        case .value:
            baseScore = 60
        case .help:
            baseScore = 40
        case .description:
            baseScore = 30
        case .role:
            baseScore = 10
        }

        let prefixBonus = (field == .title || field == .value)
            && normalizedValue.hasPrefix(normalizedQuery)
        return baseScore + (prefixBonus ? 20 : 0)
    }

    private static func isIndexable(_ node: SearchableNode) -> Bool {
        guard node.role != AccessibilityRole.secureTextField,
              node.frame.width >= 1,
              node.frame.height >= 1 else {
            return false
        }

        return [node.title, node.value, node.description, node.help].contains { value in
            guard let value else {
                return false
            }

            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private static func displayName(for node: SearchableNode) -> String {
        if let title = firstNonEmpty(node.title) {
            return title
        }

        if let value = firstNonEmpty(node.value) {
            return String(value.prefix(40))
        }

        if let role = firstNonEmpty(node.role) {
            return role
        }

        return "Element \(node.id)"
    }

    private static func firstNonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalized(_ value: String) -> String {
        value
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

private extension SearchableNode {
    func value(for field: SearchableField) -> String? {
        switch field {
        case .title:
            title
        case .value:
            value
        case .help:
            help
        case .description:
            description
        case .role:
            role
        }
    }
}
