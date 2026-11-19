import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    var progress: UserProgress

    @State private var apiKey: String = KeychainStore.anthropicAPIKey ?? ""
    @State private var savedFlash = false

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Claude grading") {
                    SecureField("Anthropic API key", text: $apiKey)
                    HStack {
                        Text("Monthly spend")
                        Spacer()
                        Text(String(format: "$%.2f / $%.0f", progress.monthlySpendUSD, progress.monthlySpendCapUSD))
                            .foregroundStyle(CutTheme.mist)
                    }
                    Stepper(
                        "Spend cap $\(Int(progress.monthlySpendCapUSD))",
                        value: Binding(
                            get: { progress.monthlySpendCapUSD },
                            set: { progress.monthlySpendCapUSD = $0 }
                        ),
                        in: 5...200,
                        step: 5
                    )
                    Button(savedFlash ? "Saved" : "Save API key") {
                        KeychainStore.anthropicAPIKey = apiKey
                        withAnimation { savedFlash = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            savedFlash = false
                        }
                    }
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

                Section("Storage") {
                    Text("Phone only · SwiftData · offline packs")
                        .foregroundStyle(CutTheme.mist)
                    Text("Pomvox transcription runs on device. Audio is not uploaded.")
                        .font(CutTheme.caption)
                        .foregroundStyle(CutTheme.mist)
                }

                Section("About") {
                    LabeledContent("App", value: "The Cut")
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
        }
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
