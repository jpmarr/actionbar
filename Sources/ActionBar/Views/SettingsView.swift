import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var pollInterval: Double
    @State private var notificationsEnabled: Bool
    @State private var notifyOnSuccess: Bool
    @State private var notifyOnFailure: Bool

    init() {
        let settings = SettingsStorage()
        _pollInterval = State(initialValue: settings.pollInterval)
        _notificationsEnabled = State(initialValue: settings.notificationsEnabled)
        _notifyOnSuccess = State(initialValue: settings.notifyOnSuccess)
        _notifyOnFailure = State(initialValue: settings.notifyOnFailure)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    appState.showingSettings = false
                } label: {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)

                Spacer()

                Text("Settings")
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Form {
                Section("Polling") {
                    HStack {
                        Text("Poll interval")
                        Spacer()
                        Picker("", selection: $pollInterval) {
                            Text("10s").tag(10.0)
                            Text("30s").tag(30.0)
                            Text("60s").tag(60.0)
                            Text("120s").tag(120.0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }
                }

                Section("Notifications") {
                    Toggle("Enable notifications", isOn: $notificationsEnabled)
                    if notificationsEnabled {
                        Toggle("Notify on success", isOn: $notifyOnSuccess)
                        Toggle("Notify on failure", isOn: $notifyOnFailure)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)

            Spacer()
        }
        .frame(minWidth: 480, maxWidth: 480, minHeight: 300)
        .onChange(of: pollInterval) { _, newValue in
            let settings = SettingsStorage()
            settings.pollInterval = newValue
            Task { await appState.pollingService.setInterval(newValue) }
        }
        .onChange(of: notificationsEnabled) { _, newValue in
            SettingsStorage().notificationsEnabled = newValue
        }
        .onChange(of: notifyOnSuccess) { _, newValue in
            SettingsStorage().notifyOnSuccess = newValue
        }
        .onChange(of: notifyOnFailure) { _, newValue in
            SettingsStorage().notifyOnFailure = newValue
        }
    }
}
