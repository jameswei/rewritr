import AppKit
import XCTest
@testable import Rewritr

final class RewritrTests: XCTestCase {
    func testScaffoldLoads() {
        XCTAssertTrue(true)
    }

    func testChatCompletionsURLAppendsEndpoint() {
        XCTAssertEqual(
            ProviderConfig.chatCompletionsURL(from: "https://api.openai.com/v1")?.absoluteString,
            "https://api.openai.com/v1/chat/completions"
        )
    }

    func testChatCompletionsURLAcceptsExistingEndpoint() {
        XCTAssertEqual(
            ProviderConfig.chatCompletionsURL(from: "https://example.com/v1/chat/completions")?.absoluteString,
            "https://example.com/v1/chat/completions"
        )
    }

    func testProviderConfigValidationRequiresFields() {
        let config = ProviderConfig(
            baseURL: "",
            model: "",
            apiKeyKeychainID: "",
            timeoutSeconds: 2
        )

        XCTAssertEqual(config.validationErrors.count, 4)
    }

    func testProviderClientParsesSuccessfulResponse() async throws {
        let client = ProviderClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")

            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "test-model")
            XCTAssertEqual(json["temperature"] as? Double, 0.2)

            let data = Data("""
            {
              "choices": [
                {
                  "message": {
                    "role": "assistant",
                    "content": "OK"
                  }
                }
              ]
            }
            """.utf8)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (data, response)
        }

        let result = try await client.chatCompletion(
            config: testConfig(),
            apiKey: "test-key",
            messages: [ChatMessage(role: "user", content: "Hello")]
        )

        XCTAssertEqual(result, "OK")
    }

    func testProviderClientSurfacesProviderError() async throws {
        let client = ProviderClient { request in
            let data = Data("""
            {
              "error": {
                "message": "Invalid API key"
              }
            }
            """.utf8)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            ))
            return (data, response)
        }

        do {
            _ = try await client.chatCompletion(
                config: testConfig(),
                apiKey: "bad-key",
                messages: [ChatMessage(role: "user", content: "Hello")]
            )
            XCTFail("Expected provider error.")
        } catch let error as ProviderClientError {
            XCTAssertEqual(error.localizedDescription, "Provider error 401: Invalid API key")
        }
    }

    func testProviderTestRequiresExactOK() async throws {
        let client = ProviderClient { request in
            let data = Data("""
            {
              "choices": [
                {
                  "message": {
                    "role": "assistant",
                    "content": "Not OK"
                  }
                }
              ]
            }
            """.utf8)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (data, response)
        }

        do {
            try await client.testConnection(config: testConfig(), apiKey: "test-key")
            XCTFail("Expected unexpected test response error.")
        } catch let error as ProviderClientError {
            XCTAssertEqual(error.localizedDescription, "Provider responded, but returned Not OK instead of OK.")
        }
    }

    func testProviderClientSurfacesMalformedResponse() async throws {
        let client = ProviderClient { request in
            let data = Data("""
            {
              "unexpected": true
            }
            """.utf8)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (data, response)
        }

        do {
            _ = try await client.chatCompletion(
                config: testConfig(),
                apiKey: "test-key",
                messages: [ChatMessage(role: "user", content: "Hello")]
            )
            XCTFail("Expected malformed response error.")
        } catch let error as ProviderClientError {
            XCTAssertEqual(error.localizedDescription, "Provider returned a response Rewritr could not read.")
        }
    }

    func testRewritePromptBuilderUsesNaturalEnglishContract() throws {
        let messages = RewritePromptBuilder().messages(
            for: RewriteRequest(inputText: "I am agree with this idea.", behavior: .previewBeforeReplacing)
        )

        XCTAssertEqual(messages.count, 2)
        let systemPrompt = try XCTUnwrap(messages.first?.content)
        XCTAssertTrue(systemPrompt.contains("natural, smooth, clear, native-like English"))
        XCTAssertTrue(systemPrompt.contains("Avoid academic, thesis-style"))
        XCTAssertTrue(systemPrompt.contains("Return only the refined text"))
        XCTAssertTrue(try XCTUnwrap(messages.last?.content).contains("I am agree with this idea."))
    }

    func testRewriteLengthPolicyUsesBehaviorThresholds() {
        XCTAssertEqual(RewriteLengthPolicy.wordCount(in: "one two\nthree"), 3)
        XCTAssertFalse(RewriteLengthPolicy.requiresWarning(wordCount: 3_999, behavior: .previewBeforeReplacing))
        XCTAssertTrue(RewriteLengthPolicy.requiresWarning(wordCount: 4_000, behavior: .previewBeforeReplacing))
        XCTAssertFalse(RewriteLengthPolicy.requiresWarning(wordCount: 1_999, behavior: .replaceInstantly))
        XCTAssertTrue(RewriteLengthPolicy.requiresWarning(wordCount: 2_000, behavior: .replaceInstantly))
    }

    func testRewriteServiceCallsProviderAndTrimsResult() async throws {
        let settings = StaticRewriteSettingsProvider(
            config: testConfig(),
            apiKey: "test-key",
            behavior: .previewBeforeReplacing
        )
        let client = ProviderClient { request in
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "test-model")

            let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
            XCTAssertTrue(try XCTUnwrap(messages.first?["content"]).contains("native-like English"))
            XCTAssertTrue(try XCTUnwrap(messages.last?["content"]).contains("I am agree."))

            let data = Data("""
            {
              "choices": [
                {
                  "message": {
                    "role": "assistant",
                    "content": " I agree.\\n"
                  }
                }
              ]
            }
            """.utf8)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (data, response)
        }
        let service = RewriteService(settingsProvider: settings, client: client)

        let result = try await service.rewrite(inputText: " I am agree. ")

        XCTAssertEqual(result.refinedText, "I agree.")
    }

    func testRewriteServiceRequiresConfirmationForLongInstantRewrite() async throws {
        let settings = StaticRewriteSettingsProvider(
            config: testConfig(),
            apiKey: "test-key",
            behavior: .replaceInstantly
        )
        let service = RewriteService(settingsProvider: settings)
        let input = Array(repeating: "word", count: 2_000).joined(separator: " ")

        do {
            _ = try await service.rewrite(inputText: input)
            XCTFail("Expected long rewrite warning.")
        } catch let error as RewriteServiceError {
            XCTAssertEqual(error.localizedDescription, "This is a long rewrite (2000 words, warning starts at 2000) and may take longer or cost more.")
        }
    }

    func testPasteboardSnapshotRestoresPreviousString() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("RewritrTests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("original clipboard", forType: .string)

        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("temporary rewrite text", forType: .string)

        snapshot.restore(to: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), "original clipboard")
    }

    private func testConfig() -> ProviderConfig {
        ProviderConfig(
            baseURL: "https://api.example.com/v1",
            model: "test-model",
            apiKeyKeychainID: ProviderConfig.apiKeyKeychainID,
            timeoutSeconds: 20
        )
    }
}

private struct StaticRewriteSettingsProvider: RewriteSettingsProviding {
    let config: ProviderConfig
    let apiKeyValue: String
    let behavior: RewriteBehavior

    init(config: ProviderConfig, apiKey: String, behavior: RewriteBehavior) {
        self.config = config
        self.apiKeyValue = apiKey
        self.behavior = behavior
    }

    func providerConfig() throws -> ProviderConfig {
        config
    }

    func apiKey() throws -> String {
        apiKeyValue
    }

    func rewriteBehavior() -> RewriteBehavior {
        behavior
    }
}
