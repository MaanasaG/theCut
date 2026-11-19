import SwiftUI

struct QuizView: View {
    @Environment(AppModel.self) private var appModel
    var progress: UserProgress

    @State private var quizIndex = 0
    @State private var selectedChoice: Int?
    @State private var showResult = false
    @State private var wasCorrect = false

    /// All quizzes unlocked — every question shows A/B/C/D options.
    private var quizzes: [QuizItem] {
        appModel.selectedPack.quizzes
    }

    private var current: QuizItem? {
        guard !quizzes.isEmpty else { return nil }
        return quizzes[quizIndex % quizzes.count]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Quiz")
                            .font(CutTheme.title)
                            .foregroundStyle(CutTheme.paper)
                        Spacer()
                        Text("\(quizIndex + 1)/\(max(quizzes.count, 1))")
                            .font(CutTheme.caption)
                            .foregroundStyle(CutTheme.ember)
                    }

                    if let quiz = current {
                        Text(quiz.topic.title.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(CutTheme.gold)
                        Text(quiz.prompt)
                            .font(.headline)
                            .foregroundStyle(CutTheme.paper)

                        let choices = quiz.choices ?? []
                        if choices.isEmpty {
                            Text("No options bundled for this question.")
                                .foregroundStyle(CutTheme.ember)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(choices.enumerated()), id: \.offset) { i, choice in
                                    Button {
                                        guard !showResult else { return }
                                        selectedChoice = i
                                    } label: {
                                        HStack(alignment: .top, spacing: 12) {
                                            Text(optionLetter(i))
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(selectedChoice == i ? CutTheme.ink : CutTheme.gold)
                                                .frame(width: 28, height: 28)
                                                .background(selectedChoice == i ? CutTheme.ember : CutTheme.ink.opacity(0.5))
                                                .clipShape(Circle())
                                            Text(choice)
                                                .foregroundStyle(CutTheme.paper)
                                                .multilineTextAlignment(.leading)
                                            Spacer(minLength: 0)
                                        }
                                        .padding(14)
                                        .background(choiceBackground(i, quiz: quiz))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(selectedChoice == i ? CutTheme.ember.opacity(0.7) : .clear, lineWidth: 1)
                                        )
                                    }
                                    .disabled(showResult)
                                }
                            }
                        }

                        if showResult {
                            Text(wasCorrect ? "Correct" : "Not quite")
                                .foregroundStyle(wasCorrect ? CutTheme.success : CutTheme.ember)
                                .font(.headline)
                            Text(quiz.explanation)
                                .foregroundStyle(CutTheme.mist)
                            Button("Next question") { advance() }
                                .buttonStyle(CutPrimaryButtonStyle())
                        } else {
                            Button("Check answer") { check(quiz) }
                                .buttonStyle(CutPrimaryButtonStyle())
                                .disabled(selectedChoice == nil)
                        }
                    } else {
                        ContentUnavailableView("No quizzes", systemImage: "checkmark.circle")
                    }
                }
                .padding(24)
            }
            .navigationBarHidden(true)
        }
    }

    private func optionLetter(_ i: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return i < letters.count ? letters[i] : "\(i + 1)"
    }

    private func choiceBackground(_ i: Int, quiz: QuizItem) -> Color {
        guard showResult else {
            return CutTheme.slate.opacity(0.9)
        }
        if i == quiz.correctIndex {
            return CutTheme.success.opacity(0.35)
        }
        if i == selectedChoice {
            return CutTheme.ember.opacity(0.35)
        }
        return CutTheme.slate.opacity(0.6)
    }

    private func check(_ quiz: QuizItem) {
        let correct = selectedChoice == quiz.correctIndex
        wasCorrect = correct
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showResult = true
        }
        progress.recordPractice()
        progress.quizzesCompletedToday += 1
        progress.xp += correct ? 20 : 6
        if !correct {
            progress.weakestTopicRaw = quiz.topic.rawValue
        }
    }

    private func advance() {
        showResult = false
        selectedChoice = nil
        quizIndex = (quizIndex + 1) % max(quizzes.count, 1)
    }
}
