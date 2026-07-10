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
    private static let defaultMenuBarSymbolName = "bubble.and.pencil"

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureRewriteActivityIndicator()
        configureGlobalShortcut()
        observeShortcutChanges()
        showOnboardingIfNeeded()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        setStatusItem(symbolName: Self.defaultMenuBarSymbolName, toolTip: "Rewritr")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "How to Use", action: #selector(showHowToUse), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Permissions", action: #selector(showPermissions), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Privacy", action: #selector(showPrivacy), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: ""))
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
            let controller = GlobalShortcutController(shortcut: ShortcutConfiguration.load()) { [weak self] in
                self?.rewriteCoordinator.triggerRewrite()
            }
            shortcutController = controller
            try controller.start()
        } catch {
            NSLog("Rewritr global shortcut registration failed: \(error.localizedDescription)")
        }
    }

    private func observeShortcutChanges() {
        NotificationCenter.default.addObserver(
            forName: .rewritrShortcutDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let shortcut = notification.userInfo?["shortcut"] as? ShortcutConfiguration
            else {
                return
            }

            Task { @MainActor in
                do {
                    try self.shortcutController?.update(to: shortcut)
                } catch {
                    let previous = self.shortcutController?.currentShortcut ?? .defaultShortcut
                    previous.save()
                    NotificationCenter.default.post(
                        name: .rewritrShortcutRegistrationFailed,
                        object: nil,
                        userInfo: [
                            "shortcut": previous,
                            "message": "Could not register \(shortcut.displayName). Rewritr kept \(previous.displayName)."
                        ]
                    )
                }
            }
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

    @objc private func showAbout() {
        windowPresenter.show(
            title: "About Rewritr",
            width: 340,
            height: 240,
            rootView: AboutView()
        )
    }

    @objc private func showHowToUse() {
        windowPresenter.show(
            title: "How to Use",
            width: 560,
            height: 560,
            rootView: HowToUseView()
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

struct AboutView: View {
    private let projectURL = URL(string: "https://github.com/jameswei/rewritr")
    private let siteURL = URL(string: "http://lifeplayer.space/rewritr/")

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: appIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .cornerRadius(16)

            VStack(spacing: 4) {
                Text("Rewritr")
                    .font(.title)
                    .fontWeight(.semibold)
                Text(versionText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            HStack(spacing: 14) {
                if let projectURL {
                    Link("GitHub", destination: projectURL)
                }
                if let siteURL {
                    Link("Project Site", destination: siteURL)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var appIconImage: NSImage {
        if let image = NSImage(named: "AboutIconWhite") {
            return image
        }

        if let image = NSImage(named: "AppIcon") {
            return image
        }

        if
            let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            let image = NSImage(contentsOf: url)
        {
            return image
        }

        return NSApp.applicationIconImage
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (.some(version), .some(build)):
            return "Version \(version) (\(build))"
        case let (.some(version), .none):
            return "Version \(version)"
        default:
            return "Local development build"
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Privacy")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Rewritr is designed to stay small, local, and transparent.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                PrivacyTile(
                    icon: "server.rack",
                    title: "No Rewritr backend",
                    detail: "Selected text goes only to your configured LLM provider, not to a Rewritr-hosted service."
                )
                PrivacyTile(
                    icon: "chart.bar.xaxis",
                    title: "No analytics",
                    detail: "Rewritr does not collect telemetry, product analytics, or third-party marketing data."
                )
                PrivacyTile(
                    icon: "key.fill",
                    title: "API key stays on this Mac",
                    detail: "If you provide an API key, it is stored locally in macOS Keychain after a successful provider test."
                )
                PrivacyTile(
                    icon: "accessibility",
                    title: "Accessibility is only for copy and paste",
                    detail: "Rewritr uses Accessibility permission to copy selected text and paste the rewrite back into the active app."
                )
            }

            Spacer(minLength: 0)
        }
        .padding(24)
    }
}

private struct PrivacyTile: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PermissionView: View {
    @State private var isTrusted = AXIsProcessTrusted()

    var body: some View {
        VStack(spacing: 16) {
            Text("Permissions")
                .font(.title2)
                .fontWeight(.semibold)

            Image(systemName: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(isTrusted ? .green : .orange)

            Text(isTrusted ? "Accessibility permission is enabled." : "Accessibility permission is required.")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                PermissionItem(
                    icon: "accessibility",
                    title: "Accessibility",
                    detail: "Allows Rewritr to copy the selected text and paste the rewrite back into the active app."
                )
                PermissionItem(
                    icon: "doc.on.clipboard",
                    title: "Pasteboard access",
                    detail: "Uses normal macOS copy and paste briefly during a rewrite. No separate permission is required."
                )
                PermissionItem(
                    icon: "key.fill",
                    title: "Keychain",
                    detail: "Stores your API key locally after Test Connection succeeds, if your provider needs one. No extra prompt is usually needed."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
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
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private struct PermissionItem: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct HowToUseView: View {
    @State private var showsKnownLimits = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to Use")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Rewritr works where selected text can be copied and replaced with normal macOS copy and paste.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HowToUseExample()

                VStack(alignment: .leading, spacing: 14) {
                    HowToUseStep(number: "1", title: "Select text", detail: "Highlight the English sentence or paragraph you want to rewrite.")
                    HowToUseStep(number: "2", title: "Trigger Rewritr", detail: "Press your shortcut. The default is \(GlobalShortcutController.defaultShortcutLabel).")
                    HowToUseStep(number: "3", title: "Apply the rewrite", detail: "Preview mode lets you Replace, Copy, or Retry. Instant mode replaces automatically and shows a small status HUD.")
                }

                Divider()

                Button {
                    showsKnownLimits.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: showsKnownLimits ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Known limits")
                            .font(.headline)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showsKnownLimits {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(ProductCopy.compatibilitySummary)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(ProductCopy.compatibilityRestrictions, id: \.self) { restriction in
                            Label(restriction, systemImage: "info.circle")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(24)
        }
    }
}

private struct HowToUseExample: View {
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Before", systemImage: "text.quote")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("I am agree with this idea.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            Image(systemName: "arrow.right")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 6) {
                Label("After", systemImage: "sparkles")
                    .font(.callout)
                    .foregroundStyle(.green)
                Text("I agree with this idea.")
                    .font(.body)
                    .fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct HowToUseStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.title3)
                .fontWeight(.semibold)
                .frame(width: 38, height: 38)
                .background(Color.blue.opacity(0.14), in: Circle())
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
