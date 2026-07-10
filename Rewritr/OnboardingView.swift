import ApplicationServices
import SwiftUI

struct OnboardingView: View {
    let openSettings: () -> Void
    let openPermissions: () -> Void
    let finish: () -> Void

    @State private var step: OnboardingStep = .welcome

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases) { item in
                    Circle()
                        .fill(item.rawValue <= step.rawValue ? Color.blue : Color.secondary.opacity(0.25))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)

            Group {
                switch step {
                case .welcome:
                    WelcomeStep()
                case .privacy:
                    PrivacyStep()
                case .provider:
                    ProviderStep()
                case .permissions:
                    PermissionStep(openPermissions: openPermissions)
                case .demo:
                    DemoStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)

            Divider()

            HStack {
                Button("Settings", action: openSettings)
                Spacer()
                Button("Back") {
                    step = step.previous
                }
                .disabled(step == .welcome)

                Button(step == .demo ? "Finish" : "Continue") {
                    if step == .demo {
                        finish()
                    } else {
                        step = step.next
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
    }
}

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case privacy
    case provider
    case permissions
    case demo

    var id: Int { rawValue }

    var next: OnboardingStep {
        OnboardingStep(rawValue: rawValue + 1) ?? self
    }

    var previous: OnboardingStep {
        OnboardingStep(rawValue: rawValue - 1) ?? self
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Rewritr")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text(ProductCopy.positioning)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            OnboardingPanel(icon: "text.quote", title: "Rewrite selected English", detail: "You choose the exact text. Rewritr rewrites only that selection.")
            OnboardingPanel(icon: "sparkles", title: "Natural, not academic", detail: "The default style is smooth and native-like without thesis-style or overly formal phrasing.")
            OnboardingPanel(icon: "keyboard", title: "Shortcut first", detail: "Use \(GlobalShortcutController.defaultShortcutLabel) by default, or customize it in Settings.")
        }
    }
}

private struct PrivacyStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Privacy first")
                .font(.title)
                .fontWeight(.semibold)
            Text("Rewritr has no backend service. It does not create accounts, collect analytics, or store rewrite history.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            OnboardingPanel(icon: "paperplane", title: "Provider request", detail: "Selected text is sent only to the OpenAI-compatible provider you configure.")
            OnboardingPanel(icon: "key.fill", title: "Keychain storage", detail: "If you provide an API key, it is stored locally in macOS Keychain after the provider test succeeds.")
            OnboardingPanel(icon: "clipboard", title: "Clipboard automation", detail: "Rewritr temporarily uses the pasteboard to copy and replace selected text, then restores it where safe.")
        }
    }
}

private struct ProviderStep: View {
    @StateObject private var store = SettingsStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect your provider")
                .font(.title)
                .fontWeight(.semibold)
            Text("Use any OpenAI-compatible Chat Completions provider. Fast, inexpensive models are usually enough for rewriting. API keys are optional for local providers.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField(
                "Provider URL, for example https://api.example.com/v1/chat/completions",
                text: Binding(get: { store.providerBaseURL }, set: { store.updateProviderBaseURL($0) })
            )
            .textFieldStyle(.roundedBorder)

            TextField(
                "Model name",
                text: Binding(get: { store.providerModel }, set: { store.updateProviderModel($0) })
            )
            .textFieldStyle(.roundedBorder)

            SecureField(store.apiKeyPlaceholder, text: $store.apiKeyInput)
                .textFieldStyle(.roundedBorder)

            Button("Test Connection") {
                Task {
                    await store.testProvider()
                }
            }
            .disabled(!store.canTestProvider)

            ProviderStatusView(testState: store.testState)
        }
    }
}

private struct PermissionStep: View {
    let openPermissions: () -> Void
    @State private var isTrusted = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Enable Accessibility")
                .font(.title)
                .fontWeight(.semibold)
            Text("Rewritr needs Accessibility permission to copy selected text and paste rewritten text back into the app you are using.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label(
                isTrusted ? "Accessibility permission is enabled." : "Accessibility permission is not enabled yet.",
                systemImage: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.headline)
            .foregroundStyle(isTrusted ? .green : .orange)

            HStack {
                Button("Refresh Status") {
                    isTrusted = AXIsProcessTrusted()
                }
                Button("Open Permission Settings", action: openPermissions)
            }
        }
    }
}

private struct DemoStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("How rewriting works")
                .font(.title)
                .fontWeight(.semibold)

            HStack(alignment: .top, spacing: 14) {
                DemoCard(title: "1. Select", text: "I am agree with this idea.")
                Image(systemName: "arrow.right")
                    .padding(.top, 44)
                    .foregroundStyle(.secondary)
                DemoCard(title: "2. Rewrite", text: "I agree with this idea.")
                Image(systemName: "arrow.right")
                    .padding(.top, 44)
                    .foregroundStyle(.secondary)
                DemoCard(title: "3. Replace", text: "Keep writing in the original app.")
            }

            Text("Preview mode lets you review the rewrite before replacing. Instant mode replaces in place and shows a small status HUD without taking focus.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingPanel: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DemoCard: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(14)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ProviderStatusView: View {
    let testState: SettingsStore.TestState

    var body: some View {
        switch testState {
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
