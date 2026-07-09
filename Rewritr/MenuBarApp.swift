import ApplicationServices
import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let windowPresenter = WindowPresenter()
    private let rewriteCoordinator = RewriteCoordinator()
    private var shortcutController: GlobalShortcutController?
    private var statusResetTask: Task<Void, Never>?
    private static let defaultMenuBarSymbolName = "pencil.line"

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureRewriteActivityIndicator()
        configureGlobalShortcut()
        showOnboardingIfNeeded()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        setStatusItem(symbolName: Self.defaultMenuBarSymbolName, toolTip: "Rewritr")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Privacy", action: #selector(showPrivacy), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check Permissions", action: #selector(showPermissions), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Rewritr", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        item.menu = menu
    }

    private func configureRewriteActivityIndicator() {
        rewriteCoordinator.activityHandler = { [weak self] state in
            self?.updateStatusItem(for: state)
        }
    }

    private func updateStatusItem(for state: RewriteActivityState) {
        statusResetTask?.cancel()

        switch state {
        case .idle:
            setStatusItem(symbolName: Self.defaultMenuBarSymbolName, toolTip: "Rewritr")
        case .working(let message):
            setStatusItem(symbolName: "hourglass", toolTip: message)
        case .succeeded(let message):
            setStatusItem(symbolName: "checkmark.circle", toolTip: message)
            resetStatusItem(afterNanoseconds: 1_200_000_000)
        case .failed(let message):
            setStatusItem(symbolName: "exclamationmark.triangle", toolTip: message)
            resetStatusItem(afterNanoseconds: 2_000_000_000)
        }
    }

    private func setStatusItem(symbolName: String, toolTip: String) {
        guard let button = statusItem?.button else {
            return
        }

        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: toolTip)
            ?? NSImage(systemSymbolName: Self.defaultMenuBarSymbolName, accessibilityDescription: toolTip)
        image?.isTemplate = true
        button.title = ""
        button.image = image
        button.toolTip = toolTip
    }

    private func resetStatusItem(afterNanoseconds delay: UInt64) {
        statusResetTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            await MainActor.run {
                guard let self else { return }
                self.setStatusItem(symbolName: Self.defaultMenuBarSymbolName, toolTip: "Rewritr")
            }
        }
    }

    private func configureGlobalShortcut() {
        do {
            let controller = GlobalShortcutController { [weak self] in
                self?.rewriteCoordinator.triggerRewrite()
            }
            try controller.start()
            shortcutController = controller
        } catch {
            NSLog("Rewritr global shortcut registration failed: \(error.localizedDescription)")
        }
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

    private func showOnboardingIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: SettingsKey.hasCompletedOnboarding) else {
            return
        }

        windowPresenter.show(
            title: "Welcome to Rewritr",
            width: 660,
            height: 680,
            rootView: OnboardingView(
                openSettings: { [weak self] in self?.showSettings() },
                openPermissions: { [weak self] in self?.showPermissions() },
                finish: { [weak self] in
                    UserDefaults.standard.set(true, forKey: SettingsKey.hasCompletedOnboarding)
                    self?.windowPresenter.close(title: "Welcome to Rewritr")
                }
            )
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

    func close(title: String) {
        windows[title]?.close()
        windows.removeValue(forKey: title)
        delegates.removeValue(forKey: title)
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
            PrivacyRow(title: "Compatibility", detail: ProductCopy.compatibilitySummary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Known limits")
                    .fontWeight(.medium)
                ForEach(ProductCopy.compatibilityRestrictions, id: \.self) { restriction in
                    Text("- \(restriction)")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

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

            Text("macOS grants Accessibility permission to the exact app bundle path. This debug build is running from \(Bundle.main.bundlePath), so System Settings may show that temporary copy instead of a normal installed app.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Refresh Status") {
                    isTrusted = AXIsProcessTrusted()
                }

                Button("Request Permission") {
                    requestAccessibilityPermission()
                }

                Button("Open System Settings") {
                    openAccessibilitySettings()
                }
            }

            Spacer()
        }
        .padding(24)
    }

    private func requestAccessibilityPermission() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
