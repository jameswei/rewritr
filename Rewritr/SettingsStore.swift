import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    enum TestState: Equatable {
        case idle
        case testing
        case success(String)
        case warning(String)
        case failure(String)
    }

    @Published var providerBaseURL: String
    @Published var providerModel: String
    @Published var apiKeyInput: String = ""
    @Published var requestTimeoutSeconds: Int
    @Published var rewriteBehavior: RewriteBehavior
    @Published var rewriteStatusHUDStyle: RewriteStatusHUDStyle
    @Published var shortcut: ShortcutConfiguration
    @Published private(set) var hasStoredAPIKey: Bool
    @Published private(set) var testState: TestState = .idle
    @Published private(set) var saveMessage: String?
    @Published private(set) var shortcutMessage: String?

    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let client: ProviderClient
    private var isReadyForAutosave = false

    init(
        defaults: UserDefaults = .standard,
        keychain: KeychainStore = KeychainStore(),
        client: ProviderClient = ProviderClient()
    ) {
        self.defaults = defaults
        self.keychain = keychain
        self.client = client

        providerBaseURL = defaults.string(forKey: SettingsKey.providerBaseURL) ?? ""
        providerModel = defaults.string(forKey: SettingsKey.providerModel) ?? ""
        requestTimeoutSeconds = defaults.object(forKey: SettingsKey.requestTimeoutSeconds) as? Int ?? 20
        let behaviorValue = defaults.string(forKey: SettingsKey.rewriteBehavior) ?? RewriteBehavior.previewBeforeReplacing.rawValue
        rewriteBehavior = RewriteBehavior(rawValue: behaviorValue) ?? .previewBeforeReplacing
        rewriteStatusHUDStyle = RewriteStatusHUDStyle.load(from: defaults)
        shortcut = ShortcutConfiguration.load(from: defaults)
        hasStoredAPIKey = (try? keychain.read(account: ProviderConfig.apiKeyKeychainID))?.isEmpty == false
        isReadyForAutosave = true

        NotificationCenter.default.addObserver(
            forName: .rewritrShortcutRegistrationFailed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let shortcut = notification.userInfo?["shortcut"] as? ShortcutConfiguration
            let message = notification.userInfo?["message"] as? String
            Task { @MainActor in
                if let shortcut {
                    self.shortcut = shortcut
                }
                self.shortcutMessage = message ?? "Could not register that shortcut. Rewritr kept the previous shortcut."
            }
        }
    }

    var apiKeyPlaceholder: String {
        hasStoredAPIKey ? "Enter a new API key to replace the stored key" : "API key, optional for local providers"
    }

    var canTestProvider: Bool {
        testState != .testing
    }

    func updateProviderBaseURL(_ value: String) {
        providerBaseURL = value
        autosaveNormalSettings()
    }

    func updateProviderModel(_ value: String) {
        providerModel = value
        autosaveNormalSettings()
    }

    func updateRequestTimeoutSeconds(_ value: Int) {
        requestTimeoutSeconds = value
        autosaveNormalSettings()
    }

    func updateRewriteBehavior(_ value: RewriteBehavior) {
        rewriteBehavior = value
        autosaveNormalSettings()
    }

    func updateRewriteStatusHUDStyle(_ value: RewriteStatusHUDStyle) {
        rewriteStatusHUDStyle = value
        autosaveNormalSettings()
    }

    func updateShortcut(_ value: ShortcutConfiguration) {
        shortcut = value
        shortcut.save(to: defaults)
        shortcutMessage = "Shortcut saved: \(value.displayName)"
        NotificationCenter.default.post(
            name: .rewritrShortcutDidChange,
            object: nil,
            userInfo: ["shortcut": value]
        )
    }

    func autosaveNormalSettings() {
        guard isReadyForAutosave else {
            return
        }

        defaults.set(providerBaseURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: SettingsKey.providerBaseURL)
        defaults.set(providerModel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: SettingsKey.providerModel)
        defaults.set(requestTimeoutSeconds, forKey: SettingsKey.requestTimeoutSeconds)
        defaults.set(rewriteBehavior.rawValue, forKey: SettingsKey.rewriteBehavior)
        rewriteStatusHUDStyle.save(to: defaults)
        saveMessage = "Settings saved automatically."
    }

    private func storeTypedAPIKeyIfNeeded() throws {
        let trimmedAPIKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAPIKey.isEmpty {
            try keychain.save(trimmedAPIKey, account: ProviderConfig.apiKeyKeychainID)
            apiKeyInput = ""
            hasStoredAPIKey = true
        }
    }

    func saveRewriteBehavior() {
        autosaveNormalSettings()
    }

    func testProvider() async {
        testState = .testing

        do {
            let config = try currentProviderConfig()
            let apiKey = try currentAPIKey()
            let usesAPIKey = !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let result = try await client.testConnection(config: config, apiKey: apiKey)
            switch result {
            case .textResponse:
                try storeTypedAPIKeyIfNeeded()
                testState = .success(usesAPIKey ? "Connected. Provider URL, model, and API key are working." : "Connected. Provider URL and model are working without an API key.")
                saveMessage = hasStoredAPIKey ? "API key stored securely in macOS Keychain." : "Provider settings verified."
            case .emptyTextResponse:
                try storeTypedAPIKeyIfNeeded()
                testState = .success("Connected. The provider accepted the test request.")
                saveMessage = hasStoredAPIKey ? "API key stored securely in macOS Keychain." : "Provider settings verified."
            }
        } catch {
            testState = .failure(error.localizedDescription)
        }
    }

    func clearStoredAPIKey() {
        do {
            try keychain.delete(account: ProviderConfig.apiKeyKeychainID)
            hasStoredAPIKey = false
            saveMessage = "Stored API key removed."
        } catch {
            testState = .failure(error.localizedDescription)
        }
    }

    private func currentProviderConfig() throws -> ProviderConfig {
        let config = ProviderConfig(
            baseURL: providerBaseURL,
            model: providerModel,
            apiKeyKeychainID: ProviderConfig.apiKeyKeychainID,
            timeoutSeconds: requestTimeoutSeconds
        )

        let errors = config.validationErrors
        if !errors.isEmpty {
            throw SettingsValidationError(errors: errors)
        }

        return config
    }

    private func currentAPIKey() throws -> String {
        let typedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typedKey.isEmpty {
            return typedKey
        }

        if let storedKey = try keychain.read(account: ProviderConfig.apiKeyKeychainID), !storedKey.isEmpty {
            return storedKey
        }

        return ""
    }
}

enum SettingsKey {
    static let providerBaseURL = "providerBaseURL"
    static let providerModel = "providerModel"
    static let requestTimeoutSeconds = "requestTimeoutSeconds"
    static let globalShortcutLabel = "globalShortcutLabel"
    static let shortcutKeyCode = "shortcutKeyCode"
    static let shortcutModifiers = "shortcutModifiers"
    static let rewriteBehavior = "rewriteBehavior"
    static let rewriteStatusHUDStyle = "rewriteStatusHUDStyle"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}

private struct SettingsValidationError: LocalizedError {
    let errors: [String]

    var errorDescription: String? {
        errors.joined(separator: "\n")
    }
}
