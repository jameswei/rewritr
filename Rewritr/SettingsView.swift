import SwiftUI
import AppKit
import Carbon.HIToolbox

struct SettingsView: View {
    @StateObject private var store = SettingsStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSection(title: "Provider") {
                LabeledField(label: "Provider URL") {
                    TextField(
                        "https://api.example.com/v1/chat/completions",
                        text: Binding(
                            get: { store.providerBaseURL },
                            set: { store.updateProviderBaseURL($0) }
                        )
                    )
                        .textFieldStyle(.roundedBorder)
                    HelpText("Enter the full Chat Completions endpoint for your provider. Rewritr sends requests to this exact URL.")
                }
                LabeledField(label: "Model") {
                    TextField(
                        "Model name",
                        text: Binding(
                            get: { store.providerModel },
                            set: { store.updateProviderModel($0) }
                        )
                    )
                        .textFieldStyle(.roundedBorder)
                    HelpText("A fast, inexpensive chat model is usually enough for natural English rewriting.")
                }
                LabeledField(label: "API key") {
                    SecureField(store.apiKeyPlaceholder, text: $store.apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                    HelpText("Cloud providers usually require a key. Local OpenAI-compatible servers may not. A new key is stored locally in macOS Keychain only after Test Connection succeeds.")
                    if store.hasStoredAPIKey {
                        HStack {
                            Text("Stored API key: ********")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Button {
                                store.clearStoredAPIKey()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove stored API key")
                        }
                    }
                }
                Stepper(
                    "Timeout: \(store.requestTimeoutSeconds) seconds",
                    value: Binding(
                        get: { store.requestTimeoutSeconds },
                        set: { store.updateRequestTimeoutSeconds($0) }
                    ),
                    in: 5...60,
                    step: 5
                )

                HStack {
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
            SettingsDivider()

            SettingsSection(title: "Rewrite") {
                Picker("Behavior", selection: $store.rewriteBehavior) {
                    ForEach(RewriteBehavior.allCases) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: store.rewriteBehavior) { _, _ in
                    store.updateRewriteBehavior(store.rewriteBehavior)
                }

                if store.rewriteBehavior == .replaceInstantly {
                    Picker("HUD appearance", selection: $store.rewriteStatusHUDStyle) {
                        ForEach(RewriteStatusHUDStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.rewriteStatusHUDStyle) { _, _ in
                        store.updateRewriteStatusHUDStyle(store.rewriteStatusHUDStyle)
                    }
                }

                Text("Preview before replacing is the default. Instant replacement is available for users who prefer a faster flow.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Behavior changes save automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            SettingsDivider()

            SettingsSection(title: "Shortcut") {
                LabeledField(label: "Global shortcut") {
                    ShortcutRecorder(shortcut: store.shortcut) { shortcut in
                        store.updateShortcut(shortcut)
                    }
                }
                HelpText("Default: \(GlobalShortcutController.defaultShortcutLabel). Click the recorder, then press a key combination. Use at least one modifier key.")
                if let shortcutMessage = store.shortcutMessage {
                    Text(shortcutMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

private struct HelpText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
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
        .padding(.top, 14)
        .padding(.bottom, 16)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.secondary.opacity(0.18))
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: ShortcutConfiguration
    let onChange: (ShortcutConfiguration) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderField {
        let field = ShortcutRecorderField()
        field.onChange = onChange
        field.stringValue = shortcut.displayName
        return field
    }

    func updateNSView(_ nsView: ShortcutRecorderField, context: Context) {
        nsView.onChange = onChange
        if !nsView.isRecording {
            nsView.stringValue = shortcut.displayName
        }
    }
}

private final class ShortcutRecorderField: NSTextField {
    var onChange: ((ShortcutConfiguration) -> Void)?
    var isRecording = false

    init() {
        super.init(frame: .zero)
        isEditable = false
        isSelectable = false
        isBezeled = true
        drawsBackground = true
        bezelStyle = .roundedBezel
        focusRingType = .default
        lineBreakMode = .byTruncatingMiddle
        font = .systemFont(ofSize: NSFont.systemFontSize)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        stringValue = "Press shortcut..."
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            window?.makeFirstResponder(nil)
            return
        }

        guard let shortcut = ShortcutConfiguration.fromEvent(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags
        ) else {
            NSSound.beep()
            stringValue = "Use a modifier key"
            return
        }

        onChange?(shortcut)
        stringValue = shortcut.displayName
        window?.makeFirstResponder(nil)
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
