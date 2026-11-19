import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Query private var sessions: [PracticeSession]
    var progress: UserProgress

    private var hasAPIKey: Bool {
        !(KeychainStore.anthropicAPIKey ?? "").isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center, spacing: 14) {
                        Image("BrandMark")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(CutTheme.ember.opacity(0.35), lineWidth: 1)
                            )
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("The Cut")
                                .font(CutTheme.display)
                                .foregroundStyle(CutTheme.paper)
                            Text(appModel.selectedPack.name)
                                .font(CutTheme.caption)
                                .foregroundStyle(CutTheme.ember)
                        }
                        Spacer()
                        NavigationLink {
                            SettingsView(progress: progress)
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundStyle(CutTheme.paper)
                                .padding(10)
                                .background(CutTheme.slate)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Settings")
                    }

                    if !hasAPIKey {
                        NavigationLink {
                            SettingsView(progress: progress)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Add your Claude API key")
                                    .font(.headline)
                                    .foregroundStyle(CutTheme.paper)
                                Text("Needed for spoken grading and live interview rounds. Tap here to paste sk-ant-…")
                                    .font(CutTheme.caption)
                                    .foregroundStyle(CutTheme.mist)
                                    .multilineTextAlignment(.leading)
                                Text("Paste key →")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(CutTheme.ink)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(CutTheme.ember)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(CutTheme.slate.opacity(0.95))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(CutTheme.ember.opacity(0.6), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 12) {
                        StatTile(title: "Streak", value: "\(progress.streak)", subtitle: "days")
                        StatTile(title: "XP", value: "\(progress.xp)", subtitle: "total")
                        StatTile(
                            title: "Today",
                            value: "\(progress.cardsReviewedToday)/\(progress.dailyCardGoal)",
                            subtitle: "cards"
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily goal")
                            .font(.headline)
                            .foregroundStyle(CutTheme.paper)
                        ProgressBar(
                            value: Double(progress.cardsReviewedToday),
                            total: Double(max(progress.dailyCardGoal, 1))
                        )
                        Text("Quizzes \(progress.quizzesCompletedToday)/\(progress.dailyQuizGoal)")
                            .font(CutTheme.caption)
                            .foregroundStyle(CutTheme.mist)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weakest topic")
                            .font(.headline)
                            .foregroundStyle(CutTheme.paper)
                        Text(CardTopic(rawValue: progress.weakestTopicRaw)?.title ?? progress.weakestTopicRaw)
                            .foregroundStyle(CutTheme.gold)
                        Text("Missed cards resurface sooner via spaced repetition.")
                            .font(CutTheme.caption)
                            .foregroundStyle(CutTheme.mist)
                    }

                    if let latest = sessions.sorted(by: { $0.createdAt > $1.createdAt }).first {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Latest practice")
                                .font(.headline)
                                .foregroundStyle(CutTheme.paper)
                            Text(latest.prompt)
                                .foregroundStyle(CutTheme.mist)
                                .lineLimit(2)
                            Text(String(format: "Score %.1f · %@", latest.scoreAverage, latest.kind))
                                .font(CutTheme.caption)
                                .foregroundStyle(CutTheme.ember)
                        }
                    }
                }
                .padding(24)
            }
            .background(Color.clear)
            .navigationBarHidden(true)
        }
    }
}

struct StatTile: View {
    var title: String
    var value: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(CutTheme.mist.opacity(0.7))
            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(CutTheme.paper)
                .contentTransition(.numericText())
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(CutTheme.mist)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(CutTheme.slate.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ProgressBar: View {
    var value: Double
    var total: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(CutTheme.slate)
                Capsule()
                    .fill(CutTheme.ember)
                    .frame(width: geo.size.width * min(value / max(total, 1), 1))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
            }
        }
        .frame(height: 10)
    }
}
