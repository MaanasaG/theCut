import SwiftUI

enum CutTheme {
    // Ink-and-ember: serious interview prep, not purple-glow AI chrome.
    static let ink = Color(red: 0.07, green: 0.09, blue: 0.12)
    static let slate = Color(red: 0.14, green: 0.17, blue: 0.22)
    static let mist = Color(red: 0.82, green: 0.85, blue: 0.88)
    static let paper = Color(red: 0.93, green: 0.91, blue: 0.86)
    static let ember = Color(red: 0.86, green: 0.38, blue: 0.22)
    static let gold = Color(red: 0.78, green: 0.62, blue: 0.28)
    static let success = Color(red: 0.35, green: 0.62, blue: 0.42)

    static let display = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let title = Font.system(.title2, design: .serif).weight(.semibold)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default).weight(.medium)

    static var atmosphere: some View {
        ZStack {
            LinearGradient(
                colors: [ink, slate, Color(red: 0.12, green: 0.14, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [ember.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 380
            )
            RadialGradient(
                colors: [gold.opacity(0.12), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

struct CutPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(CutTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(CutTheme.ember.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct CutSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(CutTheme.paper)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(CutTheme.slate.opacity(configuration.isPressed ? 0.7 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(CutTheme.mist.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
