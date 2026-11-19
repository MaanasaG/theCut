import Foundation

enum CardTopic: String, Codable, CaseIterable, Identifiable, Hashable {
    case systemDesign = "system_design"
    case scenarios
    case aiStrategy = "ai_strategy"
    case directorBusiness = "director_business"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemDesign: return "System Design"
        case .scenarios: return "Scenarios"
        case .aiStrategy: return "AI Strategy"
        case .directorBusiness: return "Director Business"
        }
    }
}

enum CardKind: String, Codable, Hashable {
    case concept
    case tradeoff
    case frameworkStep = "framework_step"
    case interviewQuestion = "interview_question"
    case storyPrompt = "story_prompt"
    case directorBusiness = "director_business"
}

struct RolePack: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var focus: String
    var active: Bool
    var cards: [FeedCard]
    var quizzes: [QuizItem]
    var storyThemes: [StoryTheme]
    var courseWeeks: [CourseWeek]
    var systemDesignRubric: [RubricItem]
    var scenarioRubric: [RubricItem]
    var sdClockPhases: [ClockPhase]
    var mockRoundTypes: [MockRoundType]

    var available: Bool { active }
}

struct FeedCard: Codable, Identifiable, Hashable {
    var id: String
    var kind: CardKind
    var topic: CardTopic
    var title: String
    var body: String
    var recallPrompt: String
    var recallAnswer: String
    var tags: [String]
}

struct QuizItem: Codable, Identifiable, Hashable {
    var id: String
    var topic: CardTopic
    var type: QuizType
    var prompt: String
    var choices: [String]?
    var correctIndex: Int?
    var correctOrder: [String]?
    var explanation: String
}

enum QuizType: String, Codable, Hashable {
    case multipleChoice = "multiple_choice"
    case tradeoff
    case orderSteps = "order_steps"
    case estimateScale = "estimate_scale"
}

struct StoryTheme: Codable, Identifiable, Hashable {
    var id: String
    var theme: String
    var likelyQuestion: String
}

struct CourseWeek: Codable, Identifiable, Hashable {
    var id: String
    var week: Int
    var title: String
    var tasks: [CourseTask]
}

struct CourseTask: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var url: String?
}

struct RubricItem: Codable, Identifiable, Hashable {
    var id: String
    var label: String
    var description: String
}

struct ClockPhase: Codable, Identifiable, Hashable {
    var id: String
    var startMinute: Int
    var endMinute: Int
    var name: String
    var prompt: String
}

struct MockRoundType: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var defaultMinutes: Int
}

enum PackLoader {
    static func loadBundled() -> [RolePack] {
        let names = ["directors_cut", "senior_managers_cut", "managers_cut", "principals_cut"]
        return names.compactMap { load(named: $0) }
    }

    static func load(named name: String) -> RolePack? {
        let urls = [
            Bundle.main.url(forResource: name, withExtension: "json"),
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Packs"),
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Content/Packs"),
        ].compactMap { $0 }

        guard let url = urls.first else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(RolePack.self, from: data)
        } catch {
            print("Pack load error \(name): \(error)")
            return nil
        }
    }
}
