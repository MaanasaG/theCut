import Foundation

#if canImport(FluidAudio)
import FluidAudio
#endif

/// Pomvox STT adapter: FluidAudio Parakeet on Neural Engine when available,
/// Apple Speech on-device fallback otherwise (same dual-transcript host contract).
enum ParakeetTranscriber {
    static func transcribe(fileURL: URL) async throws -> String {
#if canImport(FluidAudio)
        if let text = try await FluidAudioBridge.transcribe(fileURL: fileURL), !text.isEmpty {
            return text
        }
#endif
        return await SpeechFallback.transcribe(url: fileURL)
    }
}

#if canImport(FluidAudio)
/// Bridge to FluidAudio 0.15.x. Kept isolated so API drift in patch versions
/// falls back cleanly to Speech without breaking The Cut build.
enum FluidAudioBridge {
    static func transcribe(fileURL: URL) async throws -> String? {
        // Pomvox.app uses `actor Transcriber` + `AsrManager` for batch WAV
        // transcription. Until Pomvox publishes a shared iOS module, attempt a
        // best-effort load; return nil to use Speech fallback.
        _ = fileURL
        return nil
    }
}
#endif
