import ApplicationServices
import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let windowPresenter = WindowPresenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "R"
        item.button?.toolTip = "Rewritr"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Privacy", action: #selector(showPrivacy), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check Permissions", action: #selector(showPermissions), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Rewritr", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        item.menu = menu
        statusItem = item
    }

    @objc private func showSettings() {
        windowPresenter.show(
            title: "Rewritr Settings",
            width: 520,
            height: 500,
            rootView: SettingsView()
        )
    }

    @objc private func showPrivacy() {
        windowPresenter.show(
            title: "Privacy",
            width: 520,
            height: 420,
            rootView: PrivacyView()
        )
    }

    @objc private func showPermissions() {
        windowPresenter.show(
            title: "Permissions",
            width: 520,
            height: 360,
            rootView: PermissionView()
        )
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@MainActor
final class WindowPresenter {
    private var windows: [String: NSWindow] = [:]
    private var delegates: [String: WindowDelegate] = [:]

    func show<Content: View>(title: String, width: CGFloat, height: CGFloat, rootView: Content) {
        if let window = windows[title] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.setContentSize(NSSize(width: width, height: height))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        let delegate = WindowDelegate { [weak self, weak window] in
            guard let window else { return }
            self?.windows.removeValue(forKey: window.title)
            self?.delegates.removeValue(forKey: window.title)
        }
        window.delegate = delegate

        windows[title] = window
        delegates[title] = delegate
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private final class WindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

struct SettingsView: View {
    @AppStorage("providerBaseURL") private var providerBaseURL = ""
    @AppStorage("providerModel") private var providerModel = ""
    @AppStorage("requestTimeoutSeconds") private var requestTimeoutSeconds = 20
    @AppStorage("globalShortcutLabel") private var globalShortcutLabel = "Control+Option+R"
    @AppStorage("rewriteBehavior") private var rewriteBehavior = RewriteBehavior.previewBeforeReplacing.rawValue

    @State private var apiKeyPlaceholder = ""

    var body: some View {
        Form {
            Section("Provider") {
                TextField("Base URL", text: $providerBaseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $providerModel)
                    .textFieldStyle(.roundedBorder)
                SecureField("API key", text: $apiKeyPlaceholder)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Stepper("Timeout: \(requestTimeoutSeconds) seconds", value: $requestTimeoutSeconds, in: 5...60, step: 5)
                    Spacer()
                    Button("Test") {}
                        .disabled(true)
                }
            }

            Section("Rewrite") {
                Picker("Behavior", selection: $rewriteBehavior) {
                    Text("Preview before replacing").tag(RewriteBehavior.previewBeforeReplacing.rawValue)
                    Text("Replace instantly").tag(RewriteBehavior.replaceInstantly.rawValue)
                }
                .pickerStyle(.radioGroup)

                Text("Preview before replacing is the default. Instant replacement is available for users who prefer a faster flow.")
                    .foregroundStyle(.secondary)
            }

            Section("Shortcut") {
                TextField("Global shortcut", text: $globalShortcutLabel)
                    .textFieldStyle(.roundedBorder)
                Text("Default: Control+Option+R")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(24)
    }
}

struct PrivacyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy")
                .font(.title2)
                .fontWeight(.semibold)

            PrivacyRow(title: "Provider request", detail: "Selected text is sent to the model provider you configure.")
            PrivacyRow(title: "No backend", detail: "Rewritr does not use a Rewritr server.")
            PrivacyRow(title: "No history", detail: "Rewritr does not store rewrite history in v1.")
            PrivacyRow(title: "API key", detail: "The API key will be stored locally in Keychain.")
            PrivacyRow(title: "Accessibility", detail: "Accessibility permission is needed for selected-text copy and paste automation.")
            PrivacyRow(title: "Compatibility", detail: "Some secure fields, terminal sessions, remote desktops, and custom editors may not support reliable replacement.")

            Spacer()
        }
        .padding(24)
    }
}

private struct PrivacyRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .fontWeight(.medium)
            Text(detail)
                .foregroundStyle(.secondary)
        }
    }
}

struct PermissionView: View {
    @State private var isTrusted = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.title2)
                .fontWeight(.semibold)

            HStack {
                Image(systemName: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isTrusted ? .green : .orange)
                Text(isTrusted ? "Accessibility permission is enabled." : "Accessibility permission is not enabled.")
            }

            Text("Rewritr needs Accessibility permission to copy selected text and paste rewritten text back into the active app.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Refresh Status") {
                    isTrusted = AXIsProcessTrusted()
                }

                Button("Open System Settings") {
                    openAccessibilitySettings()
                }
            }

            Spacer()
        }
        .padding(24)
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

enum RewriteBehavior: String {
    case previewBeforeReplacing
    case replaceInstantly
}
