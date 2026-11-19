import Foundation

/// Dual transcript contract matching Pomvox: raw verbatim + cleaned readable.
public struct TranscriptionResult: Sendable, Equatable {
    public var raw: String
    public var cleaned: String
    public var timestamps: [WordTimestamp]
    public var fillerCount: Int
    public var wordsPerMinute: Double
    public var pauseCount: Int
    public var durationSeconds: Double

    public init(
        raw: String,
        cleaned: String,
        timestamps: [WordTimestamp] = [],
        fillerCount: Int = 0,
        wordsPerMinute: Double = 0,
        pauseCount: Int = 0,
        durationSeconds: Double = 0
    ) {
        self.raw = raw
        self.cleaned = cleaned
        self.timestamps = timestamps
        self.fillerCount = fillerCount
        self.wordsPerMinute = wordsPerMinute
        self.pauseCount = pauseCount
        self.durationSeconds = durationSeconds
    }
}

public struct WordTimestamp: Sendable, Equatable, Codable {
    public var word: String
    public var start: Double
    public var end: Double

    public init(word: String, start: Double, end: Double) {
        self.word = word
        self.start = start
        self.end = end
    }
}

public enum PomvoxSpeechError: Error, LocalizedError, Sendable {
    case notPrepared
    case microphoneDenied
    case transcriptionFailed(String)
    case emptyAudio

    public var errorDescription: String? {
        switch self {
        case .notPrepared: return "Pomvox speech engine is not ready."
        case .microphoneDenied: return "Microphone access is required for spoken practice."
        case .transcriptionFailed(let msg): return "Transcription failed: \(msg)"
        case .emptyAudio: return "No speech detected."
        }
    }
}
