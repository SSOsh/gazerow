import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// overlay focused label을 실제 click execution으로 연결한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
protocol OverlaySessionClickExecuting {
    func execute(
        selection: OverlayClickSelection,
        context: TargetContext,
        isSecondConfirmProvided: Bool
    ) -> Result<ClickExecutionSuccess, OverlaySessionClickFailure>
}

/// overlay session click 실패 사유.
///
/// @author suho.do
/// @since 2026-07-02
enum OverlaySessionClickFailure: Error, Equatable {
    case scanFailed(AccessibilityScanFailure)
    case missingFocusedTarget(index: Int)
    case selectedTargetUnavailable(labelID: Int)
    case selectedTargetChanged(labelID: Int)
    case selectedTargetAmbiguous(labelID: Int)
    case executionFailed(ClickExecutionFailure)
}

/// production overlay click executor adapter.
///
/// AXUIElement와 AppKit event posting은 모두 non-Sendable API이며, 선택 검증과 click을
/// 같은 순서로 처리해야 한다. 따라서 이 경계는 @MainActor에서 직렬 실행한다. 별도 actor로
/// 옮기려면 AX 호출을 소유하는 Sendable wrapper와 snapshot-only 결과 계약이 먼저 필요하다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct AXOverlaySessionClickExecutor: OverlaySessionClickExecuting {
    private let targetRevalidator: OverlayClickTargetRevalidator<AXAccessibilityElementClient>
    private let clickExecutor: ClickExecutor<AXClickExecutionClient>
    private let clickPreparer: TargetApplicationClickPreparer
    private let performanceRecorder: any OverlayClickPerformanceRecording
    private let dateProvider: () -> Date

    init(
        targetResolver: OverlaySessionClickTargetResolver<AXAccessibilityElementClient>? = nil,
        clickExecutor: ClickExecutor<AXClickExecutionClient> = ClickExecutor(
            client: AXClickExecutionClient(),
            configuration: .overlayConfirmedClick
        ),
        clickPreparer: TargetApplicationClickPreparer = TargetApplicationClickPreparer(),
        targetMatcher: OverlayClickTargetMatcher = OverlayClickTargetMatcher(),
        generationStore: AccessibilityTreeGenerationStore? = nil,
        performanceRecorder: (any OverlayClickPerformanceRecording)? = nil,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.targetRevalidator = OverlayClickTargetRevalidator(
            targetResolver: targetResolver ?? OverlaySessionClickTargetResolver(
                client: AXAccessibilityElementClient()
            ),
            targetMatcher: targetMatcher,
            generationStore: generationStore
        )
        self.clickExecutor = clickExecutor
        self.clickPreparer = clickPreparer
        self.performanceRecorder = performanceRecorder ?? OverlayClickPerformanceRecorder()
        self.dateProvider = dateProvider
    }

    func execute(
        selection: OverlayClickSelection,
        context: TargetContext,
        isSecondConfirmProvided: Bool
    ) -> Result<ClickExecutionSuccess, OverlaySessionClickFailure> {
        let startedAt = dateProvider()
        let revalidation = targetRevalidator.revalidate(
            selection: selection,
            context: context
        )
        let resolvedAt = dateProvider()
        let result: Result<ClickExecutionSuccess, OverlaySessionClickFailure>
        switch revalidation {
        case .matched(let target, let metadata, _, let candidateCount):
            let diagnostic = OverlayClickTargetDiagnostic.resolved(
                index: metadata.currentIndex,
                candidateCount: candidateCount,
                target: target
            )
            AppLogger.interaction.info(
                "\(diagnostic, privacy: .public)"
            )
            clickPreparer.prepareForClick(application: context.application)
            let request = ClickExecutionRequest(
                target: target,
                isSecondConfirmProvided: isSecondConfirmProvided
            )
            result = clickExecutor.execute(request).mapError(OverlaySessionClickFailure.executionFailed)
        case .unavailable:
            result = .failure(.selectedTargetUnavailable(labelID: selection.labelID))
        case .changed:
            result = .failure(.selectedTargetChanged(labelID: selection.labelID))
        case .ambiguous:
            result = .failure(.selectedTargetAmbiguous(labelID: selection.labelID))
        case .scanFailed(let failure):
            result = .failure(.scanFailed(failure))
        }

        performanceRecorder.record(
            OverlayClickPerformanceSample(
                rescanMilliseconds: Self.milliseconds(from: startedAt, to: resolvedAt),
                totalMilliseconds: Self.milliseconds(from: startedAt, to: dateProvider()),
                outcome: OverlayClickPerformanceOutcome.code(for: result)
            )
        )
        return result
    }

    private static func milliseconds(from start: Date, to end: Date) -> Int {
        max(0, Int((end.timeIntervalSince(start) * 1_000).rounded()))
    }
}

/// click confirm 시 사용한 target 검증 경로.
///
/// @author suho.do
/// @since 2026-07-17
enum OverlayClickRevalidationPath: String, Equatable {
    case selective
    case fullRescan
}

