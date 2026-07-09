import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    enum TestState: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    @Published var providerBaseURL: String
    @Published var providerModel: String
    @Published var apiKeyInput: String = ""
    @Published var requestTimeoutSeconds: Int
    @Published var globalShortcutLabel: String
    @Published var rewriteBehavior: RewriteBehavior
    @Published private(set) var hasStoredAPIKey: Bool
    @Published private(set) var testState: TestState = .idle
    @Published private(set) var saveMessage: String?

    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let client: ProviderClient

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
        globalShortcutLabel = defaults.string(forKey: SettingsKey.globalShortcutLabel) ?? GlobalShortcutController.defaultShortcutLabel
        let behaviorValue = defaults.string(forKey: SettingsKey.rewriteBehavior) ?? RewriteBehavior.previewBeforeReplacing.rawValue
        rewriteBehavior = RewriteBehavior(rawValue: behaviorValue) ?? .previewBeforeReplacing
        hasStoredAPIKey = (try? keychain.read(account: ProviderConfig.apiKeyKeychainID))?.isEmpty == false
    }

    var apiKeyPlaceholder: String {
        hasStoredAPIKey ? "Stored in Keychain. Enter a new key to replace it." : "API key"
    }

    var canTestProvider: Bool {
        testState != .testing
    }

    func save() {
        defaults.set(providerBaseURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: SettingsKey.providerBaseURL)
        defaults.set(providerModel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: SettingsKey.providerModel)
        defaults.set(requestTimeoutSeconds, forKey: SettingsKey.requestTimeoutSeconds)
        defaults.set(globalShortcutLabel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: SettingsKey.globalShortcutLabel)
        defaults.set(rewriteBehavior.rawValue, forKey: SettingsKey.rewriteBehavior)

        let trimmedAPIKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAPIKey.isEmpty {
            do {
                try keychain.save(trimmedAPIKey, account: ProviderConfig.apiKeyKeychainID)
                apiKeyInput = ""
                hasStoredAPIKey = true
                saveMessage = "Settings saved. API key stored in Keychain."
            } catch {
                saveMessage = error.localizedDescription
            }
        } else {
            saveMessage = "Settings saved."
        }
    }

    func testProvider() async {
        save()
        testState = .testing

        do {
            let config = try currentProviderConfig()
            let apiKey = try currentAPIKey()
            try await client.testConnection(config: config, apiKey: apiKey)
            testState = .success
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

        throw SettingsValidationError(errors: ["API key is required."])
    }
}

enum SettingsKey {
    static let providerBaseURL = "providerBaseURL"
    static let providerModel = "providerModel"
    static let requestTimeoutSeconds = "requestTimeoutSeconds"
    static let globalShortcutLabel = "globalShortcutLabel"
    static let rewriteBehavior = "rewriteBehavior"
}

private struct SettingsValidationError: LocalizedError {
    let errors: [String]

    var errorDescription: String? {
        errors.joined(separator: "\n")
    }
}
