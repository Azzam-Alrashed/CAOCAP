import AVFoundation
import Foundation
import OSLog

/// Captures microphone PCM (16-bit LE @ 16 kHz) and plays model audio (16-bit LE @ 24 kHz).
@MainActor
final class CopilotCallAudioEngine {
    private let logger = Logger(subsystem: "CAOCAP", category: "CopilotCallAudio")

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var converter: AVAudioConverter?
    private var isRunning = false
    private var isMuted = false
    private var didAttachPlayer = false

    var onPCMChunk: ((Data) -> Void)?

    func setMuted(_ muted: Bool) {
        isMuted = muted
    }

    func start() throws {
        guard !isRunning else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try session.setActive(true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        ) else {
            throw CopilotCallAudioError.unsupportedFormat
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw CopilotCallAudioError.converterUnavailable
        }
        self.converter = converter

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            guard !self.isMuted, let converter = self.converter else { return }
            guard let data = Self.convert(buffer: buffer, using: converter, to: targetFormat) else {
                return
            }
            Task { @MainActor in
                self.onPCMChunk?(data)
            }
        }

        if !didAttachPlayer {
            engine.attach(playerNode)
            didAttachPlayer = true
        }
        let playbackFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 24_000,
            channels: 1,
            interleaved: false
        )!
        engine.connect(playerNode, to: engine.mainMixerNode, format: playbackFormat)

        engine.prepare()
        try engine.start()
        playerNode.play()
        isRunning = true
        logger.info("Call audio engine started")
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        playerNode.stop()
        engine.stop()
        converter = nil
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        logger.info("Call audio engine stopped")
    }

    func enqueuePlaybackPCM16(_ data: Data) {
        guard isRunning, !data.isEmpty else { return }
        let sampleCount = data.count / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 24_000,
            channels: 1,
            interleaved: false
        ),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount))
        else { return }

        buffer.frameLength = AVAudioFrameCount(sampleCount)
        data.withUnsafeBytes { raw in
            guard let int16 = raw.bindMemory(to: Int16.self).baseAddress,
                  let channel = buffer.floatChannelData?[0]
            else { return }
            for i in 0..<sampleCount {
                channel[i] = Float(int16[i]) / Float(Int16.max)
            }
        }
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
    }

    func clearPlayback() {
        playerNode.stop()
        if isRunning {
            playerNode.play()
        }
    }

    nonisolated private static func convert(
        buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> Data? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }

        var error: NSError?
        var consumedInput = false
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if consumedInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumedInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil, output.frameLength > 0,
              let channel = output.int16ChannelData?[0]
        else {
            return nil
        }

        let byteCount = Int(output.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: channel, count: byteCount)
    }
}

enum CopilotCallAudioError: LocalizedError {
    case unsupportedFormat
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Microphone format is not supported."
        case .converterUnavailable:
            return "Could not convert microphone audio."
        }
    }
}
