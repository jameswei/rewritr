import SwiftUI

struct SettingsView: View {
    @StateObject private var store = SettingsStore()

    var body: some View {
        Form {
            Section("Provider") {
                TextField("Base URL", text: $store.providerBaseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $store.providerModel)
                    .textFieldStyle(.roundedBorder)
                SecureField(store.apiKeyPlaceholder, text: $store.apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                Stepper(
                    "Timeout: \(store.requestTimeoutSeconds) seconds",
                    value: $store.requestTimeoutSeconds,
                    in: 5...60,
                    step: 5
                )

                HStack {
                    Button("Save") {
                        store.save()
                    }

                    Button("Test") {
                        Task {
                            await store.testProvider()
                        }
                    }
                    .disabled(!store.canTestProvider)

                    Spacer()
                }

                statusView
            }

            Section("Rewrite") {
                Picker("Behavior", selection: $store.rewriteBehavior) {
                    ForEach(RewriteBehavior.allCases) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("Preview before replacing is the default. Instant replacement is available for users who prefer a faster flow.")
                    .foregroundStyle(.secondary)
            }

            Section("Shortcut") {
                TextField("Global shortcut", text: $store.globalShortcutLabel)
                    .textFieldStyle(.roundedBorder)
                Text("Default: \(GlobalShortcutController.defaultShortcutLabel)")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(24)
    }

    @ViewBuilder
    private var statusView: some View {
        if let saveMessage = store.saveMessage {
            Text(saveMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
        }

        switch store.testState {
        case .idle:
            EmptyView()
        case .testing:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Testing provider...")
                    .foregroundStyle(.secondary)
            }
        case .success:
            Label("Provider test succeeded.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}
