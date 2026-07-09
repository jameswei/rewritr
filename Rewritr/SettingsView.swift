import SwiftUI

struct SettingsView: View {
    @StateObject private var store = SettingsStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsSection(title: "Provider") {
                    LabeledField(label: "Base URL") {
                        TextField("https://api.example.com/v1", text: $store.providerBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledField(label: "Model") {
                        TextField("Model name", text: $store.providerModel)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledField(label: "API key") {
                        SecureField(store.apiKeyPlaceholder, text: $store.apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                        if store.hasStoredAPIKey {
                            Text("Stored API key: ********")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
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

                        Button("Test Connection") {
                            Task {
                                await store.testProvider()
                            }
                        }
                        .disabled(!store.canTestProvider)

                        Spacer()
                    }

                    statusView
                }

                SettingsSection(title: "Rewrite") {
                    Picker("Behavior", selection: $store.rewriteBehavior) {
                        ForEach(RewriteBehavior.allCases) { behavior in
                            Text(behavior.displayName).tag(behavior)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: store.rewriteBehavior) { _, _ in
                        store.saveRewriteBehavior()
                    }

                    Text("Preview before replacing is the default. Instant replacement is available for users who prefer a faster flow.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Behavior changes save automatically.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SettingsSection(title: "Shortcut") {
                    LabeledField(label: "Global shortcut") {
                        TextField(GlobalShortcutController.defaultShortcutLabel, text: $store.globalShortcutLabel)
                            .textFieldStyle(.roundedBorder)
                    }
                    Text("Default: \(GlobalShortcutController.defaultShortcutLabel)")
                        .foregroundStyle(.secondary)
                }

                SettingsSection(title: "Compatibility") {
                    Text(ProductCopy.compatibilitySummary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(ProductCopy.compatibilityRestrictions, id: \.self) { restriction in
                        Text("- \(restriction)")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(24)
        }
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
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .fixedSize(horizontal: false, vertical: true)
        case .warning(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
    }
}

private struct LabeledField<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.callout)
                .fontWeight(.medium)
            content
        }
    }
}
