import Foundation

/// 첫 실행 안내, Known Limitations, 앱 지원 범위 등 사용자 노출 정적 콘텐츠.
///
/// TICKET-009 범위. UI 문구를 한곳에서 관리해 Onboarding/Settings/README가
/// 같은 내용을 참조하게 한다.
///
/// @author suho.do
/// @since 2026-07-02
enum AppContent {

    /// 앱 지원 등급.
    enum SupportTier {
        /// MVP 기준 앱으로 task 검증 대상.
        case supported
        /// 동작하지만 후보/클릭에 제약이 있는 앱.
        case limited
        /// 평가했지만 현재 후보 수집 또는 대표 task 수행이 불가능한 앱.
        case unsupported
        /// 아직 검증하지 않은 앱.
        case unverified
    }

    /// 앱 지원성 표시 항목.
    struct AppSupport: Identifiable {
        let id = UUID()
        let name: String
        let tier: SupportTier
    }

    // MARK: - Disclaimers

    /// 접근성/의료 보조 제품이 아님을 밝히는 문구.
    static let nonMedicalDisclaimer = """
    GazeRow is a productivity utility for keyboard-centric users. It is not an \
    accessibility or assistive-technology product, and is not intended for \
    medical or safety-critical use.
    """

    /// 좌표 클릭 fallback이 기본 비활성임을 알리는 문구.
    static let fallbackDisabledNotice = """
    Coordinate-based click fallback (CGEventPost) is disabled by default to \
    reduce the risk of mis-clicks. Clicks use supported accessibility actions.
    """

    /// 첫 실행 안내에서 소개하는 setup 단계.
    static let setupSteps: [String] = [
        "Grant Accessibility permission in System Settings.",
        "Return to GazeRow and press Recheck to confirm the status.",
        "Open the overlay with the shortcut, focus an element, and confirm with a key."
    ]

    // MARK: - Known Limitations

    /// 사용자에게 노출하는 알려진 제한사항.
    static let knownLimitations: [String] = [
        "Only the frontmost app's focused window is scanned.",
        "Some apps expose an incomplete accessibility tree, so candidates may be missing.",
        "Clicks rely on accessibility actions such as AXPress, AXConfirm, AXOpen, and AXShowDefaultUI; elements without a supported action may not be actionable.",
        "Coordinate-click fallback is off by default and must be enabled in debug.",
        "All clicks require explicit keyboard confirmation; there is no auto-click.",
        "Gaze/camera features are Post-MVP and disabled in this build.",
        "Slack currently exposes only window-control candidates in the Post-MVP smoke test.",
        "Discord currently returns no clickable candidates in the Post-MVP smoke test."
    ]

    // MARK: - Diagnostics

    /// interaction 로그 저장 opt-in 토글 안내 문구.
    static let interactionLoggingNotice = """
    When enabled, GazeRow stores minimal interaction events (focus/click) locally. \
    Window titles are stored only as a per-session hash; raw titles and text values \
    are never written.
    """

    /// debug export 안내 문구.
    static let debugExportNotice = """
    Debug Export saves a plain-text snapshot of current diagnostics for \
    troubleshooting. It does not include raw window titles or text values.
    """

    // MARK: - App Support

    /// 지원/제한/미확인 앱 구분 목록.
    static let appSupport: [AppSupport] = [
        AppSupport(name: "Finder", tier: .supported),
        AppSupport(name: "Safari", tier: .supported),
        AppSupport(name: "Chrome", tier: .supported),
        AppSupport(name: "VS Code", tier: .supported),
        AppSupport(name: "System Settings", tier: .supported),
        AppSupport(name: "Slack", tier: .limited),
        AppSupport(name: "Notion", tier: .supported),
        AppSupport(name: "Discord", tier: .unsupported),
        AppSupport(name: "Obsidian", tier: .unverified)
    ]
}
