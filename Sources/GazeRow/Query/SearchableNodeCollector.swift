import Foundation

/// AX tree에서 Query Overlay 검색용 node index를 수집한다.
///
/// @author suho.do
/// @since 2026-07-09
@MainActor
protocol SearchableNodeCollecting {
    func buildIndex(context: TargetContext) -> ElementSearchIndex
}

/// 기존 accessibility client를 재사용하는 searchable node collector.
///
/// @author suho.do
/// @since 2026-07-09
@MainActor
struct AccessibilitySearchableNodeCollector<Client: AccessibilityElementClient>: SearchableNodeCollecting {
    private let client: Client
    private let configuration: AccessibilityScanConfiguration
    private let dateProvider: () -> Date

    init(
        client: Client,
        configuration: AccessibilityScanConfiguration = AccessibilityScanConfiguration(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.configuration = configuration
        self.dateProvider = dateProvider
    }

    func buildIndex(context: TargetContext) -> ElementSearchIndex {
        let startedAt = dateProvider()
        switch client.rootElement(for: context) {
        case .success(let root):
            return buildIndex(root: root, startedAt: startedAt)
        case .failure:
            return ElementSearchIndex(
                nodes: [],
                buildMetrics: SearchIndexMetrics(nodesVisited: 0, durationMs: 0, truncated: false)
            )
        }
    }

    private func buildIndex(root: Client.Element, startedAt: Date) -> ElementSearchIndex {
        var stack: [PendingNode<Client.Element>] = [
            PendingNode(element: root, depth: 0, parentID: nil, axPath: [])
        ]
        var nodes: [SearchableNode] = []
        var nodeIndexByID: [Int: Int] = [:]
        var childrenByParentID: [Int: [Int]] = [:]
        var nodesVisited = 0
        var truncated = false

        while let item = stack.popLast() {
            if nodesVisited >= configuration.maxNodes || isTimedOut(startedAt: startedAt) {
                truncated = true
                break
            }

            let snapshot = client.snapshot(of: item.element)
            let nodeID = nodesVisited
            nodesVisited += 1

            if let node = makeNode(
                id: nodeID,
                snapshot: snapshot,
                parentID: item.parentID,
                axPath: item.axPath
            ) {
                nodeIndexByID[nodeID] = nodes.count
                nodes.append(node)
                if let parentID = item.parentID {
                    childrenByParentID[parentID, default: []].append(nodeID)
                }
            }

            guard item.depth < configuration.maxDepth else {
                truncated = true
                continue
            }

            if case .success(let children) = client.children(of: item.element) {
                let pendingChildren = children.enumerated().reversed().map { offset, child in
                    PendingNode(
                        element: child,
                        depth: item.depth + 1,
                        parentID: nodeID,
                        axPath: item.axPath + [offset]
                    )
                }
                stack.append(contentsOf: pendingChildren)
            }
        }

        for (parentID, childrenIDs) in childrenByParentID {
            guard let index = nodeIndexByID[parentID] else {
                continue
            }
            let node = nodes[index]
            nodes[index] = SearchableNode(
                id: node.id,
                role: node.role,
                subrole: node.subrole,
                title: node.title,
                value: node.value,
                description: node.description,
                help: node.help,
                frame: node.frame,
                axPath: node.axPath,
                parentID: node.parentID,
                childrenIDs: childrenIDs
            )
        }

        return ElementSearchIndex(
            nodes: nodes,
            buildMetrics: SearchIndexMetrics(
                nodesVisited: nodesVisited,
                durationMs: dateProvider().timeIntervalSince(startedAt) * 1_000,
                truncated: truncated
            )
        )
    }

    private func makeNode(
        id: Int,
        snapshot: AccessibilityElementSnapshot,
        parentID: Int?,
        axPath: [Int]
    ) -> SearchableNode? {
        guard let frame = snapshot.frame else {
            return nil
        }

        return SearchableNode(
            id: id,
            role: snapshot.role,
            subrole: snapshot.subrole,
            title: snapshot.title,
            value: snapshot.value,
            description: nil,
            help: snapshot.help,
            frame: frame,
            axPath: axPath,
            parentID: parentID
        )
    }

    private func isTimedOut(startedAt: Date) -> Bool {
        dateProvider().timeIntervalSince(startedAt) > configuration.timeout
    }
}

private struct PendingNode<Element> {
    let element: Element
    let depth: Int
    let parentID: Int?
    let axPath: [Int]
}
