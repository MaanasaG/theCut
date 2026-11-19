import Foundation
import SwiftData

@Model
final class UserProgress {
    var selectedPackID: String
    var hasCompletedOnboarding: Bool
    var xp: Int
    var streak: Int
    var lastPracticeDay: String // yyyy-MM-dd local
    var cardsReviewedToday: Int
    var quizzesCompletedToday: Int
    var dailyCardGoal: Int
    var dailyQuizGoal: Int
    var monthlySpendUSD: Double
    var monthlySpendCapUSD: Double
    var spendMonthKey: String // yyyy-MM
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var favoriteCardIDs: [String]
    var completedTaskIDs: [String]
    var weakestTopicRaw: String

    init() {
        self.selectedPackID = "directors_cut"
        self.hasCompletedOnboarding = false
        self.xp = 0
        self.streak = 0
        self.lastPracticeDay = ""
        self.cardsReviewedToday = 0
        self.quizzesCompletedToday = 0
        self.dailyCardGoal = 10
        self.dailyQuizGoal = 1
        self.monthlySpendUSD = 0
        self.monthlySpendCapUSD = 25
        self.spendMonthKey = Self.monthKey()
        self.reminderEnabled = false
        self.reminderHour = 8
        self.reminderMinute = 0
        self.favoriteCardIDs = []
        self.completedTaskIDs = []
        self.weakestTopicRaw = CardTopic.systemDesign.rawValue
    }

    static func dayKey(_ date: Date = .now) -> String {
        let f = DateFormatter()
        f.calendar = .current
        f.locale = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func monthKey(_ date: Date = .now) -> String {
        let f = DateFormatter()
        f.calendar = .current
        f.locale = .current
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }

    func rollDayIfNeeded() {
        let today = Self.dayKey()
        if lastPracticeDay != today {
            if !lastPracticeDay.isEmpty {
                let cal = Calendar.current
                if let last = Self.parseDay(lastPracticeDay),
                   let yesterday = cal.date(byAdding: .day, value: -1, to: Date()),
                   Self.dayKey(yesterday) == lastPracticeDay || Self.dayKey(last) == Self.dayKey(yesterday) {
                    // streak continues when practicing next calendar day
                } else if lastPracticeDay != today {
                    // broken streak handled on award
                }
            }
            cardsReviewedToday = 0
            quizzesCompletedToday = 0
        }
        let month = Self.monthKey()
        if spendMonthKey != month {
            spendMonthKey = month
            monthlySpendUSD = 0
        }
    }

    private static func parseDay(_ key: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
    }

    func recordPractice() {
        rollDayIfNeeded()
        let today = Self.dayKey()
        if lastPracticeDay.isEmpty {
            streak = 1
        } else if lastPracticeDay != today {
            let cal = Calendar.current
            if let yesterday = cal.date(byAdding: .day, value: -1, to: Date()),
               lastPracticeDay == Self.dayKey(yesterday) {
                streak += 1
            } else {
                streak = 1
            }
        }
        lastPracticeDay = today
    }
}

@Model
final class SpacedCardState {
    @Attribute(.unique) var cardID: String
    var easiness: Double
    var intervalDays: Int
    var repetitions: Int
    var dueDate: Date
    var lastResult: Bool
    var topicRaw: String

    init(cardID: String, topic: CardTopic) {
        self.cardID = cardID
        self.easiness = 2.5
        self.intervalDays = 0
        self.repetitions = 0
        self.dueDate = .now
        self.lastResult = false
        self.topicRaw = topic.rawValue
    }

    /// SM-2 inspired update.
    func apply(correct: Bool) {
        lastResult = correct
        if correct {
            repetitions += 1
            if repetitions == 1 {
                intervalDays = 1
            } else if repetitions == 2 {
                intervalDays = 3
            } else {
                intervalDays = Int(Double(intervalDays) * easiness)
            }
            easiness = max(1.3, easiness + 0.1)
        } else {
            repetitions = 0
            intervalDays = 0
            easiness = max(1.3, easiness - 0.2)
        }
        dueDate = Calendar.current.date(byAdding: .day, value: max(intervalDays, correct ? 1 : 0), to: .now) ?? .now
    }
}

@Model
final class StoryBankEntry {
    @Attribute(.unique) var themeID: String
    var theme: String
    var likelyQuestion: String
    var story: String
    var number: String

    init(themeID: String, theme: String, likelyQuestion: String, story: String = "", number: String = "") {
        self.themeID = themeID
        self.theme = theme
        self.likelyQuestion = likelyQuestion
        self.story = story
        self.number = number
    }
}

@Model
final class PracticeSession {
    var createdAt: Date
    var kind: String // spoken | live | quiz
    var topic: String
    var prompt: String
    var rawTranscript: String
    var cleanedTranscript: String
    var scoreAverage: Double
    var rubricJSON: String
    var feedback: String
    var hireSignal: String?

    init(
        kind: String,
        topic: String,
        prompt: String,
        rawTranscript: String = "",
        cleanedTranscript: String = "",
        scoreAverage: Double = 0,
        rubricJSON: String = "[]",
        feedback: String = "",
        hireSignal: String? = nil
    ) {
        self.createdAt = .now
        self.kind = kind
        self.topic = topic
        self.prompt = prompt
        self.rawTranscript = rawTranscript
        self.cleanedTranscript = cleanedTranscript
        self.scoreAverage = scoreAverage
        self.rubricJSON = rubricJSON
        self.feedback = feedback
        self.hireSignal = hireSignal
    }
}
