import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    var progress: UserProgress

    @State private var apiKey: String = KeychainStore.anthropicAPIKey ?? ""
    @State private var savedFlash = false
    @State private var showKey = false

    private var hasKey: Bool {
        !(KeychainStore.anthropicAPIKey ?? "").isEmpty || !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Anthropic API key")
                        .font(.headline)
                        .foregroundStyle(CutTheme.paper)
                    Text("Paste your Claude key here (starts with sk-ant-). Not OpenAI. Stored in Keychain only.")
                        .font(CutTheme.caption)
                        .foregroundStyle(CutTheme.mist)

                    if showKey {
                        TextField("sk-ant-…", text: $apiKey, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(CutTheme.ink.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(CutTheme.paper)
                    } else {
                        SecureField("sk-ant-…", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(CutTheme.ink.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(CutTheme.paper)
                    }

                    HStack(spacing: 10) {
                        Button {
                            if let clip = UIPasteboard.general.string, !clip.isEmpty {
                                apiKey = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(CutSecondaryButtonStyle())

                        Button {
                            showKey.toggle()
                        } label: {
                            Label(showKey ? "Hide" : "Show", systemImage: showKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(CutSecondaryButtonStyle())
                    }

                    Button(savedFlash ? "Saved ✓" : "Save API key") {
                        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        KeychainStore.anthropicAPIKey = trimmed
                        apiKey = trimmed
                        withAnimation { savedFlash = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            savedFlash = false
                        }
                    }
                    .buttonStyle(CutPrimaryButtonStyle())

                    Text(hasKey ? "Key on device" : "No key saved yet")
                        .font(CutTheme.caption)
                        .foregroundStyle(hasKey ? CutTheme.success : CutTheme.ember)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Claude grading")
            }

            Section("Spend") {
                HStack {
                    Text("This month")
                    Spacer()
                    Text(String(format: "$%.2f / $%.0f", progress.monthlySpendUSD, progress.monthlySpendCapUSD))
                        .foregroundStyle(CutTheme.mist)
                }
                Stepper(
                    "Cap $\(Int(progress.monthlySpendCapUSD))",
                    value: Binding(
                        get: { progress.monthlySpendCapUSD },
                        set: { progress.monthlySpendCapUSD = $0 }
                    ),
                    in: 5...200,
                    step: 5
                )
            }

            Section("Role pack") {
                Picker("Pack", selection: Binding(
                    get: { appModel.selectedPackID },
                    set: { appModel.selectPack($0, progress: progress) }
                )) {
                    ForEach(appModel.packs) { pack in
                        Text(pack.active ? pack.name : "\(pack.name) (soon)")
                            .tag(pack.id)
                    }
                }
                Text(appModel.selectedPack.focus)
                    .font(CutTheme.caption)
                    .foregroundStyle(CutTheme.mist)
            }

            Section("Daily streak reminder") {
                Toggle("Enabled", isOn: Binding(
                    get: { progress.reminderEnabled },
                    set: { newValue in
                        progress.reminderEnabled = newValue
                        Task { await updateReminder() }
                    }
                ))
                DatePicker(
                    "Time",
                    selection: Binding(
                        get: {
                            Calendar.current.date(
                                bySettingHour: progress.reminderHour,
                                minute: progress.reminderMinute,
                                second: 0,
                                of: Date()
                            ) ?? Date()
                        },
                        set: { date in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                            progress.reminderHour = comps.hour ?? 8
                            progress.reminderMinute = comps.minute ?? 0
                            Task { await updateReminder() }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .disabled(!progress.reminderEnabled)
            }

            Section("About") {
                LabeledContent("App", value: "The Cut")
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1")
                Text("Phone-only storage. Pomvox stays on device.")
                    .font(CutTheme.caption)
                    .foregroundStyle(CutTheme.mist)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func updateReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["thecut.streak"])
        guard progress.reminderEnabled else { return }
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        guard granted == true else { return }

        var date = DateComponents()
        date.hour = progress.reminderHour
        date.minute = progress.reminderMinute
        let content = UNMutableNotificationContent()
        content.title = "The Cut"
        content.body = "Keep the streak. Ten cards and one quiz."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: "thecut.streak", content: content, trigger: trigger)
        try? await center.add(request)
    }
}
