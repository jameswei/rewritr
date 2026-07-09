import Foundation

enum RewriteServiceError: LocalizedError, Sendable {
    case emptyInput
    case invalidSettings([String])
    case missingAPIKey
    case longRewriteRequiresConfirmation(wordCount: Int, threshold: Int)
    case emptyRewrite

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            "Select text before triggering rewrite."
        case .invalidSettings(let errors):
            errors.joined(separator: "\n")
        case .missingAPIKey:
            "API key is required."
        case .longRewriteRequiresConfirmation(let wordCount, let threshold):
            "This is a long rewrite (\(wordCount) words, warning starts at \(threshold)) and may take longer or cost more."
        case .emptyRewrite:
            "Provider returned an empty rewrite."
        }
    }
}

protocol RewriteSettingsProviding: Sendable {
    func providerConfig() throws -> ProviderConfig
    func apiKey() throws -> String
    func rewriteBehavior() -> RewriteBehavior
}

struct UserDefaultsRewriteSettingsProvider: RewriteSettingsProviding, @unchecked Sendable {
    private let defaults: UserDefaults
    private let keychain: KeychainStore

    init(defaults: UserDefaults = .standard, keychain: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain
    }

    func providerConfig() throws -> ProviderConfig {
        let config = ProviderConfig(
            baseURL: defaults.string(forKey: SettingsKey.providerBaseURL) ?? "",
            model: defaults.string(forKey: SettingsKey.providerModel) ?? "",
            apiKeyKeychainID: ProviderConfig.apiKeyKeychainID,
            timeoutSeconds: defaults.object(forKey: SettingsKey.requestTimeoutSeconds) as? Int ?? 20
        )
        let errors = config.validationErrors
        guard errors.isEmpty else {
            throw RewriteServiceError.invalidSettings(errors)
        }
        return config
    }

    func apiKey() throws -> String {
        guard let apiKey = try keychain.read(account: ProviderConfig.apiKeyKeychainID), !apiKey.isEmpty else {
            throw RewriteServiceError.missingAPIKey
        }
        return apiKey
    }

    func rewriteBehavior() -> RewriteBehavior {
        let value = defaults.string(forKey: SettingsKey.rewriteBehavior) ?? RewriteBehavior.previewBeforeReplacing.rawValue
        return RewriteBehavior(rawValue: value) ?? .previewBeforeReplacing
    }
}

struct RewritePromptBuilder: Sendable {
    func messages(for request: RewriteRequest) -> [ChatMessage] {
        [
            ChatMessage(role: "system", content: systemPrompt(for: request.mode)),
            ChatMessage(role: "user", content: userPrompt(inputText: request.inputText))
        ]
    }

    private func systemPrompt(for mode: RewriteMode) -> String {
        switch mode {
        case .refine:
            """
            You rewrite English written by non-native English speakers.

            Preserve the user's meaning exactly.
            Rewrite into natural, smooth, clear, native-like English.
            Preserve the user's intent, voice, and approximate tone.
            Keep it conversational and professional only when appropriate to the original context.
            Avoid slang.
            Avoid filler words.
            Avoid academic, thesis-style, overly formal phrasing unless the original context requires it.
            Avoid corporate jargon, marketing polish, and obvious AI-writing-assistant style.
            Do not add new facts, claims, emotion, confidence, or intent.
            Keep roughly the same length unless clarity requires a small adjustment.
            Return only the refined text, with no labels, markdown, quotes, or explanation.

            Examples:
            Input: I am agree with this idea.
            Output: I agree with this idea.
            Input: Can you help to check this when you have time?
            Output: Can you help check this when you have time?
            Input: This solution is more better for our case.
            Output: This solution is better for our case.
            """
        }
    }

    private func userPrompt(inputText: String) -> String {
        """
        Rewrite this selected text:

        \(inputText)
        """
    }
}

struct RewriteService: Sendable {
    private let settingsProvider: RewriteSettingsProviding
    private let client: ProviderClient
    private let promptBuilder: RewritePromptBuilder

    init(
        settingsProvider: RewriteSettingsProviding = UserDefaultsRewriteSettingsProvider(),
        client: ProviderClient = ProviderClient(),
        promptBuilder: RewritePromptBuilder = RewritePromptBuilder()
    ) {
        self.settingsProvider = settingsProvider
        self.client = client
        self.promptBuilder = promptBuilder
    }

    func rewriteBehavior() -> RewriteBehavior {
        settingsProvider.rewriteBehavior()
    }

    func rewrite(inputText: String, allowsLongRewrite: Bool = false) async throws -> RewriteResult {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw RewriteServiceError.emptyInput
        }

        let behavior = settingsProvider.rewriteBehavior()
        let wordCount = RewriteLengthPolicy.wordCount(in: trimmedInput)
        let threshold = RewriteLengthPolicy.warningThreshold(for: behavior)
        if RewriteLengthPolicy.requiresWarning(wordCount: wordCount, behavior: behavior), !allowsLongRewrite {
            throw RewriteServiceError.longRewriteRequiresConfirmation(wordCount: wordCount, threshold: threshold)
        }

        let request = RewriteRequest(
            inputText: trimmedInput,
            behavior: behavior,
            allowsLongRewrite: allowsLongRewrite
        )
        let refinedText = try await client.chatCompletion(
            config: try settingsProvider.providerConfig(),
            apiKey: try settingsProvider.apiKey(),
            messages: promptBuilder.messages(for: request)
        )
        let trimmedRewrite = refinedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRewrite.isEmpty else {
            throw RewriteServiceError.emptyRewrite
        }

        return RewriteResult(refinedText: trimmedRewrite)
    }
}
