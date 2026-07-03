@preconcurrency import AVFoundation
import CoreVideo
import Foundation

/// AVFoundation 기반 webcam frame provider.
///
/// frame은 메모리에서만 전달하며 저장하지 않는다. 호출자는 Settings opt-in과
/// Camera 권한이 확인된 뒤에만 `start()`를 호출해야 한다.
///
/// @author suho.do
/// @since 2026-07-03
final class CameraFrameProvider: NSObject {

    enum CameraFrameProviderError: Error, Equatable {
        case cameraUnavailable
        case inputCreationFailed
        case inputUnavailable
        case outputUnavailable
    }

    var onFrame: ((CVPixelBuffer) -> Void)?

    private let captureSession: AVCaptureSession
    private let videoOutput: AVCaptureVideoDataOutput
    private let deviceProvider: () -> AVCaptureDevice?
    private let queue = DispatchQueue(label: "dev.local.gazerow.camera.frames")
    private var activeInput: AVCaptureDeviceInput?

    init(
        captureSession: AVCaptureSession = AVCaptureSession(),
        videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput(),
        deviceProvider: @escaping () -> AVCaptureDevice? = {
            AVCaptureDevice.default(for: .video)
        }
    ) {
        self.captureSession = captureSession
        self.videoOutput = videoOutput
        self.deviceProvider = deviceProvider
        super.init()
    }

    func start() throws {
        guard !captureSession.isRunning else {
            return
        }

        guard let device = deviceProvider() else {
            throw CameraFrameProviderError.cameraUnavailable
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraFrameProviderError.inputCreationFailed
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium

        if let activeInput {
            captureSession.removeInput(activeInput)
        }

        guard captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            throw CameraFrameProviderError.inputUnavailable
        }
        captureSession.addInput(input)
        activeInput = input

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)

        guard captureSession.outputs.contains(videoOutput) || captureSession.canAddOutput(videoOutput) else {
            captureSession.commitConfiguration()
            throw CameraFrameProviderError.outputUnavailable
        }

        if !captureSession.outputs.contains(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    func stop() {
        guard captureSession.isRunning else {
            return
        }

        captureSession.stopRunning()
    }
}

extension CameraFrameProvider: GazeFrameProviding {}

extension CameraFrameProvider: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        onFrame?(pixelBuffer)
    }
}
