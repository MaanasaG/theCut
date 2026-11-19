import AVFoundation
import PomvoxSpeech
import SwiftData
import SwiftUI

struct LiveMockView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    var progress: UserProgress

    @State private var roundID: String = "mr-sc"
    @State private var minutes: Int = 15
    @State private var companyStyle = "growth company"
    @State private var secondsLeft = 15 * 60
    @State private var running = false
    @State private var history: [LiveTurn] = []
    @State private var isRecording = false
    @State private var busy = false
    @State private var errorText: String?
    @State private var grade: GradeResult?
    @State private var ticker: Timer?
    @State private var synthesizer = AVSpeechSynthesizer()

    private var roundName: String {
        appModel.selectedPack.mockRoundTypes.first(where: { $0.id == roundID })?.name ?? "Scenario round"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Live Claude rounds")
                    .font(CutTheme.title)
                    .foregroundStyle(CutTheme.paper)

                Picker("Round", selection: $roundID) {
                    ForEach(appModel.selectedPack.mockRoundTypes) { r in
                        Text(r.name).tag(r.id)
                    }
                }
                .pickerStyle(.menu)

                Picker("Length", selection: $minutes) {
                    Text("15 min").tag(15)
                    Text("20 min").tag(20)
                }
                .pickerStyle(.segmented)
                .onChange(of: minutes) { _, v in
                    if !running { secondsLeft = v * 60 }
                }

                Picker("Company style", selection: $companyStyle) {
                    Text("Google").tag("Google")
                    Text("Meta").tag("Meta")
                    Text("Growth company").tag("growth company")
                    Text("AI startup").tag("AI startup")
                }
                .pickerStyle(.menu)

                Text(timeLabel)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(CutTheme.paper)

                if !running {
                    Button("Start round") { Task { await startRound() } }
                        .buttonStyle(CutPrimaryButtonStyle())
                } else {
                    if isRecording {
                        Button("Send answer") { Task { await sendAnswer() } }
                            .buttonStyle(CutPrimaryButtonStyle())
                    } else {
                        Button(busy ? "Interviewer thinking…" : "Answer by voice") {
                            Task { await beginAnswer() }
                        }
                        .buttonStyle(CutPrimaryButtonStyle())
                        .disabled(busy)
                    }
                    Button("End & scorecard") { Task { await endRound() } }
                        .buttonStyle(CutSecondaryButtonStyle())
                }

                ForEach(Array(history.enumerated()), id: \.offset) { _, turn in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(turn.role.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(turn.role == "interviewer" ? CutTheme.gold : CutTheme.ember)
                        Text(turn.text)
                            .foregroundStyle(CutTheme.paper)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CutTheme.slate.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if let errorText {
                    Text(errorText).foregroundStyle(CutTheme.ember)
                }
                if let grade {
                    GradeCard(grade: grade)
                }
            }
            .padding(24)
        }
        .onDisappear {
            ticker?.invalidate()
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private var timeLabel: String {
        String(format: "%d:%02d", secondsLeft / 60, secondsLeft % 60)
    }

    private func startRound() async {
        grade = nil
        errorText = nil
        history = []
        secondsLeft = minutes * 60
        running = true
        startTicker()
        await askInterviewer()
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if secondsLeft > 0 {
                    secondsLeft -= 1
                } else {
                    ticker?.invalidate()
                    Task { await endRound() }
                }
            }
        }
    }

    private func askInterviewer() async {
        busy = true
        defer { busy = false }
        do {
            let reply = try await ClaudeClient.shared.liveInterviewerReply(
                roundName: roundName,
                companyStyle: companyStyle,
                minutesRemaining: max(secondsLeft / 60, 0),
                history: history.isEmpty
                    ? [LiveTurn(role: "system", text: "Begin the interview now with an opening question.")]
                    : history,
                progress: progress
            )
            history.append(LiveTurn(role: "interviewer", text: reply))
            speak(reply)
            if reply.contains("ROUND_COMPLETE") {
                await endRound()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synthesizer.speak(utterance)
    }

    private func beginAnswer() async {
        do {
            try await PomvoxSpeechClient.shared.prepare()
            try await PomvoxSpeechClient.shared.startRecording()
            isRecording = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func sendAnswer() async {
        isRecording = false
        do {
            let result = try await PomvoxSpeechClient.shared.stopAndTranscribe()
            history.append(LiveTurn(role: "candidate", text: result.cleaned))
            await askInterviewer()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func endRound() async {
        running = false
        ticker?.invalidate()
        busy = true
        defer { busy = false }
        let transcript = history.map { "\($0.role): \($0.text)" }.joined(separator: "\n")
        do {
            let graded = try await ClaudeClient.shared.gradeSpokenAnswer(
                prompt: "Live \(roundName) (\(companyStyle))",
                raw: transcript,
                cleaned: transcript,
                fillerCount: 0,
                wpm: 0,
                rubric: appModel.selectedPack.scenarioRubric + appModel.selectedPack.systemDesignRubric,
                kind: "live",
                progress: progress
            )
            grade = graded
            modelContext.insert(PracticeSession(
                kind: "live",
                topic: roundID,
                prompt: roundName,
                rawTranscript: transcript,
                cleanedTranscript: transcript,
                scoreAverage: graded.average,
                feedback: graded.coaching,
                hireSignal: graded.hireSignal
            ))
            progress.xp += Int(graded.average * 10)
            progress.recordPractice()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
