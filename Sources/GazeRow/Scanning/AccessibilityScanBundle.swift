import CoreGraphics
import Foundation

/// 단일 AX walk가 수행한 inspection 계측값.
///
/// @author suho.do
/// @since 2026-07-17
struct AccessibilityScanBundleMetrics: Equatable, Sendable {
    let inspectionCount: Int
    let childReadCount: Int
}

/// label 후보와 Query Overlay index를 동일 AX snapshot에서 만든 결과.
///
/// @author suho.do
/// @since 2026-07-17
struct AccessibilityScanBundle: Equatable, Sendable {
    let scanResult: AccessibilityScanResult
    let elementIndex: ElementSearchIndex
    let metrics: AccessibilityScanBundleMetrics
    let generation: AccessibilityTreeGeneration
    let isChangeMonitoringActive: Bool

    init(
        scanResult: AccessibilityScanResult,
        elementIndex: ElementSearchIndex,
        metrics: AccessibilityScanBundleMetrics,
        generation: AccessibilityTreeGeneration = .initial,
        isChangeMonitoringActive: Bool = false
    ) {
        self.scanResult = scanResult
        self.elementIndex = elementIndex
        self.metrics = metrics
        self.generation = generation
        self.isChangeMonitoringActive = isChangeMonitoringActive
    }

    static func fallback(scanResult: AccessibilityScanResult) -> AccessibilityScanBundle {
        let nodes = scanResult.candidates.enumerated().map { index, candidate in
            SearchableNode(
                id: index,
                role: candidate.role,
                subrole: candidate.subrole,
                title: candidate.title,
                frame: candidate.frame
            )
        }
        return AccessibilityScanBundle(
            scanResult: scanResult,
            elementIndex: ElementSearchIndex(nodes: nodes),
            metrics: AccessibilityScanBundleMetrics(
                inspectionCount: scanResult.nodesVisited,
                childReadCount: 0
            )
        )
    }

    func withCacheMetadata(
        generation: AccessibilityTreeGeneration,
        isChangeMonitoringActive: Bool
    ) -> AccessibilityScanBundle {
        AccessibilityScanBundle(
            scanResult: scanResult,
            elementIndex: elementIndex,
            metrics: metrics,
            generation: generation,
            isChangeMonitoringActive: isChangeMonitoringActive
        )
    }
}

/// candidate와 searchable node를 한 inspection에서 생성하는 AX tree collector.
///
/// @author suho.do
/// @since 2026-07-17
struct AccessibilityScanBundleCollector<Client: AccessibilityElementClient> {
    private var progressiveYieldInterval: Int { 32 }
    private let client: Client
    private let configuration: AccessibilityScanConfiguration
    private let clickabilityPolicy: AccessibilityClickabilityPolicy
    private let dateProvider: () -> Date

    init(
        client: Client,
        configuration: AccessibilityScanConfiguration = AccessibilityScanConfiguration(),
        clickabilityPolicy: AccessibilityClickabilityPolicy = AccessibilityClickabilityPolicy(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.configuration = configuration
        self.clickabilityPolicy = clickabilityPolicy
        self.dateProvider = dateProvider
    }

    func collectProgressively(
        context: TargetContext,
        onProgress: (AccessibilityScanProgress) -> Void
    ) async -> Result<AccessibilityScanBundle, AccessibilityScanFailure> {
        let startedAt = dateProvider()
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }

        let root: Client.Element
        switch client.rootElement(for: context) {
        case .success(let resolvedRoot):
            root = resolvedRoot
        case .failure(let failure):
            return .failure(failure)
        }

        var state = CollectionState<Client.Element>(
            root: root,
            additionalRoots: client.additionalRootElements(for: context)
        )
        while let item = state.stack.popLast() {
            if Task.isCancelled {
                return .failure(.cancelled)
            }
            if state.nodesVisited >= configuration.maxNodes {
                state.didHitNodeLimit = true
                break
            }
            if dateProvider().timeIntervalSince(startedAt) > configuration.timeout {
                state.didTimeout = true
                break
            }

            process(item, context: context, state: &state)
            if state.didAddCandidate || state.nodesVisited.isMultiple(of: progressiveYieldInterval) {
                onProgress(
                    AccessibilityScanProgress(
                        candidates: state.candidates,
                        nodesVisited: state.nodesVisited
                    )
                )
                await Task.yield()
            }
        }

        return .success(makeBundle(state: state, startedAt: startedAt))
    }

    private func process(
        _ item: PendingBundleNode<Client.Element>,
        context: TargetContext,
        state: inout CollectionState<Client.Element>
    ) {
        let nodeID = state.nodesVisited
        state.nodesVisited += 1
        state.inspectionCount += 1
        let inspection = client.inspect(item.element)
        state.didAddCandidate = false

        if let candidate = makeCandidate(
            from: inspection.snapshot,
            within: context.window.frame
        ),
           state.candidateKeys.insert(BundleCandidateKey(candidate)).inserted {
            state.candidates.append(candidate)
            state.didAddCandidate = true
        }

        if let node = makeSearchableNode(
            id: nodeID,
            snapshot: inspection.snapshot,
            parentID: item.parentID,
            axPath: item.axPath
        ) {
            state.nodeIndexByID[nodeID] = state.nodes.count
            state.nodes.append(node)
            if let parentID = item.parentID {
                state.childrenByParentID[parentID, default: []].append(nodeID)
            }
        }

        guard item.depth < configuration.maxDepth else {
            state.didHitDepthLimit = true
            return
        }

        state.childReadCount += 1
        switch inspection.children {
        case .success(let children):
            state.stack.append(
                contentsOf: children.enumerated().reversed().map { offset, child in
                    PendingBundleNode(
                        element: child,
                        depth: item.depth + 1,
                        parentID: nodeID,
                        axPath: item.axPath + [offset]
                    )
                }
            )
        case .failure:
            state.failedChildReadCount += 1
        }
    }

