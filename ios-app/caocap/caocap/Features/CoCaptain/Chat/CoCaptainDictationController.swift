import AVFoundation
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class CoCaptainDictationController {
    var isRecording = false
    var transcript = ""
    var errorMessage: String?

    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInstalledAudioTap = false
    private var seedText = ""

    func start(initialText: String, localeOption: CoCaptainDictationLocaleOption = .auto) async {
        stop(cancelRecognition: true)
        errorMessage = nil

        let recognitionLocale = localeOption.recognitionLocale(for: initialText)
        let speechRecognizer = SFSpeechRecognizer(locale: recognitionLocale)
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "\(localeOption.displayName) dictation is not available right now."
            return
        }

        guard await requestSpeechAuthorization() else {
            errorMessage = "Speech recognition permission is required for dictation."
            return
        }

        guard await requestMicrophoneAuthorization() else {
            errorMessage = "Microphone permission is required for dictation."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        seedText = initialText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try configureAudioSession(with: request)
            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let result {
                        self.transcript = self.composedTranscript(
                            from: result.bestTranscription.formattedString
                        )
                    }

                    if error != nil || result?.isFinal == true {
                        self.stop(cancelRecognition: false)
                    }
                }
            }

            isRecording = true
        } catch {
            errorMessage = "Dictation could not start."
            stop(cancelRecognition: true)
        }
    }

    func stop() {
        stop(cancelRecognition: false)
    }

    private func stop(cancelRecognition: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if hasInstalledAudioTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledAudioTap = false
        }

        if cancelRecognition {
            recognitionTask?.cancel()
        } else {
            recognitionRequest?.endAudio()
        }

        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureAudioSession(with request: SFSpeechAudioBufferRecognitionRequest) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        hasInstalledAudioTap = true

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func composedTranscript(from spokenText: String) -> String {
        guard !seedText.isEmpty else { return spokenText }
        guard !spokenText.isEmpty else { return seedText }
        return "\(seedText) \(spokenText)"
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { isGranted in
                continuation.resume(returning: isGranted)
            }
        }
    }
}

enum CoCaptainDictationLocaleOption: String, CaseIterable, Identifiable {
    case auto
    case arabicSaudiArabia
    case englishUnitedStates

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:
            "Auto"
        case .arabicSaudiArabia:
            "Arabic (Saudi Arabia)"
        case .englishUnitedStates:
            "English (US)"
        }
    }

    var systemImageName: String {
        switch self {
        case .auto:
            "wand.and.stars"
        case .arabicSaudiArabia:
            "textformat"
        case .englishUnitedStates:
            "character.cursor.ibeam"
        }
    }

    func recognitionLocale(for text: String) -> Locale {
        switch self {
        case .auto:
            if text.containsArabicScalars || Locale.preferredLanguages.contains(where: { $0.hasPrefix("ar") }) {
                return Locale(identifier: "ar-SA")
            }

            return .autoupdatingCurrent
        case .arabicSaudiArabia:
            return Locale(identifier: "ar-SA")
        case .englishUnitedStates:
            return Locale(identifier: "en-US")
        }
    }
}

private extension String {
    var containsArabicScalars: Bool {
        unicodeScalars.contains { scalar in
            (0x0600...0x06FF).contains(scalar.value)
            || (0x0750...0x077F).contains(scalar.value)
            || (0x08A0...0x08FF).contains(scalar.value)
            || (0xFB50...0xFDFF).contains(scalar.value)
            || (0xFE70...0xFEFF).contains(scalar.value)
        }
    }
}
