import Foundation

enum ProviderClientError: LocalizedError, Sendable {
    case invalidURL
    case invalidHTTPResponse
    case providerError(statusCode: Int, message: String)
    case emptyResponse
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Provider URL is invalid."
        case .invalidHTTPResponse:
            "Provider returned an invalid response."
        case .providerError(let statusCode, let message):
            Self.friendlyProviderError(statusCode: statusCode, message: message)
        case .emptyResponse:
            "Provider returned no text content."
        case .malformedResponse:
            "Provider returned a response Rewritr could not read."
        }
    }

    private static func friendlyProviderError(statusCode: Int, message: String) -> String {
        let guidance: String
        switch statusCode {
        case 400:
            guidance = "The provider rejected the request. Check the Provider URL, model name, and whether the endpoint supports OpenAI-compatible Chat Completions."
        case 401:
            guidance = "Authentication failed. Check your API key. If you use a local provider that does not need a key, leave the API key field blank."
        case 403:
            guidance = "Access was denied. Check whether your API key is allowed to use this model and endpoint."
        case 404:
            guidance = "The provider endpoint was not found. Check the full Provider URL and model name; different providers may use different Chat Completions paths."
        case 408:
            guidance = "The provider timed out. Check the Provider URL and try a higher timeout."
        case 429:
            guidance = "The provider rate limit was reached. Wait a moment, or check your provider quota."
        case 500..<600:
            guidance = "The provider returned a server error. Try again later, or check the provider status."
        default:
            guidance = "The provider rejected the request. Check the Provider URL, model name, and API key."
        }

        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            return "\(guidance) (HTTP \(statusCode))"
        }
        return "\(guidance) (HTTP \(statusCode): \(trimmedMessage))"
    }
}

enum ProviderConnectionTestResult: Equatable, Sendable {
    case textResponse
    case emptyTextResponse
}

struct ProviderClient: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let transport: Transport

    init(transport: @escaping Transport = { request in
        try await URLSession.shared.data(for: request)
    }) {
        self.transport = transport
    }

    func testConnection(config: ProviderConfig, apiKey: String) async throws -> ProviderConnectionTestResult {
        do {
            _ = try await chatCompletion(
                config: config,
                apiKey: apiKey,
                messages: [
                    ChatMessage(role: "system", content: "Reply with a very short confirmation."),
                    ChatMessage(role: "user", content: "Connection test.")
                ],
                maxTokens: 8
            )
        } catch ProviderClientError.emptyResponse {
            return .emptyTextResponse
        }

        return .textResponse
    }

    func chatCompletion(
        config: ProviderConfig,
        apiKey: String,
        messages: [ChatMessage],
        maxTokens: Int? = nil
    ) async throws -> String {
        guard let url = config.chatCompletionsURL else {
            throw ProviderClientError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: TimeInterval(config.timeoutSeconds))
        request.httpMethod = "POST"
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAPIKey.isEmpty {
            request.setValue("Bearer \(trimmedAPIKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionRequest(
                model: config.model,
                messages: messages,
                temperature: 0.2,
                maxTokens: maxTokens
            )
        )

        let (data, response) = try await transport(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderClientError.invalidHTTPResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = ProviderErrorResponse.message(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw ProviderClientError.providerError(statusCode: httpResponse.statusCode, message: message)
        }

        let decoded: ChatCompletionResponse
        do {
            decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw ProviderClientError.malformedResponse
        }
        guard let content = decoded.choices.first?.message.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderClientError.emptyResponse
        }

        return content
    }
}

struct ChatMessage: Codable, Equatable, Sendable {
    let role: String
    let content: String
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        let message: ChatMessage
    }

    let choices: [Choice]
}

private struct ProviderErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        let message: String?
    }

    let error: ErrorBody?

    static func message(from data: Data) -> String? {
        try? JSONDecoder().decode(Self.self, from: data).error?.message
    }
}