    private func makeBundle(
        state: CollectionState<Client.Element>,
        startedAt: Date
    ) -> AccessibilityScanBundle {
        let duration = dateProvider().timeIntervalSince(startedAt)
        let nodes = attachChildren(
            state.nodes,
            nodeIndexByID: state.nodeIndexByID,
            childrenByParentID: state.childrenByParentID
        )
        let truncated = state.didHitDepthLimit || state.didHitNodeLimit || state.didTimeout
        return AccessibilityScanBundle(
            scanResult: AccessibilityScanResult(
                candidates: state.candidates,
                nodesVisited: state.nodesVisited,
                scanDuration: duration,
                didHitDepthLimit: state.didHitDepthLimit,
                didHitNodeLimit: state.didHitNodeLimit,
                didTimeout: state.didTimeout,
                failedChildReadCount: state.failedChildReadCount
            ),
            elementIndex: ElementSearchIndex(
                nodes: nodes,
                buildMetrics: SearchIndexMetrics(
                    nodesVisited: state.nodesVisited,
                    durationMs: duration * 1_000,
                    truncated: truncated
                )
            ),
            metrics: AccessibilityScanBundleMetrics(
                inspectionCount: state.inspectionCount,
                childReadCount: state.childReadCount
            )
        )
    }

    private func attachChildren(
        _ nodes: [SearchableNode],
        nodeIndexByID: [Int: Int],
        childrenByParentID: [Int: [Int]]
    ) -> [SearchableNode] {
        var result = nodes
        for (parentID, childrenIDs) in childrenByParentID {
            guard let index = nodeIndexByID[parentID] else {
                continue
            }
            let node = result[index]
            result[index] = SearchableNode(
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
        return result
    }

    private func makeSearchableNode(
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
            help: snapshot.help,
            frame: frame,
            axPath: axPath,
            parentID: parentID
        )
    }

    private func makeCandidate(
        from snapshot: AccessibilityElementSnapshot,
        within targetFrame: CGRect
    ) -> ClickableCandidate? {
        guard let role = snapshot.role,
              !snapshot.isSecureField else {
            return nil
        }
        guard isClickable(snapshot: snapshot, role: role),
              let frame = snapshot.frame,
              frame.width > 0,
              frame.height > 0,
              frame.intersects(targetFrame) else {
            return nil
        }
        return ClickableCandidate(
            role: role,
            subrole: snapshot.subrole,
            title: snapshot.title,
            frame: frame,
            actions: snapshot.actions
        )
    }

    private func isClickable(snapshot: AccessibilityElementSnapshot, role: String) -> Bool {
        if clickabilityPolicy.hasClickAction(snapshot.actions)
            || clickabilityPolicy.isFocusableInput(
                role: role,
                subrole: snapshot.subrole,
                actions: snapshot.actions
            )
            || (role != AccessibilityRole.image && clickabilityPolicy.isClickableRole(role)) {
            return true
        }
        guard role == AccessibilityRole.image else {
            return false
        }
        return clickabilityPolicy.hasSemanticText(
            title: snapshot.title,
            value: snapshot.value,
            help: snapshot.help
        )
    }
}

private struct PendingBundleNode<Element> {
    let element: Element
    let depth: Int
    let parentID: Int?
    let axPath: [Int]
}

private struct CollectionState<Element> {
    var stack: [PendingBundleNode<Element>]
    var nodesVisited = 0
    var inspectionCount = 0
    var childReadCount = 0
    var candidates: [ClickableCandidate] = []
    var candidateKeys = Set<BundleCandidateKey>()
    var nodes: [SearchableNode] = []
    var nodeIndexByID: [Int: Int] = [:]
    var childrenByParentID: [Int: [Int]] = [:]
    var didHitDepthLimit = false
    var didHitNodeLimit = false
    var didTimeout = false
    var failedChildReadCount = 0
    var didAddCandidate = false

    init(root: Element, additionalRoots: [Element]) {
        stack = [PendingBundleNode(element: root, depth: 0, parentID: nil, axPath: [])]
        stack.append(
            contentsOf: additionalRoots.enumerated().map { offset, element in
                PendingBundleNode(
                    element: element,
                    depth: 0,
                    parentID: nil,
                    axPath: [-(offset + 1)]
                )
            }
        )
    }
}

private struct BundleCandidateKey: Hashable {
    let role: String
    let subrole: String?
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let actions: [String]

    init(_ candidate: ClickableCandidate) {
        role = candidate.role
        subrole = candidate.subrole
        x = Int(candidate.frame.minX.rounded())
        y = Int(candidate.frame.minY.rounded())
        width = Int(candidate.frame.width.rounded())
        height = Int(candidate.frame.height.rounded())
        actions = candidate.actions.sorted()
    }
}
