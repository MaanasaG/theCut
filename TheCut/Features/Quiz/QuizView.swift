import SwiftData
import SwiftUI

struct QuizView: View {
    @Environment(AppModel.self) private var appModel
    var progress: UserProgress

    @State private var quizIndex = 0
    @State private var selectedChoice: Int?
    @State private var orderDraft: [String] = []
    @State private var showResult = false
    @State private var wasCorrect = false
    @State private var moduleUnlocked = 1

    private var quizzes: [QuizItem] {
        let all = appModel.selectedPack.quizzes
        // Unlock in course order: 1 quiz per "module" level initially, grow with XP.
        let unlockedCount = min(all.count, max(1, progress.xp / 30 + moduleUnlocked))
        return Array(all.prefix(unlockedCount))
    }

    private var current: QuizItem? {
        guard !quizzes.isEmpty else { return nil }
        return quizzes[quizIndex % quizzes.count]
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Quiz")
                        .font(CutTheme.title)
                        .foregroundStyle(CutTheme.paper)
                    Spacer()
                    Text("+\(progress.xp) XP")
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

                    switch quiz.type {
                    case .multipleChoice, .tradeoff, .estimateScale:
                        choiceList(quiz)
                    case .orderSteps:
                        orderList(quiz)
                    }

                    if showResult {
                        Text(wasCorrect ? "Correct" : "Not quite")
                            .foregroundStyle(wasCorrect ? CutTheme.success : CutTheme.ember)
                            .font(.headline)
                            .transition(.scale.combined(with: .opacity))
                        Text(quiz.explanation)
                            .foregroundStyle(CutTheme.mist)
                        Button("Next") { advance() }
                            .buttonStyle(CutPrimaryButtonStyle())
                    } else {
                        Button("Check") { check(quiz) }
                            .buttonStyle(CutPrimaryButtonStyle())
                            .disabled(!canCheck(quiz))
                    }
                } else {
                    ContentUnavailableView("No quizzes", systemImage: "checkmark.circle")
                }

                Spacer()
            }
            .padding(24)
            .navigationBarHidden(true)
            .onAppear { moduleUnlocked = max(1, progress.streak) }
        }
    }

    @ViewBuilder
    private func choiceList(_ quiz: QuizItem) -> some View {
        VStack(spacing: 10) {
            ForEach(Array((quiz.choices ?? []).enumerated()), id: \.offset) { i, choice in
                Button {
                    selectedChoice = i
                } label: {
                    HStack {
                        Text(choice)
                            .foregroundStyle(CutTheme.paper)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if selectedChoice == i {
                            Image(systemName: "circle.inset.filled")
                                .foregroundStyle(CutTheme.ember)
                        }
                    }
                    .padding(14)
                    .background(CutTheme.slate.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private func orderList(_ quiz: QuizItem) -> some View {
        let pool = orderDraft.isEmpty ? (quiz.correctOrder ?? []) : orderDraft
        VStack(spacing: 8) {
            Text("Tap in the correct order")
                .font(CutTheme.caption)
                .foregroundStyle(CutTheme.mist)
            ForEach(pool, id: \.self) { step in
                Button {
                    if orderDraft.isEmpty {
                        orderDraft = pool
                    }
                    if let idx = orderDraft.firstIndex(of: step) {
                        let item = orderDraft.remove(at: idx)
                        orderDraft.append(item)
                    }
                } label: {
                    Text(step)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .foregroundStyle(CutTheme.paper)
                        .background(CutTheme.slate)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            Button("Shuffle") {
                orderDraft = (quiz.correctOrder ?? []).shuffled()
            }
            .buttonStyle(CutSecondaryButtonStyle())
            .onAppear {
                if orderDraft.isEmpty {
                    orderDraft = (quiz.correctOrder ?? []).shuffled()
                }
            }
        }
    }

    private func canCheck(_ quiz: QuizItem) -> Bool {
        switch quiz.type {
        case .orderSteps: return !orderDraft.isEmpty
        default: return selectedChoice != nil
        }
    }

    private func check(_ quiz: QuizItem) {
        let correct: Bool
        switch quiz.type {
        case .orderSteps:
            correct = orderDraft == (quiz.correctOrder ?? [])
        default:
            correct = selectedChoice == quiz.correctIndex
        }
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
        orderDraft = []
        quizIndex += 1
        if quizIndex >= quizzes.count {
            moduleUnlocked += 1
            quizIndex = 0
        }
    }
}
