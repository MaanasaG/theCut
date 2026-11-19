import AVFoundation
import SwiftUI

/// Short “AI video” lesson: cinematic topic still + Ken Burns motion + optional narration.
struct TopicVideoBackdrop: View {
    var topic: CardTopic
    var isActive: Bool
    var playing: Bool

    @State private var zoomed = false

    var body: some View {
        GeometryReader { geo in
            Image(topic.backdropAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(zoomed ? 1.12 : 1.0)
                .offset(y: zoomed ? -18 : 8)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            CutTheme.ink.opacity(0.35),
                            CutTheme.ink.opacity(0.55),
                            CutTheme.ink.opacity(0.92),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .onAppear { animateIfNeeded() }
                .onChange(of: isActive) { _, active in
                    if active { animateIfNeeded() } else { zoomed = false }
                }
                .onChange(of: playing) { _, _ in animateIfNeeded() }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func animateIfNeeded() {
        guard isActive else { return }
        withAnimation(.easeInOut(duration: playing ? 8 : 12).repeatForever(autoreverses: true)) {
            zoomed = true
        }
    }
}

extension CardTopic {
    var backdropAssetName: String {
        switch self {
        case .systemDesign: return "topic-system-design"
        case .scenarios: return "topic-scenarios"
        case .aiStrategy: return "topic-ai-strategy"
        case .directorBusiness: return "topic-director-business"
        }
    }
}

@MainActor
final class LessonNarrator: ObservableObject {
    static let shared = LessonNarrator()
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false

    func play(title: String, body: String) {
        stop()
        let utterance = AVSpeechUtterance(string: "\(title). \(body)")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        isSpeaking = true
        synthesizer.speak(utterance)
        // Rough end marker — synthesizer delegate would be cleaner later.
        let seconds = max(Double(utterance.speechString.count) / 14.0, 4)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.isSpeaking = false
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}
