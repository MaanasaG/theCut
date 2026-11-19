import SwiftData
import SwiftUI

@main
struct TheCutApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            UserProgress.self,
            SpacedCardState.self,
            StoryBankEntry.self,
            PracticeSession.self,
        ])
    }
}
