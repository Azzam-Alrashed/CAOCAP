import CoreImage
import CoreMedia
import Foundation
import OSLog
import ReplayKit
import UIKit

/// Captures the app's screen via ReplayKit and emits JPEG frames suitable for Gemini Live.
@MainActor
final class ScreenCaptureController {
    private let logger = Logger(subsystem: "CAOCAP", category: "ScreenCapture")
    private let ciContext = CIContext(options: nil)

    private var isCapturing = false
    private var isStarting = false
    private var startToken = UUID()
    private var lastFrameSentAt: Date = .distantPast
    private let minimumFrameInterval: TimeInterval = 1.0
    private let maxDimension: CGFloat = 768

    var onJPEGFrame: ((Data) -> Void)?
    var onStarted: (() -> Void)?
    var onError: ((Error) -> Void)?

    var isActive: Bool { isCapturing }

    func start() {
        guard !isCapturing, !isStarting else { return }
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable else {
            onError?(ScreenCaptureError.unavailable)
            return
        }

        let token = UUID()
        startToken = token
        isStarting = true
        recorder.isMicrophoneEnabled = false
        recorder.startCapture { [weak self] sampleBuffer, bufferType, error in
            guard let self else { return }
            if let error {
                Task { @MainActor in
                    self.onError?(error)
                }
                return
            }
            guard bufferType == .video else { return }
            Task { @MainActor in
                self.handleVideoSample(sampleBuffer)
            }
        } completionHandler: { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.isStarting = false

                // A newer start/stop superseded this attempt (e.g. user cancelled during the prompt).
                guard self.startToken == token else {
                    if RPScreenRecorder.shared().isRecording {
                        RPScreenRecorder.shared().stopCapture { _ in }
                    }
                    return
                }

                if let error {
                    self.isCapturing = false
                    self.onError?(error)
                    self.logger.error("ReplayKit start failed: \(error.localizedDescription, privacy: .public)")
                } else {
                    self.isCapturing = true
                    self.logger.info("ReplayKit capture started")
                    self.onStarted?()
                }
            }
        }
    }

    func stop() {
        startToken = UUID()
        isStarting = false
        guard isCapturing || RPScreenRecorder.shared().isRecording else {
            isCapturing = false
            return
        }
        RPScreenRecorder.shared().stopCapture { [weak self] error in
            Task { @MainActor in
                self?.isCapturing = false
                if let error {
                    self?.logger.error("ReplayKit stop failed: \(error.localizedDescription, privacy: .public)")
                } else {
                    self?.logger.info("ReplayKit capture stopped")
                }
            }
        }
    }

    private func handleVideoSample(_ sampleBuffer: CMSampleBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastFrameSentAt) >= minimumFrameInterval else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let encodeState = PerformanceSignposts.begin(PerformanceSignposts.Name.screenCaptureEncode)
        defer { PerformanceSignposts.end(PerformanceSignposts.Name.screenCaptureEncode, encodeState) }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let extent = ciImage.extent
        guard extent.width > 1, extent.height > 1 else { return }

        let scale = min(1, maxDimension / max(extent.width, extent.height))
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledExtent = scaled.extent

        guard let cgImage = ciContext.createCGImage(scaled, from: scaledExtent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpeg = uiImage.jpegData(compressionQuality: 0.7) else { return }

        lastFrameSentAt = now
        onJPEGFrame?(jpeg)
    }
}

enum ScreenCaptureError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Screen recording is not available on this device."
        }
    }
}
