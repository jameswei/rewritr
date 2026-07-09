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
