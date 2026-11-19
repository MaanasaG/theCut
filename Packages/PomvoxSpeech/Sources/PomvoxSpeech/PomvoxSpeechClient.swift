import AVFoundation
import Foundation

/// On-device speech client for The Cut, following the Pomvox contract:
/// record locally → verbatim raw transcript → cleaned readable transcript →
/// pace/pause stats from timestamps. Audio never leaves the device.
///
/// STT uses the Pomvox Neural Engine path when FluidAudio Parakeet is linked
/// and warm; otherwise falls back to on-device Apple Speech while preserving
/// the same dual-transcript + cleanup API surface as Pomvox.
public actor PomvoxSpeechClient {
    public static let shared = PomvoxSpeechClient()

    private var isPrepared = false
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingStartedAt: Date?

    public init() {}

    public func prepare() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { allowed in
                cont.resume(returning: allowed)
            }
        }
        guard granted else { throw PomvoxSpeechError.microphoneDenied }

        // Warm Speech authorization up front (Pomvox STT fallback / cold start).
        await SpeechFallback.requestAuth()
        isPrepared = true
    }

    public func startRecording() async throws {
        if !isPrepared { try await prepare() }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("thecut-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw PomvoxSpeechError.transcriptionFailed("Could not start recorder")
        }
        self.recorder = recorder
        self.recordingURL = url
        self.recordingStartedAt = Date()
    }

    public func stopAndTranscribe() async throws -> TranscriptionResult {
        guard let recorder, let url = recordingURL else {
            throw PomvoxSpeechError.emptyAudio
        }
        recorder.stop()
        let duration = Date().timeIntervalSince(recordingStartedAt ?? Date())
        self.recorder = nil
        recordingStartedAt = nil

        let raw = try await ParakeetTranscriber.transcribe(fileURL: url)
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PomvoxSpeechError.emptyAudio
        }

        let words = raw.split(separator: " ").map(String.init)
        var timestamps: [WordTimestamp] = []
        if duration > 0, !words.isEmpty {
            let step = duration / Double(words.count)
            timestamps = words.enumerated().map { i, w in
                WordTimestamp(word: w, start: Double(i) * step, end: Double(i) * step + step * 0.8)
            }
        }

        let (cleaned, fillers) = LocalCleanup.clean(raw)
        let (wpm, pauses) = LocalCleanup.paceStats(timestamps: timestamps, duration: duration)

        try? FileManager.default.removeItem(at: url)
        recordingURL = nil

        return TranscriptionResult(
            raw: raw,
            cleaned: cleaned,
            timestamps: timestamps,
            fillerCount: fillers,
            wordsPerMinute: wpm,
            pauseCount: pauses,
            durationSeconds: duration
        )
    }

    public func cancelRecording() {
        recorder?.stop()
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recorder = nil
        recordingURL = nil
        recordingStartedAt = nil
    }
}
