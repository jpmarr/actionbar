import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var pollInterval: Double
    @State private var activePollInterval: Double
    @State private var notificationsEnabled: Bool
    @State private var notifyOnSuccess: Bool
    @State private var notifyOnFailure: Bool

    init() {
        let settings = SettingsStorage()
        _pollInterval = State(initialValue: settings.pollInterval)
        _activePollInterval = State(initialValue: settings.activePollInterval)
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
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(HoverButtonStyle())
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
                        Text("Idle interval")
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
                    HStack {
                        Text("Active run interval")
                        Spacer()
                        Picker("", selection: $activePollInterval) {
                            Text("5s").tag(5.0)
                            Text("10s").tag(10.0)
                            Text("15s").tag(15.0)
                            Text("30s").tag(30.0)
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
        .onChange(of: pollInterval) { _, newValue in
            SettingsStorage().pollInterval = newValue
            Task { await appState.pollingService.setInterval(newValue) }
        }
        .onChange(of: activePollInterval) { _, newValue in
            SettingsStorage().activePollInterval = newValue
            Task { await appState.pollingService.setActiveInterval(newValue) }
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
