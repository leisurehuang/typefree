import XCTest
@testable import VoicePolishCore

/// 自定义识别档（custom-asr-provider）：端点拼接、配置完整性、multipart 结构、响应解析。
final class CustomASRProviderTests: XCTestCase {

    private func tmpConfig() -> VoicePolishConfig {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vpcfg-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return VoicePolishConfig(configDir: dir, secrets: InMemorySecretStore())
    }

    // MARK: - /audio/transcriptions 端点拼接

    func testTranscriptionsURLFromBareBase() {
        XCTAssertEqual(CloudASRTranscriber.customTranscriptionsURL(from: "https://api.siliconflow.cn/v1")?.absoluteString,
                       "https://api.siliconflow.cn/v1/audio/transcriptions")
    }

    func testTranscriptionsURLStripsTrailingSlash() {
        XCTAssertEqual(CloudASRTranscriber.customTranscriptionsURL(from: "https://api.groq.com/openai/v1/")?.absoluteString,
                       "https://api.groq.com/openai/v1/audio/transcriptions")
    }

    func testTranscriptionsURLWithFullEndpointUsedAsIs() {
        XCTAssertEqual(CloudASRTranscriber.customTranscriptionsURL(from: "https://example.com/v1/audio/transcriptions")?.absoluteString,
                       "https://example.com/v1/audio/transcriptions")
    }

    func testTranscriptionsURLTrimsWhitespace() {
        XCTAssertEqual(CloudASRTranscriber.customTranscriptionsURL(from: "  https://api.siliconflow.cn/v1 \n")?.absoluteString,
                       "https://api.siliconflow.cn/v1/audio/transcriptions")
    }

    func testTranscriptionsURLRejectsEmptyOrNonHTTP() {
        XCTAssertNil(CloudASRTranscriber.customTranscriptionsURL(from: nil))
        XCTAssertNil(CloudASRTranscriber.customTranscriptionsURL(from: ""))
        XCTAssertNil(CloudASRTranscriber.customTranscriptionsURL(from: "ftp://example.com"))
        XCTAssertNil(CloudASRTranscriber.customTranscriptionsURL(from: "不是地址"))
    }

    /// 润色档的端点函数仍正常（共享 CustomEndpoint 后互不影响）
    func testPolishEndpointStillWorks() {
        XCTAssertEqual(AIPolisher.customChatCompletionsURL(from: "https://api.deepseek.com")?.absoluteString,
                       "https://api.deepseek.com/chat/completions")
    }

    // MARK: - 配置完整性（三项齐才算已配置）

    func testCustomASRProviderComplete() {
        let cfg = tmpConfig()
        cfg.save(value: "https://api.siliconflow.cn/v1", forKey: "custom_asr_base_url")
        cfg.save(value: "SenseVoice-Small", forKey: "custom_asr_model")
        cfg.saveSecret("sk-x", forKey: "custom_asr_api_key")
        let p = CloudASRTranscriber.customASRProvider(config: cfg)
        XCTAssertEqual(p?.url.absoluteString, "https://api.siliconflow.cn/v1/audio/transcriptions")
        XCTAssertEqual(p?.model, "SenseVoice-Small")
        XCTAssertEqual(p?.apiKey, "sk-x")
    }

    func testCustomASRProviderNilWhenAnyFieldMissing() {
        let cfg = tmpConfig()
        XCTAssertNil(CloudASRTranscriber.customASRProvider(config: cfg))   // 全空
        cfg.save(value: "https://api.siliconflow.cn/v1", forKey: "custom_asr_base_url")
        XCTAssertNil(CloudASRTranscriber.customASRProvider(config: cfg))   // 缺 model + key
        cfg.save(value: "SenseVoice-Small", forKey: "custom_asr_model")
        XCTAssertNil(CloudASRTranscriber.customASRProvider(config: cfg))   // 缺 key
        cfg.saveSecret("", forKey: "custom_asr_api_key")
        XCTAssertNil(CloudASRTranscriber.customASRProvider(config: cfg))   // key 清空 = 删凭证
    }

    func testCustomASRProviderNilWhenURLInvalid() {
        let cfg = tmpConfig()
        cfg.save(value: "不是地址", forKey: "custom_asr_base_url")
        cfg.save(value: "m", forKey: "custom_asr_model")
        cfg.saveSecret("sk-x", forKey: "custom_asr_api_key")
        XCTAssertNil(CloudASRTranscriber.customASRProvider(config: cfg))
    }

