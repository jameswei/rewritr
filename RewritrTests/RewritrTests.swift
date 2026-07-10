import AppKit
import Carbon.HIToolbox
import XCTest
@testable import Rewritr

final class RewritrTests: XCTestCase {
    func testScaffoldLoads() {
        XCTAssertTrue(true)
    }

    func testChatCompletionsURLUsesExactProviderURL() {
        XCTAssertEqual(
            ProviderConfig.chatCompletionsURL(from: "https://api.openai.com/v1/chat/completions")?.absoluteString,
            "https://api.openai.com/v1/chat/completions"
        )
    }

    func testChatCompletionsURLDoesNotAppendEndpoint() {
        XCTAssertEqual(
            ProviderConfig.chatCompletionsURL(from: "https://example.com/custom/rewrite")?.absoluteString,
            "https://example.com/custom/rewrite"
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
            XCTAssertEqual(error.localizedDescription, "Authentication failed. Check your API key. If you use a local provider that does not need a key, leave the API key field blank. (HTTP 401: Invalid API key)")
        }
    }

    func testProviderClientOmitsAuthorizationHeaderForLocalProviderWithoutAPIKey() async throws {
        let client = ProviderClient { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

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
            apiKey: "",
            messages: [ChatMessage(role: "user", content: "Hello")]
        )

        XCTAssertEqual(result, "OK")
    }

    func testProviderClientUsesFriendlyMessagesForCommonHTTPFailures() async throws {
        let cases: [(Int, String, String)] = [
            (400, "Bad request", "The provider rejected the request. Check the Provider URL, model name, and whether the endpoint supports OpenAI-compatible Chat Completions. (HTTP 400: Bad request)"),
            (403, "Forbidden", "Access was denied. Check whether your API key is allowed to use this model and endpoint. (HTTP 403: Forbidden)"),
            (404, "Not found", "The provider endpoint was not found. Check the full Provider URL and model name; different providers may use different Chat Completions paths. (HTTP 404: Not found)"),
            (429, "Too many requests", "The provider rate limit was reached. Wait a moment, or check your provider quota. (HTTP 429: Too many requests)")
        ]

        for (statusCode, providerMessage, expectedMessage) in cases {
            let client = ProviderClient { request in
                let data = Data("""
                {
                  "error": {
                    "message": "\(providerMessage)"
                  }
                }
                """.utf8)
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: statusCode,
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
                XCTFail("Expected provider error.")
            } catch let error as ProviderClientError {
                XCTAssertEqual(error.localizedDescription, expectedMessage)
            }
        }
    }

