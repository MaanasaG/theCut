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
                Section("Eight-week course") {
                    ForEach(appModel.selectedPack.courseWeeks) { week in
                        NavigationLink {
                            WeekDetailView(week: week, progress: progress)
                        } label: {
                            HStack {
                                WeekRing(progress: weekProgress(week))
                                VStack(alignment: .leading) {
                                    Text("Week \(week.week): \(week.title)")
                                        .foregroundStyle(CutTheme.paper)
                                    Text("\(completedCount(week))/\(week.tasks.count) tasks")
                                        .font(CutTheme.caption)
                                        .foregroundStyle(CutTheme.mist)
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

    private func completedCount(_ week: CourseWeek) -> Int {
        week.tasks.filter { progress.completedTaskIDs.contains($0.id) }.count
    }

    private func weekProgress(_ week: CourseWeek) -> Double {
        guard !week.tasks.isEmpty else { return 0 }
        return Double(completedCount(week)) / Double(week.tasks.count)
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

struct WeekDetailView: View {
    var week: CourseWeek
    var progress: UserProgress

    var body: some View {
        List {
            ForEach(week.tasks) { task in
                HStack(alignment: .top) {
                    Button {
                        toggle(task.id)
                    } label: {
                        Image(systemName: progress.completedTaskIDs.contains(task.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(CutTheme.ember)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .foregroundStyle(CutTheme.paper)
                        if let url = task.url, let link = URL(string: url) {
                            Link("Open in Safari", destination: link)
                                .font(CutTheme.caption)
                                .foregroundStyle(CutTheme.gold)
                        }
                    }
                }
                .listRowBackground(CutTheme.slate.opacity(0.7))
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Week \(week.week)")
    }

    private func toggle(_ id: String) {
        if let i = progress.completedTaskIDs.firstIndex(of: id) {
            progress.completedTaskIDs.remove(at: i)
        } else {
            progress.completedTaskIDs.append(id)
            progress.recordPractice()
            progress.xp += 5
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
