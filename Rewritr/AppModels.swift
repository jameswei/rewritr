import Foundation

enum RewriteBehavior: String, CaseIterable, Identifiable, Sendable {
    case previewBeforeReplacing
    case replaceInstantly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .previewBeforeReplacing:
            "Preview before replacing"
        case .replaceInstantly:
            "Replace instantly"
        }
    }
}

struct ProviderConfig: Equatable, Sendable {
    static let apiKeyKeychainID = "default-api-key"

    let baseURL: String
    let model: String
    let apiKeyKeychainID: String
    let timeoutSeconds: Int

    var chatCompletionsURL: URL? {
        Self.chatCompletionsURL(from: baseURL)
    }

    var validationErrors: [String] {
        var errors: [String] = []

        if baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Base URL is required.")
        } else if chatCompletionsURL == nil {
            errors.append("Base URL must be a valid URL.")
        }

        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Model is required.")
        }

        if apiKeyKeychainID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("API key reference is required.")
        }

        if timeoutSeconds < 5 || timeoutSeconds > 60 {
            errors.append("Timeout must be between 5 and 60 seconds.")
        }

        return errors
    }

    static func chatCompletionsURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else {
            return nil
        }

        guard components.scheme != nil, components.host != nil else {
            return nil
        }

        let existingPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if existingPath.hasSuffix("chat/completions") {
            return components.url
        }

        let prefix = existingPath.isEmpty ? "" : "/" + existingPath
        components.path = prefix + "/chat/completions"
        return components.url
    }
}

enum RewriteMode: String, Sendable {
    case refine
}

struct RewriteRequest: Equatable, Sendable {
    let inputText: String
    let mode: RewriteMode
    let behavior: RewriteBehavior
    let allowsLongRewrite: Bool

    init(
        inputText: String,
        mode: RewriteMode = .refine,
        behavior: RewriteBehavior,
        allowsLongRewrite: Bool = false
    ) {
        self.inputText = inputText
        self.mode = mode
        self.behavior = behavior
        self.allowsLongRewrite = allowsLongRewrite
    }
}

struct RewriteResult: Equatable, Sendable {
    let refinedText: String
}

enum RewriteLengthPolicy {
    static let previewWarningWordCount = 4_000
    static let instantWarningWordCount = 2_000

    static func wordCount(in text: String) -> Int {
        text
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    static func warningThreshold(for behavior: RewriteBehavior) -> Int {
        switch behavior {
        case .previewBeforeReplacing:
            previewWarningWordCount
        case .replaceInstantly:
            instantWarningWordCount
        }
    }

    static func requiresWarning(wordCount: Int, behavior: RewriteBehavior) -> Bool {
        wordCount >= warningThreshold(for: behavior)
    }
}