/// 선택 target 재검증 결과.
///
/// @author suho.do
/// @since 2026-07-17
enum OverlayClickTargetRevalidation<Element> {
    case matched(
        target: ClickTarget<Element>,
        metadata: OverlayClickTargetMatchMetadata,
        path: OverlayClickRevalidationPath,
        candidateCount: Int
    )
    case unavailable(path: OverlayClickRevalidationPath)
    case changed(path: OverlayClickRevalidationPath)
    case ambiguous(path: OverlayClickRevalidationPath)
    case scanFailed(AccessibilityScanFailure)
}

/// generation이 동일하면 선택 path만 검증하고, 불확실하면 기존 전체 scan으로 복귀한다.
///
/// @author suho.do
/// @since 2026-07-17
@MainActor
struct OverlayClickTargetRevalidator<Client: AccessibilityElementClient> {
    private let targetResolver: OverlaySessionClickTargetResolver<Client>
    private let targetMatcher: OverlayClickTargetMatcher
    private let generationStore: AccessibilityTreeGenerationStore?

    init(
        targetResolver: OverlaySessionClickTargetResolver<Client>,
        targetMatcher: OverlayClickTargetMatcher = OverlayClickTargetMatcher(),
        generationStore: AccessibilityTreeGenerationStore? = nil
    ) {
        self.targetResolver = targetResolver
        self.targetMatcher = targetMatcher
        self.generationStore = generationStore
    }

    func revalidate(
        selection: OverlayClickSelection,
        context: TargetContext
    ) -> OverlayClickTargetRevalidation<Client.Element> {
        if shouldUseSelectivePath(selection: selection, context: context),
           let descriptor = selection.targetDescriptor,
           case .success(let target?) = targetResolver.resolveTarget(
               context: context,
               descriptor: descriptor
           ),
           case .matched(let matchedTarget, let metadata) = targetMatcher.match(
               selection: selection,
               currentTargets: [target]
           ) {
            return .matched(
                target: matchedTarget,
                metadata: metadata,
                path: .selective,
                candidateCount: 1
            )
        }

        return revalidateWithFullScan(selection: selection, context: context)
    }

    private func shouldUseSelectivePath(
        selection: OverlayClickSelection,
        context: TargetContext
    ) -> Bool {
        guard selection.isChangeMonitoringActive,
              selection.targetDescriptor != nil,
              let generationStore else {
            return false
        }

        let current = generationStore.snapshot(
            for: context.application.processIdentifier
        )
        return current.isChangeMonitoringActive
            && current.generation == selection.generation
    }

    private func revalidateWithFullScan(
        selection: OverlayClickSelection,
        context: TargetContext
    ) -> OverlayClickTargetRevalidation<Client.Element> {
        switch targetResolver.resolveTargets(context: context) {
        case .success(let targets):
            return mapFullScanMatch(
                targetMatcher.match(selection: selection, currentTargets: targets),
                candidateCount: targets.count
            )
        case .failure(let failure):
            return .scanFailed(failure)
        }
    }

    private func mapFullScanMatch(
        _ match: OverlayClickTargetMatch<Client.Element>,
        candidateCount: Int
    ) -> OverlayClickTargetRevalidation<Client.Element> {
        switch match {
        case .matched(let target, let metadata):
            .matched(
                target: target,
                metadata: metadata,
                path: .fullRescan,
                candidateCount: candidateCount
            )
        case .unavailable:
            .unavailable(path: .fullRescan)
        case .changed:
            .changed(path: .fullRescan)
        case .ambiguous:
            .ambiguous(path: .fullRescan)
        }
    }
}

/// overlay가 key app이 된 뒤에도 실제 click이 대상 app에 전달되도록 준비한다.
///
/// @author suho.do
/// @since 2026-07-04
struct TargetApplicationClickPreparer {
    private let activateApplication: (pid_t) -> Bool

    init(
        activateApplication: @escaping (pid_t) -> Bool = { processIdentifier in
            NSRunningApplication(processIdentifier: processIdentifier)?
                .activate(options: []) ?? false
        }
    ) {
        self.activateApplication = activateApplication
    }

    func prepareForClick(application: TargetApplication) {
        guard activateApplication(application.processIdentifier) else {
            AppLogger.interaction.info(
                "target app activation skipped pid=\(application.processIdentifier, privacy: .public)"
            )
            return
        }

        AppLogger.interaction.info(
            "target app activated pid=\(application.processIdentifier, privacy: .public)"
        )
    }
}

/// scan 순서와 동일한 순서로 click target element를 수집한다.
///
/// @author suho.do
/// @since 2026-07-02
@MainActor
struct OverlaySessionClickTargetResolver<Client: AccessibilityElementClient> {
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

    func resolveTargets(context: TargetContext) -> Result<[ClickTarget<Client.Element>], AccessibilityScanFailure> {
        let startedAt = dateProvider()

        switch client.rootElement(for: context) {
        case .success(let root):
            return .success(resolveTargets(root: root, context: context, startedAt: startedAt))
        case .failure(let failure):
            return .failure(failure)
        }
    }

