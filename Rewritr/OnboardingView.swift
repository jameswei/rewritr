import SwiftUI

struct OnboardingView: View {
    let openSettings: () -> Void
    let openPermissions: () -> Void
    let finish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Rewritr")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text(ProductCopy.positioning)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                OnboardingRow(
                    title: "How it works",
                    detail: "Select English text, press \(GlobalShortcutController.defaultShortcutLabel), and choose whether to review the rewrite or replace it instantly."
                )
                OnboardingRow(
                    title: "Provider setup",
                    detail: "Bring an OpenAI-compatible Chat Completions provider. Your API key is stored locally in Keychain."
                )
                OnboardingRow(
                    title: "Privacy",
                    detail: "Selected text is sent only to the provider you configure. Rewritr has no backend, analytics, accounts, or rewrite history in v1."
                )
                OnboardingRow(
                    title: "Compatibility",
                    detail: ProductCopy.compatibilitySummary
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Known limits")
                    .font(.headline)
                ForEach(ProductCopy.compatibilityRestrictions, id: \.self) { restriction in
                    Text("- \(restriction)")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            HStack {
                Button("Settings", action: openSettings)
                Button("Permissions", action: openPermissions)
                Spacer()
                Button("Done", action: finish)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }
}

private struct OnboardingRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
