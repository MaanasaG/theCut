import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @State private var progress: UserProgress?
    @State private var tab: AppTab = .home

    var body: some View {
        ZStack {
            CutTheme.atmosphere
            Group {
                if let progress {
                    if progress.hasCompletedOnboarding {
                        MainTabView(tab: $tab, progress: progress)
                    } else {
                        OnboardingView(progress: progress)
                    }
                } else {
                    ProgressView()
                        .tint(CutTheme.ember)
                }
            }
        }
        .task {
            appModel.loadPacks()
            progress = appModel.ensureProgress(context: modelContext)
        }
    }
}

enum AppTab: Hashable {
    case home, feed, quiz, practice, course, settings
}

struct MainTabView: View {
    @Binding var tab: AppTab
    var progress: UserProgress

    var body: some View {
        TabView(selection: $tab) {
            HomeView(progress: progress)
                .tabItem { Label("Home", systemImage: "flame") }
                .tag(AppTab.home)
            FeedView(progress: progress)
                .tabItem { Label("Feed", systemImage: "rectangle.stack") }
                .tag(AppTab.feed)
            QuizView(progress: progress)
                .tabItem { Label("Quiz", systemImage: "checkmark.circle") }
                .tag(AppTab.quiz)
            PracticeHubView(progress: progress)
                .tabItem { Label("Practice", systemImage: "mic") }
                .tag(AppTab.practice)
            CourseView(progress: progress)
                .tabItem { Label("Course", systemImage: "calendar") }
                .tag(AppTab.course)
            SettingsView(progress: progress)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(CutTheme.ember)
    }
}
