import Foundation

/// MVP freeze 전에 기본 기능 정책을 한곳에서 감사한다.
///
/// 실제 기능의 source of truth는 각 구성 타입에 남겨두고, 이 타입은 freeze
/// 체크리스트에서 필요한 기본값을 읽기 전용으로 모아 검증한다.
///
/// @author suho.do
/// @since 2026-07-02
struct MVPDefaultPolicy {

    /// 클릭 실행 기본 설정.
    private let clickConfiguration: ClickExecutionConfiguration

    /// interaction 로그 저장소.
    private let interactionLogStore: InteractionLogStore

    /// debug UI 노출 정책.
    private let debugFeatureVisibility: DebugFeatureVisibility

    /// camera gaze focus opt-in 상태.
    private let cameraGazeSettings: CameraGazeSettings

    init(
        clickConfiguration: ClickExecutionConfiguration = ClickExecutionConfiguration(),
        interactionLogStore: InteractionLogStore = InteractionLogStore(),
        debugFeatureVisibility: DebugFeatureVisibility = DebugFeatureVisibility(),
        cameraGazeSettings: CameraGazeSettings = CameraGazeSettings()
    ) {
        self.clickConfiguration = clickConfiguration
        self.interactionLogStore = interactionLogStore
        self.debugFeatureVisibility = debugFeatureVisibility
        self.cameraGazeSettings = cameraGazeSettings
    }

    /// gaze 기능은 명시 opt-in 전까지 기본값에서 비활성이다.
    var isGazeDisabled: Bool {
        !cameraGazeSettings.isOptInEnabled
    }

    /// camera 권한 요청 경로는 있어도 기본 opt-in은 꺼져 있어야 한다.
    var isCameraGazeOptInDisabled: Bool {
        !cameraGazeSettings.isOptInEnabled
    }

    /// 좌표 클릭 fallback은 기본 off다.
    var isCoordinateFallbackDisabled: Bool {
        !clickConfiguration.isCoordinateFallbackEnabled
    }

    /// 위험 action의 second confirm 요구 여부. 기본값은 off(1회 확인 클릭)다.
    var requiresSecondConfirmForRiskyAction: Bool {
        clickConfiguration.requiresSecondConfirmForRiskyAction
    }

    /// interaction 로그 파일 저장은 기본 opt-in off다.
    var isInteractionLogOptInDisabled: Bool {
        !interactionLogStore.isOptInEnabled
    }

    /// debug export UI는 기본 숨김이다.
    var isDebugExportHidden: Bool {
        !debugFeatureVisibility.isDebugExportVisible
    }

    /// TICKET-011에서 자동으로 확인 가능한 freeze 기본값이 모두 충족됐는지 여부.
    var passesAutomatedFreezeDefaults: Bool {
        isGazeDisabled
            && isCoordinateFallbackDisabled
            && isInteractionLogOptInDisabled
            && isDebugExportHidden
            && isCameraGazeOptInDisabled
    }
}
