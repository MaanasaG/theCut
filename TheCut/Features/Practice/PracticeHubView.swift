import SwiftUI

struct PracticeHubView: View {
    var progress: UserProgress

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SpokenPracticeView(progress: progress)
                    } label: {
                        Label("Spoken answers", systemImage: "waveform")
                    }
                    NavigationLink {
                        ScenarioDrillView(progress: progress)
                    } label: {
                        Label("Scenario drill (2 min)", systemImage: "timer")
                    }
                    NavigationLink {
                        SystemDesignMockView(progress: progress)
                    } label: {
                        Label("System design mock (60 min)", systemImage: "clock")
                    }
                    NavigationLink {
                        LiveMockView(progress: progress)
                    } label: {
                        Label("Live Claude rounds", systemImage: "person.wave.2")
                    }
                } header: {
                    Text("Practice")
                } footer: {
                    Text("Audio stays on device. Pomvox transcribes locally; Claude grades content.")
                }

                Section("History") {
                    NavigationLink {
                        PracticeHistoryView()
                    } label: {
                        Label("Score history", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
