import PomvoxSpeech
import SwiftData
import SwiftUI

struct ScenarioDrillView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    var progress: UserProgress

    @State private var prompt: FeedCard?
    @State private var secondsLeft = 120
    @State private var timerRunning = false
    @State private var isRecording = false
    @State private var grade: GradeResult?
    @State private var errorText: String?
    @State private var ticker: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scenario drill")
                .font(CutTheme.title)
                .foregroundStyle(CutTheme.paper)
            Text(prompt?.body ?? "Loading…")
                .foregroundStyle(CutTheme.mist)

            Text(timeLabel)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(secondsLeft <= 20 ? CutTheme.ember : CutTheme.paper)
                .contentTransition(.numericText())

            HStack {
                Button(timerRunning ? "Pause" : "Start 2:00") {
                    toggleTimer()
                }
                .buttonStyle(CutSecondaryButtonStyle())

                if isRecording {
                    Button("Stop & grade") {
                        Task { await finish() }
                    }
                    .buttonStyle(CutPrimaryButtonStyle())
                } else {
                    Button("Record") {
                        Task { await beginRecord() }
                    }
                    .buttonStyle(CutPrimaryButtonStyle())
                    .disabled(prompt == nil)
                }
            }

            Button("New question") { drawPrompt() }
                .buttonStyle(CutSecondaryButtonStyle())

            if let errorText {
                Text(errorText).foregroundStyle(CutTheme.ember)
            }
            if let grade {
                GradeCard(grade: grade)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { drawPrompt() }
        .onDisappear { ticker?.invalidate() }
    }

    private var timeLabel: String {
        String(format: "%d:%02d", secondsLeft / 60, secondsLeft % 60)
    }

    private func drawPrompt() {
        let pool = appModel.selectedPack.cards.filter { $0.kind == .storyPrompt }
        prompt = pool.randomElement()
        secondsLeft = 120
        grade = nil
        errorText = nil
    }

    private func toggleTimer() {
        if timerRunning {
            ticker?.invalidate()
            timerRunning = false
        } else {
            timerRunning = true
            ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in
                    if secondsLeft > 0 {
                        secondsLeft -= 1
                    } else {
                        ticker?.invalidate()
                        timerRunning = false
                    }
                }
            }
        }
    }

    private func beginRecord() async {
        do {
            try await PomvoxSpeechClient.shared.prepare()
            try await PomvoxSpeechClient.shared.startRecording()
            isRecording = true
            if !timerRunning { toggleTimer() }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func finish() async {
        isRecording = false
        ticker?.invalidate()
        timerRunning = false
        guard let prompt else { return }
        do {
            let result = try await PomvoxSpeechClient.shared.stopAndTranscribe()
            let graded = try await ClaudeClient.shared.gradeSpokenAnswer(
                prompt: prompt.body,
                raw: result.raw,
                cleaned: result.cleaned,
                fillerCount: result.fillerCount,
                wpm: result.wordsPerMinute,
                rubric: appModel.selectedPack.scenarioRubric,
                kind: "scenario",
                progress: progress
            )
            grade = graded
            modelContext.insert(PracticeSession(
                kind: "spoken",
                topic: prompt.topic.rawValue,
                prompt: prompt.title,
                rawTranscript: result.raw,
                cleanedTranscript: result.cleaned,
                scoreAverage: graded.average,
                feedback: graded.coaching
            ))
            progress.xp += Int(graded.average * 8)
            progress.recordPractice()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
