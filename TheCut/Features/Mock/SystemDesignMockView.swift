import SwiftUI

struct SystemDesignMockView: View {
    @Environment(AppModel.self) private var appModel
    var progress: UserProgress

    @State private var elapsed = 0
    @State private var running = false
    @State private var ticker: Timer?
    @State private var prompt: FeedCard?
    @State private var nudgeFlash = false

    private var phases: [ClockPhase] {
        appModel.selectedPack.sdClockPhases
    }

    private var currentPhase: ClockPhase? {
        let minute = elapsed / 60
        return phases.first { minute >= $0.startMinute && minute < $0.endMinute }
            ?? phases.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("System design mock")
                .font(CutTheme.title)
                .foregroundStyle(CutTheme.paper)

            Text(prompt?.title ?? "Pick a prompt")
                .foregroundStyle(CutTheme.gold)
            Text(prompt?.body ?? "")
                .foregroundStyle(CutTheme.mist)

            Text(timeLabel)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(CutTheme.paper)

            if let phase = currentPhase {
                VStack(alignment: .leading, spacing: 6) {
                    Text(phase.name)
                        .font(.headline)
                        .foregroundStyle(nudgeFlash ? CutTheme.ember : CutTheme.paper)
                    Text(phase.prompt)
                        .foregroundStyle(CutTheme.mist)
                    Text("\(phase.startMinute)–\(phase.endMinute) min")
                        .font(CutTheme.caption)
                        .foregroundStyle(CutTheme.gold)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CutTheme.slate.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .scaleEffect(nudgeFlash ? 1.02 : 1)
            }

            HStack {
                Button(running ? "Pause" : "Start") { toggle() }
                    .buttonStyle(CutPrimaryButtonStyle())
                Button("Reset") { reset() }
                    .buttonStyle(CutSecondaryButtonStyle())
            }
            Button("New prompt") { draw() }
                .buttonStyle(CutSecondaryButtonStyle())

            Spacer()
        }
        .padding(24)
        .onAppear { draw() }
        .onDisappear { ticker?.invalidate() }
        .onChange(of: currentPhase?.id) { _, _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                nudgeFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { nudgeFlash = false }
            }
        }
    }

    private var timeLabel: String {
        let m = elapsed / 60
        let s = elapsed % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func draw() {
        prompt = appModel.selectedPack.cards
            .filter { $0.kind == .interviewQuestion && $0.topic == .systemDesign }
            .randomElement()
    }

    private func toggle() {
        if running {
            ticker?.invalidate()
            running = false
        } else {
            running = true
            ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in
                    if elapsed < 60 * 60 {
                        elapsed += 1
                    } else {
                        ticker?.invalidate()
                        running = false
                    }
                }
            }
        }
    }

    private func reset() {
        ticker?.invalidate()
        running = false
        elapsed = 0
    }
}
