import AppKit
import SwiftUI

/// full-screen calibration overlay window의 lifecycle과 캡처 타이밍을 관리한다.
///
/// 각 타깃에서 dwell 시간을 채우면 coordinator에 캡처를 요청하고 다음 타깃으로
/// 넘어간다. 모든 타깃을 채우거나 Escape로 취소되면 window를 닫고 결과를 알린다.
/// raw camera frame은 저장하지 않는다.
///
/// @author suho.do
/// @since 2026-07-03
@MainActor
final class GazeCalibrationWindowController {

    private var panel: CalibrationPanel?
    private let state = GazeCalibrationViewState()
    private var coordinator: GazeCalibrationCoordinator?
    private var timer: Timer?
    private var dwellClock: GazeCalibrationDwellClock
    private let tickInterval: TimeInterval
    private let onFinished: (Result<[GazeCalibrationSample], GazeCalibrationFailure>) -> Void

    init(
        dwellSeconds: TimeInterval = 1.2,
        tickInterval: TimeInterval = 1.0 / 30.0,
        onFinished: @escaping (Result<[GazeCalibrationSample], GazeCalibrationFailure>) -> Void = { _ in }
    ) {
        self.dwellClock = GazeCalibrationDwellClock(dwellSeconds: dwellSeconds)
        self.tickInterval = tickInterval
        self.onFinished = onFinished
    }

    /// 지정 화면에 calibration overlay를 띄우고 캡처를 시작한다.
    func present(on screen: NSScreen = NSScreen.main ?? NSScreen.screens[0]) {
        let frame = screen.frame

        let coordinator = GazeCalibrationCoordinator(
            screenBounds: frame,
            onProgress: { [weak self] session in
                Task { @MainActor in
                    self?.applyProgress(session)
                }
            },
            onFinished: { [weak self] result in
                Task { @MainActor in
                    self?.finish(with: result)
                }
            }
        )
        self.coordinator = coordinator

        showPanel(frame: frame)
        coordinator.start()
        startTimer()
    }

    /// 진행 중인 calibration을 취소한다.
    func cancel() {
        coordinator?.cancel()
    }

    private func showPanel(frame: CGRect) {
        let panel = CalibrationPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.onEscape = { [weak self] in
            self?.cancel()
        }
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: GazeCalibrationView(state: state))

        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func startTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        self.timer = timer
    }

    /// 매 tick마다 dwell을 누적하고, 임계값 도달 시 캡처를 시도한다.
    private func tick() {
        guard let coordinator else {
            return
        }

        guard dwellClock.advance(by: tickInterval) else {
            state.dwellProgress = dwellClock.progress
            return
        }

        // dwell 완료: 캡처 시도. feature 미검출이면 즉시 재시도 상태로 되돌린다.
        if coordinator.captureCurrentTarget() {
            dwellClock.reset()
        } else {
            dwellClock.retry()
        }
        state.dwellProgress = dwellClock.progress
    }

    private func applyProgress(_ session: GazeCalibrationSession) {
        state.normalizedTarget = session.currentNormalizedTarget
        state.currentStep = min(session.currentIndex + 1, session.totalTargetCount)
        state.totalSteps = session.totalTargetCount
        dwellClock.reset()
        state.dwellProgress = 0
    }

    private func finish(
        with result: Result<[GazeCalibrationSample], GazeCalibrationFailure>
    ) {
        timer?.invalidate()
        timer = nil
        coordinator = nil

        panel?.orderOut(nil)
        panel = nil

        onFinished(result)
    }
}

extension Notification.Name {
    /// Settings에서 gaze calibration 시작을 요청할 때 게시하는 알림.
    static let gazeCalibrationRequested = Notification.Name("GazeRow.gazeCalibrationRequested")
}

/// Escape로 취소 가능한 calibration 전용 borderless panel.
///
/// @author suho.do
/// @since 2026-07-03
private final class CalibrationPanel: NSPanel {
    var onEscape: () -> Void = {}

    override var canBecomeKey: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        // keyCode 53 = Escape
        if event.keyCode == 53 {
            onEscape()
            return
        }
        super.keyDown(with: event)
    }
}
