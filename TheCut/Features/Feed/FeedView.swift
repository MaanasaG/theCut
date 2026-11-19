import SwiftData
import SwiftUI

struct FeedView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query private var spaced: [SpacedCardState]
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
                TabView(selection: $index) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                        FeedCardView(
                            card: card,
                            isFavorite: progress.favoriteCardIDs.contains(card.id),
                            phase: index == i ? recallPhase : .hidden,
                            onToggleFavorite: { toggleFavorite(card) },
                            onStartRecall: { recallPhase = .prompt },
                            onShowAnswer: { recallPhase = .revealed },
                            onScore: { correct in
                                applyRecall(card: card, correct: correct)
                                recallPhase = .hidden
                            }
                        )
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
                .onChange(of: index) { _, _ in
                    recallPhase = .hidden
                }
            }

            VStack {
                filterBar
                Spacer()
            }
            .padding(.top, 8)
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
    case hidden, prompt, revealed
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
    var onToggleFavorite: () -> Void
    var onStartRecall: () -> Void
    var onShowAnswer: () -> Void
    var onScore: (Bool) -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CutTheme.ink, CutTheme.slate, topicAccent.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(card.topic.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(CutTheme.gold)
                    Spacer()
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(CutTheme.ember)
                    }
                }

                Text(card.title)
                    .font(CutTheme.title)
                    .foregroundStyle(CutTheme.paper)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Text(card.body)
                    .font(CutTheme.body)
                    .foregroundStyle(CutTheme.mist)
                    .opacity(appeared ? 1 : 0)

                Spacer()

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
                    }
                    .padding(16)
                    .background(CutTheme.ink.opacity(0.55))
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
                    }
                    .padding(16)
                    .background(CutTheme.ink.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Text("Swipe up for next")
                    .font(CutTheme.caption)
                    .foregroundStyle(CutTheme.mist.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }
            .padding(28)
            .padding(.top, 56)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
        .onChange(of: card.id) { _, _ in
            appeared = false
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
    }

    private var topicAccent: Color {
        switch card.topic {
        case .systemDesign: return CutTheme.ember
        case .scenarios: return CutTheme.gold
        case .aiStrategy: return Color(red: 0.35, green: 0.55, blue: 0.7)
        case .directorBusiness: return Color(red: 0.55, green: 0.4, blue: 0.3)
        }
    }
}
