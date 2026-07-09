import Foundation

enum ProviderClientError: LocalizedError, Sendable {
    case invalidURL
    case invalidHTTPResponse
    case providerError(statusCode: Int, message: String)
    case emptyResponse
    case unexpectedTestResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Provider base URL is invalid."
        case .invalidHTTPResponse:
            "Provider returned an invalid response."
        case .providerError(let statusCode, let message):
            "Provider error \(statusCode): \(message)"
        case .emptyResponse:
            "Provider returned an empty response."
        case .unexpectedTestResponse(let value):
            "Provider responded, but returned \(value) instead of OK."
        }
    }
}

struct ProviderClient: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let transport: Transport

    init(transport: @escaping Transport = { request in
        try await URLSession.shared.data(for: request)
    }) {
        self.transport = transport
    }

    func testConnection(config: ProviderConfig, apiKey: String) async throws {
        let response = try await chatCompletion(
            config: config,
            apiKey: apiKey,
            messages: [
                ChatMessage(role: "system", content: "Return exactly OK and nothing else."),
                ChatMessage(role: "user", content: "OK")
            ],
            maxTokens: 4
        )

        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "OK" else {
            throw ProviderClientError.unexpectedTestResponse(trimmed)
        }
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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
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
