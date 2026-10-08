import XCTest
@testable import VoicePolishCore

/// 自定义模型档（custom-model-provider）：端点拼接、通用请求体、/models 解析、配置完整性。
final class CustomPolishProviderTests: XCTestCase {

    private func tmpConfig() -> VoicePolishConfig {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vpcfg-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return VoicePolishConfig(configDir: dir, secrets: InMemorySecretStore())
    }

    // MARK: - chat/completions 端点拼接

    func testChatCompletionsURLFromBareBase() {
        XCTAssertEqual(AIPolisher.customChatCompletionsURL(from: "https://api.deepseek.com")?.absoluteString,
                       "https://api.deepseek.com/chat/completions")
    }

    func testChatCompletionsURLKeepsVersionPathAndStripsTrailingSlash() {
        XCTAssertEqual(AIPolisher.customChatCompletionsURL(from: "https://api.openai.com/v1/")?.absoluteString,
                       "https://api.openai.com/v1/chat/completions")
    }

    func testChatCompletionsURLWithFullEndpointUsedAsIs() {
        XCTAssertEqual(AIPolisher.customChatCompletionsURL(from: "https://example.com/v1/chat/completions")?.absoluteString,
                       "https://example.com/v1/chat/completions")
    }

    func testChatCompletionsURLTrimsWhitespace() {
        XCTAssertEqual(AIPolisher.customChatCompletionsURL(from: "  https://api.deepseek.com/v1  \n")?.absoluteString,
                       "https://api.deepseek.com/v1/chat/completions")
    }

    func testChatCompletionsURLRejectsEmptyOrNonHTTP() {
        XCTAssertNil(AIPolisher.customChatCompletionsURL(from: nil))
        XCTAssertNil(AIPolisher.customChatCompletionsURL(from: ""))
        XCTAssertNil(AIPolisher.customChatCompletionsURL(from: "   "))
        XCTAssertNil(AIPolisher.customChatCompletionsURL(from: "ftp://example.com"))
        XCTAssertNil(AIPolisher.customChatCompletionsURL(from: "不是地址"))
    }

    // MARK: - /models 地址

    func testModelsURLComposition() {
        XCTAssertEqual(AIPolisher.customModelsURL(from: "https://api.deepseek.com")?.absoluteString,
                       "https://api.deepseek.com/models")
        XCTAssertEqual(AIPolisher.customModelsURL(from: "https://api.openai.com/v1/")?.absoluteString,
                       "https://api.openai.com/v1/models")
        // 用户把完整 chat/completions 粘进 Base URL 也能得到正确的 models 地址
        XCTAssertEqual(AIPolisher.customModelsURL(from: "https://example.com/v1/chat/completions")?.absoluteString,
                       "https://example.com/v1/models")
    }

    // MARK: - /models 响应解析（OpenAI 格式 data[].id）

    func testParseModelsListOpenAIShape() {
        let data = #"{"object":"list","data":[{"id":"deepseek-chat"},{"id":"deepseek-reasoner"},{"id":"deepseek-chat"}]}"#.data(using: .utf8)!
        XCTAssertEqual(AIPolisher.parseModelsList(from: data), ["deepseek-chat", "deepseek-reasoner"])
    }

    func testParseModelsListGarbageReturnsEmpty() {
        XCTAssertTrue(AIPolisher.parseModelsList(from: Data("not json".utf8)).isEmpty)
        XCTAssertTrue(AIPolisher.parseModelsList(from: Data("{}".utf8)).isEmpty)
        XCTAssertTrue(AIPolisher.parseModelsList(from: Data(#"{"data":[{"object":"model"}]}"#.utf8)).isEmpty)
    }

    // MARK: - 通用请求体（不带厂商专属字段）

    func testCustomPolishBodyGenericParamsOnly() {
        let body = AIPolisher.customPolishBody(model: "m-1", systemPrompt: "s", userPrompt: "u")
        XCTAssertEqual(Set(body.keys), ["model", "messages", "temperature", "max_tokens"])
        XCTAssertEqual(body["temperature"] as? Double, 0.1)
        XCTAssertEqual(body["max_tokens"] as? Int, 2000)
        XCTAssertNil(body["enable_thinking"])
        XCTAssertNil(body["result_format"])
        XCTAssertNil(body["top_p"])
        XCTAssertNil(body["thinking"])
    }

    /// 问 AI（answer 链路）的 custom body 同样只发通用参数；stream 是 OpenAI 标准字段（渐进显示用）。
    func testCustomAskBodyGenericParamsOnly() {
        let msgs: [[String: Any]] = [["role": "user", "content": "q"]]
        let body = AIPolisher.customAskBody(model: "m-1", messages: msgs)
        XCTAssertEqual(Set(body.keys), ["model", "messages", "stream", "temperature", "max_tokens"])
        XCTAssertEqual(body["temperature"] as? Double, 0.5)
        XCTAssertEqual(body["max_tokens"] as? Int, 1200)
        XCTAssertEqual((body["messages"] as? [[String: Any]])?.count, 1)
        XCTAssertNil(body["enable_thinking"])
        XCTAssertNil(body["enable_search"])
        XCTAssertNil(body["top_p"])
        XCTAssertNil(body["thinking"])   // thinking 是 GLM/豆包字段，严格端点会 4xx
    }

    // MARK: - 配置完整性（三项齐才算已配置）

    func testCustomProviderComplete() {
        let cfg = tmpConfig()
        cfg.save(value: "https://api.deepseek.com", forKey: "custom_polish_base_url")
        cfg.save(value: "deepseek-chat", forKey: "custom_polish_model")
        cfg.saveSecret("sk-x", forKey: "custom_api_key")
        let p = AIPolisher.customPolishProvider(config: cfg)
        XCTAssertEqual(p?.name, "custom")
        XCTAssertEqual(p?.url.absoluteString, "https://api.deepseek.com/chat/completions")
        XCTAssertEqual(p?.model, "deepseek-chat")
        XCTAssertEqual(p?.apiKey, "sk-x")
    }

    func testCustomProviderNilWhenAnyFieldMissing() {
        let cfg = tmpConfig()
        XCTAssertNil(AIPolisher.customPolishProvider(config: cfg))   // 全空
        cfg.save(value: "https://api.deepseek.com", forKey: "custom_polish_base_url")
        XCTAssertNil(AIPolisher.customPolishProvider(config: cfg))   // 缺 model + key
        cfg.save(value: "deepseek-chat", forKey: "custom_polish_model")
        XCTAssertNil(AIPolisher.customPolishProvider(config: cfg))   // 缺 key
        cfg.saveSecret("", forKey: "custom_api_key")
        XCTAssertNil(AIPolisher.customPolishProvider(config: cfg))   // key 被清空 = 删除凭证
    }

    func testCustomProviderNilWhenURLInvalid() {
        let cfg = tmpConfig()
        cfg.save(value: "不是地址", forKey: "custom_polish_base_url")
        cfg.save(value: "m", forKey: "custom_polish_model")
        cfg.saveSecret("sk-x", forKey: "custom_api_key")
        XCTAssertNil(AIPolisher.customPolishProvider(config: cfg))
    }
}
