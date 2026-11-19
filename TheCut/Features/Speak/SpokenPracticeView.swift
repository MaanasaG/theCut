import PomvoxSpeech
import SwiftData
import SwiftUI

struct SpokenPracticeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    var progress: UserProgress

    @State private var selectedCard: FeedCard?
    @State private var isRecording = false
    @State private var isBusy = false
    @State private var errorText: String?
    @State private var transcript: TranscriptionResult?
    @State private var grade: GradeResult?

    private var prompts: [FeedCard] {
        appModel.selectedPack.cards.filter {
            $0.kind == .interviewQuestion || $0.kind == .storyPrompt || $0.kind == .directorBusiness
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Spoken answers")
                    .font(CutTheme.title)
                    .foregroundStyle(CutTheme.paper)
                Text("Record → Pomvox on-device transcript (raw + cleaned) → Claude rubric grade.")
                    .font(CutTheme.caption)
                    .foregroundStyle(CutTheme.mist)

                Picker("Prompt", selection: $selectedCard) {
                    Text("Select a prompt").tag(Optional<FeedCard>.none)
                    ForEach(prompts) { card in
                        Text(card.title).tag(Optional(card))
                    }
                }
                .pickerStyle(.navigationLink)
                .foregroundStyle(CutTheme.paper)

                if let selectedCard {
                    Text(selectedCard.body)
                        .foregroundStyle(CutTheme.mist)
                        .padding(12)
                        .background(CutTheme.slate.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                HStack {
                    if isRecording {
                        Button("Stop & grade") {
                            Task { await stopAndGrade() }
                        }
                        .buttonStyle(CutPrimaryButtonStyle())
                    } else {
                        Button(isBusy ? "Working…" : "Record answer") {
                            Task { await start() }
                        }
                        .buttonStyle(CutPrimaryButtonStyle())
                        .disabled(selectedCard == nil || isBusy)
                    }
                }

                if let errorText {
                    Text(errorText).foregroundStyle(CutTheme.ember)
                }

                if let transcript {
                    Group {
                        Text("Raw").font(.caption.weight(.bold)).foregroundStyle(CutTheme.gold)
                        Text(transcript.raw).foregroundStyle(CutTheme.mist)
                        Text("Cleaned").font(.caption.weight(.bold)).foregroundStyle(CutTheme.gold)
                        Text(transcript.cleaned).foregroundStyle(CutTheme.paper)
                        Text("Fillers \(transcript.fillerCount) · \(Int(transcript.wordsPerMinute)) wpm · pauses \(transcript.pauseCount)")
                            .font(CutTheme.caption)
                            .foregroundStyle(CutTheme.mist)
                    }
                }

                if let grade {
                    GradeCard(grade: grade)
                }
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedCard == nil {
                selectedCard = prompts.first
            }
        }
    }

    private func start() async {
        errorText = nil
        grade = nil
        transcript = nil
        do {
            try await PomvoxSpeechClient.shared.prepare()
            try await PomvoxSpeechClient.shared.startRecording()
            isRecording = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func stopAndGrade() async {
        isRecording = false
        isBusy = true
        defer { isBusy = false }
        guard let selectedCard else { return }
        do {
            let result = try await PomvoxSpeechClient.shared.stopAndTranscribe()
            transcript = result
            let rubric = selectedCard.topic == .systemDesign || selectedCard.kind == .interviewQuestion
                ? appModel.selectedPack.systemDesignRubric
                : appModel.selectedPack.scenarioRubric
            let kind = selectedCard.kind == .interviewQuestion ? "system_design" : "scenario"
            let graded = try await ClaudeClient.shared.gradeSpokenAnswer(
                prompt: selectedCard.body,
                raw: result.raw,
                cleaned: result.cleaned,
                fillerCount: result.fillerCount,
                wpm: result.wordsPerMinute,
                rubric: rubric.isEmpty ? defaultRubric : rubric,
                kind: kind,
                progress: progress
            )
            grade = graded
            let session = PracticeSession(
                kind: "spoken",
                topic: selectedCard.topic.rawValue,
                prompt: selectedCard.title,
                rawTranscript: result.raw,
                cleanedTranscript: result.cleaned,
                scoreAverage: graded.average,
                rubricJSON: (try? String(data: JSONEncoder().encode(graded.rubricScores), encoding: .utf8)) ?? "[]",
                feedback: graded.coaching
            )
            modelContext.insert(session)
            progress.recordPractice()
            progress.xp += Int(graded.average * 8)
            try? modelContext.save()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private var defaultRubric: [RubricItem] {
        [
            RubricItem(id: "r1", label: "Substance", description: "Answer has concrete content"),
            RubricItem(id: "r2", label: "Structure", description: "Clear shape"),
            RubricItem(id: "r3", label: "Director signal", description: "Judgment and leadership"),
        ]
    }
}

struct GradeCard: View {
    var grade: GradeResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(format: "Average %.1f / 5", grade.average))
                .font(.headline)
                .foregroundStyle(CutTheme.ember)
            ForEach(grade.rubricScores) { item in
                HStack {
                    Text(item.label).foregroundStyle(CutTheme.paper)
                    Spacer()
                    Text("\(item.score)")
                        .foregroundStyle(CutTheme.gold)
                }
                Text(item.note)
                    .font(CutTheme.caption)
                    .foregroundStyle(CutTheme.mist)
            }
            Text("Model outline").font(.caption.weight(.bold)).foregroundStyle(CutTheme.gold)
            Text(grade.modelOutline).foregroundStyle(CutTheme.mist)
            Text("Coaching").font(.caption.weight(.bold)).foregroundStyle(CutTheme.gold)
            Text(grade.coaching).foregroundStyle(CutTheme.paper)
            Text("One thing to fix: \(grade.oneThingToFix)")
                .foregroundStyle(CutTheme.ember)
            if let hire = grade.hireSignal {
                Text("Signal: \(hire)").foregroundStyle(CutTheme.gold)
            }
        }
        .padding(14)
        .background(CutTheme.slate.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
