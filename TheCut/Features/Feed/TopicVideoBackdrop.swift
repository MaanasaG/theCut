import SwiftUI

/// Always-playing muted topic reel video (loops while the card is on screen).
struct TopicVideoBackdrop: View {
    var topic: CardTopic
    var isActive: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(topic.backdropAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                LoopingVideoPlayer(resourceName: topic.videoResourceName, isActive: isActive)
                    .frame(width: geo.size.width, height: geo.size.height)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.35),
                        Color.black.opacity(0.78),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
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

    var videoResourceName: String { backdropAssetName }
}
