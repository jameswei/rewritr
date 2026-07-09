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
