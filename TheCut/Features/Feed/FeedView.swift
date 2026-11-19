import SwiftData
import SwiftUI

struct FeedView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query private var spaced: [SpacedCardState]
    @StateObject private var narrator = ReelNarrator.shared
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
            Color.black.ignoresSafeArea()

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
                        onToggleFavorite: { toggleFavorite(card) },
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
                .onChange(of: index) { _, newValue in
                    recallPhase = .hidden
                    narrator.stop()
                    guard cards.indices.contains(newValue) else { return }
                    let card = cards[newValue]
                    narrator.resetCardTracking()
                    narrator.speakIfNeeded(cardID: card.id, title: card.title, body: card.body)
                }
                .onAppear {
                    if let card = cards.first {
                        narrator.speakIfNeeded(cardID: card.id, title: card.title, body: card.body)
                    }
                }
            }

            VStack(spacing: 0) {
                filterBar
                    .padding(.top, 8)
                Spacer()
                Text("Swipe up")
                    .font(CutTheme.caption)
                    .foregroundStyle(CutTheme.paper.opacity(0.75))
                    .padding(.bottom, 12)
                    .allowsHitTesting(false)
            }
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
    var onToggleFavorite: () -> Void
    var onStartRecall: () -> Void
    var onShowAnswer: () -> Void
    var onTeachMe: () -> Void = {}
    var onScore: (Bool) -> Void
    var onTaught: () -> Void = {}

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TopicVideoBackdrop(topic: card.topic, isActive: isActive)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(card.topic.title.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(CutTheme.gold)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(CutTheme.ember)
                        }
                        Spacer(minLength: 8)
                        Button(action: onToggleFavorite) {
                            Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(CutTheme.ember)
                        }
                    }

                    Spacer(minLength: 12)

                    Text(card.title)
                        .font(CutTheme.title)
                        .foregroundStyle(CutTheme.paper)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
                        .opacity(appeared ? 1 : 0)

                    if phase != .teaching {
                        Text(card.body)
                            .font(CutTheme.body)
                            .foregroundStyle(CutTheme.mist)
                            .multilineTextAlignment(.leading)
                            .lineLimit(8)
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
                            .opacity(appeared ? 1 : 0)
                    }

                    Group {
                        switch phase {
                        case .hidden:
                            Button("One-tap recall", action: onStartRecall)
                                .buttonStyle(CutPrimaryButtonStyle())
                        case .prompt:
                            teachPrompt
                        case .revealed:
                            teachRevealed
                        case .teaching:
                            teachPanel
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 44)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
        .onChange(of: card.id) { _, _ in
            appeared = false
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
    }

    private var teachPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.recallPrompt)
                .font(.headline)
                .foregroundStyle(CutTheme.paper)
                .fixedSize(horizontal: false, vertical: true)
            Button("Show answer", action: onShowAnswer)
                .buttonStyle(CutPrimaryButtonStyle())
            Button("I don't know — teach me", action: onTeachMe)
                .buttonStyle(CutSecondaryButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CutTheme.ink.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var teachRevealed: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.recallPrompt)
                .font(.headline)
                .foregroundStyle(CutTheme.paper)
                .fixedSize(horizontal: false, vertical: true)
            Text(card.recallAnswer)
                .foregroundStyle(CutTheme.gold)
                .fixedSize(horizontal: false, vertical: true)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CutTheme.ink.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var teachPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Teach me")
                .font(.caption.weight(.bold))
                .foregroundStyle(CutTheme.ember)
            Text(card.body)
                .foregroundStyle(CutTheme.mist)
                .fixedSize(horizontal: false, vertical: true)
            Text("Remember this")
                .font(.caption.weight(.bold))
                .foregroundStyle(CutTheme.gold)
            Text(card.recallAnswer)
                .font(.title3.weight(.semibold))
                .foregroundStyle(CutTheme.paper)
                .fixedSize(horizontal: false, vertical: true)
            Button("Got it — next") { onTaught() }
                .buttonStyle(CutPrimaryButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CutTheme.ink.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