    func testProviderTestAcceptsAnyTextResponse() async throws {
        let client = ProviderClient { request in
            let data = Data("""
            {
              "choices": [
                {
                  "message": {
                    "role": "assistant",
                    "content": "Connected"
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

        let result = try await client.testConnection(config: testConfig(), apiKey: "test-key")

        XCTAssertEqual(result, .textResponse)
    }

    func testProviderTestAcceptsEmptyTextAsReachableProvider() async throws {
        let client = ProviderClient { request in
            let data = Data("""
            {
              "choices": [
                {
                  "message": {
                    "role": "assistant",
                    "content": ""
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

        let result = try await client.testConnection(config: testConfig(), apiKey: "test-key")

        XCTAssertEqual(result, .emptyTextResponse)
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
        XCTAssertTrue(systemPrompt.contains("Always fix grammar"))
        XCTAssertTrue(systemPrompt.contains("verb tense"))
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

    func testRewriteServiceSupportsLocalProviderWithoutAPIKey() async throws {
        let settings = StaticRewriteSettingsProvider(
            config: testConfig(),
            apiKey: "",
            behavior: .previewBeforeReplacing
        )
        let client = ProviderClient { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

            let data = Data("""
            {
              "choices": [
                {
                  "message": {
                    "role": "assistant",
                    "content": "I agree."
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

        let result = try await service.rewrite(inputText: "I am agree.")

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

    @MainActor
    func testSettingsStorePersistsRewriteBehaviorImmediately() {
        let suiteName = "RewritrTests.\(UUID().uuidString)"
        let defaults = try! XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(defaults: defaults)

        store.updateRewriteBehavior(.replaceInstantly)

        XCTAssertEqual(defaults.string(forKey: SettingsKey.rewriteBehavior), RewriteBehavior.replaceInstantly.rawValue)
        XCTAssertEqual(SettingsStore(defaults: defaults).rewriteBehavior, .replaceInstantly)
    }

    @MainActor
    func testSettingsStoreAutosavesNormalProviderSettings() {
        let suiteName = "RewritrTests.\(UUID().uuidString)"
        let defaults = try! XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(defaults: defaults)

        store.updateProviderBaseURL(" https://api.example.com/v1/chat/completions ")
        store.updateProviderModel(" fast-model ")
        store.updateRequestTimeoutSeconds(35)

        XCTAssertEqual(defaults.string(forKey: SettingsKey.providerBaseURL), "https://api.example.com/v1/chat/completions")
        XCTAssertEqual(defaults.string(forKey: SettingsKey.providerModel), "fast-model")
        XCTAssertEqual(defaults.integer(forKey: SettingsKey.requestTimeoutSeconds), 35)
    }

    @MainActor
    func testSettingsStoreSavesTypedAPIKeyOnlyAfterSuccessfulProviderTest() async throws {
        let suiteName = "RewritrTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let keychain = KeychainStore(service: suiteName)
        let client = ProviderClient { request in
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
        let store = SettingsStore(defaults: defaults, keychain: keychain, client: client)
        store.updateProviderBaseURL("https://api.example.com/v1/chat/completions")
        store.updateProviderModel("fast-model")
        store.apiKeyInput = "verified-key"

        await store.testProvider()

        XCTAssertEqual(try keychain.read(account: ProviderConfig.apiKeyKeychainID), "verified-key")
        XCTAssertTrue(store.apiKeyInput.isEmpty)
    }

    @MainActor
    func testSettingsStoreDoesNotSaveTypedAPIKeyAfterFailedProviderTest() async throws {
        let suiteName = "RewritrTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let keychain = KeychainStore(service: suiteName)
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
        let store = SettingsStore(defaults: defaults, keychain: keychain, client: client)
        store.updateProviderBaseURL("https://api.example.com/v1/chat/completions")
        store.updateProviderModel("fast-model")
        store.apiKeyInput = "bad-key"

        await store.testProvider()

        XCTAssertNil(try keychain.read(account: ProviderConfig.apiKeyKeychainID))
        XCTAssertEqual(store.apiKeyInput, "bad-key")
    }

    @MainActor
    func testSettingsStoreAllowsProviderTestWithoutAPIKey() async throws {
        let suiteName = "RewritrTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let keychain = KeychainStore(service: suiteName)
        let client = ProviderClient { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let data = Data("""
            {
              "choices": [
                {
                  "message": {
                    "role": "assistant",
                    "content": "Connected"
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
        let store = SettingsStore(defaults: defaults, keychain: keychain, client: client)
        store.updateProviderBaseURL("https://localhost:11434/v1/chat/completions")
        store.updateProviderModel("local-model")

        await store.testProvider()

        XCTAssertNil(try keychain.read(account: ProviderConfig.apiKeyKeychainID))
        XCTAssertEqual(store.testState, .success("Connected. Provider URL and model are working without an API key."))
    }

    @MainActor
    func testSettingsStoreCanClearStoredAPIKey() async throws {
        let suiteName = "RewritrTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let keychain = KeychainStore(service: suiteName)
        try keychain.save("stored-key", account: ProviderConfig.apiKeyKeychainID)
        let store = SettingsStore(defaults: defaults, keychain: keychain)

        store.clearStoredAPIKey()

        XCTAssertFalse(store.hasStoredAPIKey)
        XCTAssertNil(try keychain.read(account: ProviderConfig.apiKeyKeychainID))
    }

    func testShortcutConfigurationPersistsKeyCodeAndModifiers() {
        let suiteName = "RewritrTests.\(UUID().uuidString)"
        let defaults = try! XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let shortcut = ShortcutConfiguration(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(controlKey | optionKey | shiftKey)
        )

        shortcut.save(to: defaults)

        XCTAssertEqual(ShortcutConfiguration.load(from: defaults), shortcut)
        XCTAssertEqual(defaults.string(forKey: SettingsKey.globalShortcutLabel), "Control+Option+Shift+K")
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

    @MainActor
    func testCopyTextToClipboardWritesPlainString() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("RewritrTests.\(UUID().uuidString)"))
        let automator = ClipboardAutomator(pasteboard: pasteboard)

        let copied = automator.copyTextToClipboard("rewritten text")

        XCTAssertTrue(copied)
        XCTAssertEqual(pasteboard.string(forType: .string), "rewritten text")
    }

    @MainActor
    func testRewritePreviewModelUpdatesActionsWithState() {
        var copiedValue = "initial"
        let loadingActions = RewritePreviewActions(
            replace: {},
            copy: { copiedValue = "loading" },
            retry: {},
            dismiss: {}
        )
        let resultActions = RewritePreviewActions(
            replace: {},
            copy: { copiedValue = "result" },
            retry: {},
            dismiss: {}
        )
        let model = RewritePreviewModel(state: .loading, actions: loadingActions)

        model.update(state: .result(text: "rewritten text", isCopied: false), actions: resultActions)
        model.actions.copy()

        XCTAssertEqual(copiedValue, "result")
    }

    private func testConfig() -> ProviderConfig {
        ProviderConfig(
            baseURL: "https://api.example.com/v1/chat/completions",
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
