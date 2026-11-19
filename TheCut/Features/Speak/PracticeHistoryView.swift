import SwiftData
import SwiftUI

struct PracticeHistoryView: View {
    @Query(sort: \PracticeSession.createdAt, order: .reverse) private var sessions: [PracticeSession]

    var body: some View {
        List(sessions) { session in
            VStack(alignment: .leading, spacing: 6) {
                Text(session.prompt)
                    .font(.headline)
                    .foregroundStyle(CutTheme.paper)
                Text(String(format: "%.1f · %@ · %@", session.scoreAverage, session.kind, session.topic))
                    .font(CutTheme.caption)
                    .foregroundStyle(CutTheme.ember)
                if let hire = session.hireSignal {
                    Text("Signal: \(hire)")
                        .font(CutTheme.caption)
                        .foregroundStyle(CutTheme.gold)
                }
                Text(session.feedback)
                    .font(.caption)
                    .foregroundStyle(CutTheme.mist)
                    .lineLimit(3)
            }
            .listRowBackground(CutTheme.slate.opacity(0.7))
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("History")
    }
}
