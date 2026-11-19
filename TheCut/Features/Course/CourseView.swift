import SwiftData
import SwiftUI

struct CourseView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query private var stories: [StoryBankEntry]
    var progress: UserProgress

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Each week is a reel. Swipe the cards — that’s the course. No Safari homework.")
                        .font(CutTheme.caption)
                        .foregroundStyle(CutTheme.mist)
                        .listRowBackground(Color.clear)
                }

                Section("Eight-week course") {
                    ForEach(appModel.selectedPack.courseWeeks) { week in
                        NavigationLink {
                            WeekReelView(week: week, progress: progress)
                        } label: {
                            HStack(spacing: 14) {
                                WeekRing(progress: weekProgress(week))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Week \(week.week): \(week.title)")
                                        .foregroundStyle(CutTheme.paper)
                                    Text("\(watchedCount(week))/\(max(week.reelCardIds.count, 1)) reels watched")
                                        .font(CutTheme.caption)
                                        .foregroundStyle(CutTheme.mist)
                                    if !week.summary.isEmpty {
                                        Text(week.summary)
                                            .font(.caption2)
                                            .foregroundStyle(CutTheme.mist.opacity(0.85))
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Story bank") {
                    NavigationLink("Edit stories & numbers") {
                        StoryBankView(progress: progress)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Course")
            .onAppear { seedStoriesIfNeeded() }
        }
    }

    private func watchedCount(_ week: CourseWeek) -> Int {
        week.reelCardIds.filter { progress.completedTaskIDs.contains(weekWatchID(week.id, $0)) }.count
    }

    private func weekProgress(_ week: CourseWeek) -> Double {
        let total = max(week.reelCardIds.count, 1)
        return Double(watchedCount(week)) / Double(total)
    }

    private func seedStoriesIfNeeded() {
        for theme in appModel.selectedPack.storyThemes {
            if stories.contains(where: { $0.themeID == theme.id }) { continue }
            modelContext.insert(StoryBankEntry(
                themeID: theme.id,
                theme: theme.theme,
                likelyQuestion: theme.likelyQuestion
            ))
        }
        try? modelContext.save()
    }
}

func weekWatchID(_ weekID: String, _ cardID: String) -> String {
    "\(weekID)::\(cardID)"
}

struct WeekRing: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(CutTheme.slate, lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(CutTheme.ember, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
            Text("\(Int(progress * 100))%")
                .font(.caption2.weight(.bold))
                .foregroundStyle(CutTheme.paper)
        }
        .frame(width: 44, height: 44)
    }
}

/// Full-screen vertical reel for one course week — watching marks progress.
struct WeekReelView: View {
    @Environment(AppModel.self) private var appModel
    @StateObject private var narrator = LessonNarrator.shared
    var week: CourseWeek
    var progress: UserProgress

    @State private var index = 0
    @State private var recallPhase: RecallPhase = .hidden

    private var cards: [FeedCard] {
        let byID = Dictionary(uniqueKeysWithValues: appModel.selectedPack.cards.map { ($0.id, $0) })
        return week.reelCardIds.compactMap { byID[$0] }
    }

    var body: some View {
        ZStack {
            if cards.isEmpty {
                ContentUnavailableView("No reels yet", systemImage: "film", description: Text("This week has no cards bundled."))
            } else {
                VerticalReelPager(items: cards, index: $index) { i, card in
                    FeedCardView(
                        card: card,
                        isFavorite: progress.favoriteCardIDs.contains(card.id),
                        phase: index == i ? recallPhase : .hidden,
                        badge: "Week \(week.week) · \(i + 1)/\(cards.count)",
                        isActive: index == i,
                        isPlayingVideo: index == i && narrator.isSpeaking,
                        onToggleFavorite: {
                            if let j = progress.favoriteCardIDs.firstIndex(of: card.id) {
                                progress.favoriteCardIDs.remove(at: j)
                            } else {
                                progress.favoriteCardIDs.append(card.id)
                            }
                        },
                        onPlayVideo: {
                            narrator.play(title: card.title, body: card.body)
                        },
                        onStartRecall: { recallPhase = .prompt },
                        onShowAnswer: { recallPhase = .revealed },
                        onTeachMe: { recallPhase = .teaching },
                        onScore: { correct in
                            markWatched(card)
                            applySoftRecall(card: card, correct: correct)
                            recallPhase = .hidden
                            advanceIfNeeded()
                        },
                        onTaught: {
                            markWatched(card)
                            applySoftRecall(card: card, correct: false)
                            recallPhase = .hidden
                            advanceIfNeeded()
                        }
                    )
                }
                .onChange(of: index) { _, newValue in
                    recallPhase = .hidden
                    narrator.stop()
                    if newValue < cards.count {
                        markWatched(cards[newValue])
                    }
                }
                .onAppear {
                    if let first = cards.first {
                        markWatched(first)
                    }
                }
            }
        }
        .navigationTitle("Week \(week.week)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(watched)/\(cards.count)")
                    .font(CutTheme.caption)
                    .foregroundStyle(CutTheme.ember)
            }
        }
    }

    private var watched: Int {
        cards.filter { progress.completedTaskIDs.contains(weekWatchID(week.id, $0.id)) }.count
    }

    private func markWatched(_ card: FeedCard) {
        let id = weekWatchID(week.id, card.id)
        if !progress.completedTaskIDs.contains(id) {
            progress.completedTaskIDs.append(id)
            progress.recordPractice()
            progress.xp += 3
            progress.cardsReviewedToday += 1
        }
    }

    private func applySoftRecall(card: FeedCard, correct: Bool) {
        if !correct {
            progress.weakestTopicRaw = card.topic.rawValue
        }
        progress.xp += correct ? 6 : 2
    }

    private func advanceIfNeeded() {
        if index + 1 < cards.count {
            withAnimation { index += 1 }
        }
    }
}

struct StoryBankView: View {
    @Query(sort: \StoryBankEntry.theme) private var stories: [StoryBankEntry]
    var progress: UserProgress

    var body: some View {
        List {
            ForEach(stories) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.theme)
                        .font(.headline)
                        .foregroundStyle(CutTheme.paper)
                    Text(entry.likelyQuestion)
                        .font(CutTheme.caption)
                        .foregroundStyle(CutTheme.mist)
                    TextField("Your story", text: Binding(
                        get: { entry.story },
                        set: { entry.story = $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                    TextField("Number (metric)", text: Binding(
                        get: { entry.number },
                        set: { entry.number = $0 }
                    ))
                }
                .listRowBackground(CutTheme.slate.opacity(0.75))
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Story bank")
    }
}