    /// 版本枚举映射：custom 档的 provider / 同步性 / 不进降级链
    func testASRVersionCustomMapping() {
        XCTAssertEqual(CloudASRTranscriber.ASRVersion.custom.provider, .custom)
        XCTAssertTrue(CloudASRTranscriber.ASRVersion.custom.isSync)
        XCTAssertNil(CloudASRTranscriber.ASRVersion.custom.nextForFallback)
        XCTAssertEqual(CloudASRTranscriber.ASRVersion(rawValue: "custom"), .custom)
    }

    // MARK: - multipart 请求体

    func testMultipartBodyStructure() {
        let wav = Data([0x52, 0x49, 0x46, 0x46, 0x00, 0x01, 0x02, 0x03])   // "RIFF"...
        let body = CloudASRTranscriber.multipartBody(boundary: "b1", wavData: wav, model: "SenseVoice-Small")
        let s = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(s.hasPrefix("--b1\r\n"), "应以 boundary 开始")
        XCTAssertTrue(s.contains("name=\"file\"; filename=\"audio.wav\""), "file 字段带文件名")
        XCTAssertTrue(s.contains("Content-Type: audio/wav"), "file 字段带 WAV 类型")
        XCTAssertTrue(s.contains("name=\"model\"\r\n\r\nSenseVoice-Small\r\n"), "model 字段")
        XCTAssertTrue(s.contains("name=\"response_format\"\r\n\r\njson\r\n"), "response_format=json")
        XCTAssertTrue(s.hasSuffix("--b1--\r\n"), "应以闭合 boundary 结束")
        XCTAssertFalse(s.contains("language"), "不传 language（模型自动判语言）")
        // 二进制负载原样保留
        XCTAssertNotNil(body.range(of: wav), "WAV 二进制应原样嵌入")
    }

    // MARK: - 响应解析

    func testParseTranscriptionsSuccess() {
        let ok = Data(#"{"text":" 你好，世界 "}"#.utf8)
        if case .success(let text) = CloudASRTranscriber.parseTranscriptionsResponse(data: ok) {
            XCTAssertEqual(text, "你好，世界")   // 去首尾空白
        } else {
            XCTFail("应解析成功")
        }
        // 空文本：OpenAI 兼容端点对静音的常见返回，解析层照样成功（空串由调用方转 noSpeech）
        let empty = Data(#"{"text":""}"#.utf8)
        if case .success(let text) = CloudASRTranscriber.parseTranscriptionsResponse(data: empty) {
            XCTAssertEqual(text, "")
        } else {
            XCTFail("空文本应解析成功")
        }
    }

    func testParseTranscriptionsServerErrorShapes() {
        // OpenAI 形状错误：带出人话
        let e1 = Data(#"{"error":{"message":"Invalid API key provided","code":"invalid_api_key"}}"#.utf8)
        if case .failure(let err) = CloudASRTranscriber.parseTranscriptionsResponse(data: e1),
           case .serverFailed(let msg) = err {
            XCTAssertTrue(msg.contains("API Key"), "错误信息应含服务端原因：\(msg)")
        } else {
            XCTFail("应解析为 serverFailed")
        }
        // 顶层 message 形状
        let e2 = Data(#"{"message":"rate limit exceeded","code":429}"#.utf8)
        if case .failure(let err) = CloudASRTranscriber.parseTranscriptionsResponse(data: e2),
           case .serverFailed(let msg) = err {
            // extractAPIErrorMessage 会把 rate limit 翻成友好中文，两种都算带出了原因
            XCTAssertTrue(msg.contains("rate limit") || msg.contains("频繁"), "应带出原因：\(msg)")
        } else {
            XCTFail("应解析为 serverFailed")
        }
    }

    func testParseTranscriptionsGarbage() {
        if case .failure(let err) = CloudASRTranscriber.parseTranscriptionsResponse(data: Data("not json".utf8)) {
            XCTAssertEqual(err.localizedDescription, CloudASRTranscriber.TranscriptionError.parseError.localizedDescription)
        } else {
            XCTFail("非 JSON 应报 parseError")
        }
    }
}
