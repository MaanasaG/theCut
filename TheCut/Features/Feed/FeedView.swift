import SwiftData
import SwiftUI

struct FeedView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query private var spaced: [SpacedCardState]
    @StateObject private var narrator = LessonNarrator.shared
    var progress: UserProgress

    @State private var topicFilter: CardTopic? = nil
    @State private var showFavoritesOnly = false
    @State private var index = 0
    @State private var recallPhase: RecallPhase = .hidden

    private var cards: [FeedCard] {
        var list = appModel.selectedPack.cards
        if let topicFilter {
            list = list.filter { $0.topic == topicFilter }
        }
        if showFavoritesOnly {
            list = list.filter { progress.favoriteCardIDs.contains($0.id) }
        } else {
            let dueIDs = Set(spaced.filter { $0.dueDate <= .now }.map(\.cardID))
            list = list.sorted { a, b in
                let ad = dueIDs.contains(a.id)
                let bd = dueIDs.contains(b.id)
                if ad != bd { return ad && !bd }
                return a.id < b.id
            }
        }
        return list
    }

    var body: some View {
        ZStack {
            if cards.isEmpty {
                ContentUnavailableView(
                    "No cards",
                    systemImage: "rectangle.stack",
                    description: Text("Adjust filters or pick an active pack.")
                )
                .foregroundStyle(CutTheme.mist)
            } else {
                VerticalReelPager(items: cards, index: $index) { i, card in
                    FeedCardView(
                        card: card,
                        isFavorite: progress.favoriteCardIDs.contains(card.id),
                        phase: index == i ? recallPhase : .hidden,
                        isActive: index == i,
                        isPlayingVideo: index == i && narrator.isSpeaking,
                        onToggleFavorite: { toggleFavorite(card) },
                        onPlayVideo: {
                            narrator.play(title: card.title, body: card.body)
                        },
                        onStartRecall: { recallPhase = .prompt },
                        onShowAnswer: { recallPhase = .revealed },
                        onTeachMe: { recallPhase = .teaching },
                        onScore: { correct in
                            applyRecall(card: card, correct: correct)
                            recallPhase = .hidden
                        },
                        onTaught: {
                            applyRecall(card: card, correct: false)
                            recallPhase = .hidden
                        }
                    )
                }
                .onChange(of: index) { _, _ in
                    recallPhase = .hidden
                    narrator.stop()
                }
            }

            VStack {
                filterBar
                Spacer()
                Text("Swipe up")
                    .font(CutTheme.caption)
                    .foregroundStyle(CutTheme.paper.opacity(0.7))
                    .padding(.bottom, 28)
            }
            .padding(.top, 8)
            .allowsHitTesting(true)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", selected: topicFilter == nil && !showFavoritesOnly) {
                    topicFilter = nil
                    showFavoritesOnly = false
                    index = 0
                }
                ForEach(CardTopic.allCases) { topic in
                    FilterChip(title: topic.title, selected: topicFilter == topic) {
                        topicFilter = topic
                        showFavoritesOnly = false
                        index = 0
                    }
                }
                FilterChip(title: "Saved", selected: showFavoritesOnly) {
                    showFavoritesOnly = true
                    topicFilter = nil
                    index = 0
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func toggleFavorite(_ card: FeedCard) {
        if let i = progress.favoriteCardIDs.firstIndex(of: card.id) {
            progress.favoriteCardIDs.remove(at: i)
        } else {
            progress.favoriteCardIDs.append(card.id)
        }
    }

    private func applyRecall(card: FeedCard, correct: Bool) {
        progress.recordPractice()
        progress.cardsReviewedToday += 1
        progress.xp += correct ? 10 : 4

        let state: SpacedCardState
        if let existing = spaced.first(where: { $0.cardID == card.id }) {
            state = existing
        } else {
            state = SpacedCardState(cardID: card.id, topic: card.topic)
            modelContext.insert(state)
        }
        state.apply(correct: correct)
        if !correct {
            progress.weakestTopicRaw = card.topic.rawValue
        }
        try? modelContext.save()
    }
}

enum RecallPhase: Equatable {
    case hidden, prompt, revealed, teaching
}

struct FilterChip: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? CutTheme.ink : CutTheme.paper)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? CutTheme.ember : CutTheme.slate.opacity(0.9))
                .clipShape(Capsule())
        }
    }
}

