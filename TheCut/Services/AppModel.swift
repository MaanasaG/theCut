import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppModel {
    var packs: [RolePack] = []
    var selectedPackID: String = "directors_cut"

    var selectedPack: RolePack {
        packs.first(where: { $0.id == selectedPackID })
            ?? packs.first(where: { $0.active })
            ?? RolePack(
                id: "directors_cut",
                name: "Director's Cut",
                focus: "",
                active: true,
                cards: [],
                quizzes: [],
                storyThemes: [],
                courseWeeks: [],
                systemDesignRubric: [],
                scenarioRubric: [],
                sdClockPhases: [],
                mockRoundTypes: []
            )
    }

    func loadPacks() {
        packs = PackLoader.loadBundled()
        if packs.isEmpty {
            print("Warning: no role packs loaded from bundle")
        }
        if !packs.contains(where: { $0.id == selectedPackID }) {
            selectedPackID = packs.first(where: \.active)?.id ?? selectedPackID
        }
    }

    func ensureProgress(context: ModelContext) -> UserProgress {
        let descriptor = FetchDescriptor<UserProgress>()
        if let existing = try? context.fetch(descriptor).first {
            selectedPackID = existing.selectedPackID
            existing.rollDayIfNeeded()
            return existing
        }
        let created = UserProgress()
        context.insert(created)
        try? context.save()
        return created
    }

    func selectPack(_ id: String, progress: UserProgress) {
        guard packs.contains(where: { $0.id == id && $0.active }) else { return }
        selectedPackID = id
        progress.selectedPackID = id
    }
}
