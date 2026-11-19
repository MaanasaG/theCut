import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel
    var progress: UserProgress
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 18) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: CutTheme.ember.opacity(0.35), radius: 16, y: 8)
                    .scaleEffect(appear ? 1 : 0.9)
                    .opacity(appear ? 1 : 0)

                Text("The Cut")
                    .font(CutTheme.display)
                    .foregroundStyle(CutTheme.paper)
                    .scaleEffect(appear ? 1 : 0.92)
                    .opacity(appear ? 1 : 0)

                Text("Director interview prep that trains judgment — not trivia.")
                    .font(CutTheme.body)
                    .foregroundStyle(CutTheme.mist)
                    .opacity(appear ? 1 : 0)

                Text("Pick your target role. The engine stays the same; the pack changes the feed, quizzes, and mocks.")
                    .font(CutTheme.caption)
                    .foregroundStyle(CutTheme.mist.opacity(0.8))
            }
            .padding(.horizontal, 28)

            VStack(spacing: 12) {
                ForEach(appModel.packs) { pack in
                    Button {
                        guard pack.active else { return }
                        appModel.selectPack(pack.id, progress: progress)
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            progress.hasCompletedOnboarding = true
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pack.name)
                                    .font(.headline)
                                    .foregroundStyle(CutTheme.paper)
                                Text(pack.focus)
                                    .font(.caption)
                                    .foregroundStyle(CutTheme.mist)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            if pack.active {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(CutTheme.ember)
                            } else {
                                Text("Soon")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(CutTheme.mist.opacity(0.5))
                            }
                        }
                        .padding(16)
                        .background(CutTheme.slate.opacity(pack.active ? 0.95 : 0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(pack.active ? CutTheme.ember.opacity(0.5) : .clear, lineWidth: 1)
                        )
                    }
                    .disabled(!pack.active)
                }
            }
            .padding(28)
            .padding(.top, 24)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appear = true }
        }
    }
}