struct FeedCardView: View {
    var card: FeedCard
    var isFavorite: Bool
    var phase: RecallPhase
    var badge: String? = nil
    var isActive: Bool = true
    var isPlayingVideo: Bool = false
    var onToggleFavorite: () -> Void
    var onPlayVideo: () -> Void = {}
    var onStartRecall: () -> Void
    var onShowAnswer: () -> Void
    var onTeachMe: () -> Void = {}
    var onScore: (Bool) -> Void
    var onTaught: () -> Void = {}

    @State private var appeared = false

    var body: some View {
        ZStack {
            TopicVideoBackdrop(topic: card.topic, isActive: isActive, playing: isPlayingVideo)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(card.topic.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(CutTheme.gold)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(CutTheme.ember)
                    }
                    Spacer()
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(CutTheme.ember)
                    }
                }

                Spacer()

                Text(card.title)
                    .font(CutTheme.title)
                    .foregroundStyle(CutTheme.paper)
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                if phase != .teaching {
                    Text(card.body)
                        .font(CutTheme.body)
                        .foregroundStyle(CutTheme.mist)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                        .opacity(appeared ? 1 : 0)
                }

                Button {
                    onPlayVideo()
                } label: {
                    Label(isPlayingVideo ? "Playing lesson…" : "Play AI lesson", systemImage: isPlayingVideo ? "waveform" : "play.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CutTheme.paper)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(CutTheme.ink.opacity(0.55))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(CutTheme.ember.opacity(0.5), lineWidth: 1))
                }

                switch phase {
                case .hidden:
                    Button("One-tap recall", action: onStartRecall)
                        .buttonStyle(CutPrimaryButtonStyle())
                case .prompt:
                    VStack(alignment: .leading, spacing: 12) {
                        Text(card.recallPrompt)
                            .font(.headline)
                            .foregroundStyle(CutTheme.paper)
                        Button("Show answer", action: onShowAnswer)
                            .buttonStyle(CutPrimaryButtonStyle())
                        Button("I don't know — teach me", action: onTeachMe)
                            .buttonStyle(CutSecondaryButtonStyle())
                    }
                    .padding(16)
                    .background(CutTheme.ink.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                case .revealed:
                    VStack(alignment: .leading, spacing: 12) {
                        Text(card.recallPrompt)
                            .font(.headline)
                            .foregroundStyle(CutTheme.paper)
                        Text(card.recallAnswer)
                            .foregroundStyle(CutTheme.gold)
                        HStack {
                            Button("Knew it") { onScore(true) }
                                .buttonStyle(CutPrimaryButtonStyle())
                            Button("Missed") { onScore(false) }
                                .buttonStyle(CutSecondaryButtonStyle())
                        }
                        Button("Teach me more", action: onTeachMe)
                            .buttonStyle(CutSecondaryButtonStyle())
                    }
                    .padding(16)
                    .background(CutTheme.ink.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                case .teaching:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Teach me")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(CutTheme.ember)
                        Text(card.body)
                            .foregroundStyle(CutTheme.mist)
                        Text("Remember this")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(CutTheme.gold)
                        Text(card.recallAnswer)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(CutTheme.paper)
                        Button("Got it — next") { onTaught() }
                            .buttonStyle(CutPrimaryButtonStyle())
                    }
                    .padding(16)
                    .background(CutTheme.ink.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(28)
            .padding(.top, 56)
            .padding(.bottom, 36)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
        .onChange(of: card.id) { _, _ in
            appeared = false
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
    }
}