    /// 최초 scan의 AX path를 따라 선택된 node 하나만 다시 읽는다.
    func resolveTarget(
        context: TargetContext,
        descriptor: AccessibilityTargetDescriptor
    ) -> Result<ClickTarget<Client.Element>?, AccessibilityScanFailure> {
        let root: Client.Element
        switch client.rootElement(for: context) {
        case .success(let resolvedRoot):
            root = resolvedRoot
        case .failure(let failure):
            return .failure(failure)
        }

        var remainingPath = descriptor.axPath[...]
        var element = root
        var depth = 0
        if let first = remainingPath.first, first < 0 {
            let additionalRootIndex = -(first + 1)
            let additionalRoots = client.additionalRootElements(for: context)
            guard additionalRoots.indices.contains(additionalRootIndex) else {
                return .success(nil)
            }
            element = additionalRoots[additionalRootIndex]
            remainingPath = remainingPath.dropFirst()
        }

        for childIndex in remainingPath {
            guard childIndex >= 0 else {
                return .success(nil)
            }
            let children: [Client.Element]
            switch client.children(of: element) {
            case .success(let resolvedChildren):
                children = resolvedChildren
            case .failure(let failure):
                return .failure(failure)
            }
            guard children.indices.contains(childIndex) else {
                return .success(nil)
            }
            element = children[childIndex]
            depth += 1
        }
        return .success(makeTarget(element: element, depth: depth))
    }

    private func resolveTargets(
        root: Client.Element,
        context: TargetContext,
        startedAt: Date
    ) -> [ClickTarget<Client.Element>] {
        var stack: [(element: Client.Element, depth: Int)] = [(root, 0)]
        stack.append(contentsOf: client.additionalRootElements(for: context).map { ($0, 0) })
        var nodesVisited = 0
        var targets: [ClickTarget<Client.Element>] = []
        var targetKeys = Set<ClickTargetKey>()

        while let item = stack.popLast() {
            if nodesVisited >= configuration.maxNodes || isTimedOut(startedAt: startedAt) {
                break
            }

            nodesVisited += 1

            if let target = makeTarget(element: item.element, depth: item.depth),
               targetKeys.insert(ClickTargetKey(target)).inserted {
                targets.append(target)
            }

            guard item.depth < configuration.maxDepth else {
                continue
            }

            if case .success(let children) = client.children(of: item.element) {
                stack.append(contentsOf: children.reversed().map { ($0, item.depth + 1) })
            }
        }

        return targets
    }

    private func makeTarget(element: Client.Element, depth: Int) -> ClickTarget<Client.Element>? {
        guard let role = client.role(of: element),
              role != AccessibilityRole.secureTextField else {
            return nil
        }

        let actions = client.actions(of: element)
        let subrole: String?
        let title: String?
        if clickabilityPolicy.hasClickAction(actions)
            || clickabilityPolicy.isFocusableInput(
                role: role,
                subrole: nil,
                actions: actions
            )
            || (role != AccessibilityRole.image && clickabilityPolicy.isClickableRole(role)) {
            subrole = nil
            title = client.title(of: element)
        } else if role == AccessibilityRole.image {
            subrole = nil
            title = client.title(of: element)
            guard hasSemanticText(in: element, title: title) else {
                return nil
            }
        } else if depth > 0 {
            let inspectedSubrole = client.subrole(of: element)
            guard clickabilityPolicy.isFocusableInput(
                role: role,
                subrole: inspectedSubrole,
                actions: actions
            ) else {
                return nil
            }
            subrole = inspectedSubrole
            title = client.title(of: element)
        } else {
            return nil
        }

        guard let frame = client.frame(of: element),
              frame.width > 0,
              frame.height > 0 else {
            return nil
        }

        return ClickTarget(
            element: element,
            role: role,
            subrole: subrole ?? client.subrole(of: element),
            title: title,
            frame: frame,
            actions: actions
        )
    }

    private func hasSemanticText(in element: Client.Element, title: String?) -> Bool {
        if clickabilityPolicy.hasSemanticText(title: title, value: nil, help: nil) {
            return true
        }

        if clickabilityPolicy.hasSemanticText(title: nil, value: client.value(of: element), help: nil) {
            return true
        }

        return clickabilityPolicy.hasSemanticText(title: nil, value: nil, help: client.help(of: element))
    }

    private func isTimedOut(startedAt: Date) -> Bool {
        dateProvider().timeIntervalSince(startedAt) > configuration.timeout
    }

}

private struct ClickTargetKey: Hashable {
    private let role: String
    private let subrole: String?
    private let x: Int
    private let y: Int
    private let width: Int
    private let height: Int
    private let actions: [String]

    init<Element>(_ target: ClickTarget<Element>) {
        self.role = target.role
        self.subrole = target.subrole
        self.x = Int(target.frame.origin.x.rounded())
        self.y = Int(target.frame.origin.y.rounded())
        self.width = Int(target.frame.width.rounded())
        self.height = Int(target.frame.height.rounded())
        self.actions = target.actions.sorted()
    }
}
