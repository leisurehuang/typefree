# Design · custom-asr-provider

Gate 2（2026-10-10 确认）技术方案存档。

## 改动面

**核心（VoicePolishCore）**

- `CloudASRTranscriber.swift`
  - `ASRProvider` 加 `.custom`；`ASRVersion` 加 `.custom`（provider=.custom、isSync=true、displayName=自定义、resourceID=""、modelIdentifier 读 `custom_asr_model`）。全库无 `ASRVersion.allCases` 遍历（UI 均为显式 switch），编译器穷尽性检查兜底。
  - `isConfigured(version:)`：custom → `customASRProvider() != nil`；`missingConfigurationHint()` 更新。
  - `transcribe(samples:version:)` 分发 switch 加 `.custom` 分支；**custom 档固定 WAV 16k 单声道**（内置档保持 M4A 优先）。
  - 静态 `customASRProvider(config:) -> (url, model, apiKey)?`：三项齐 + URL 合法（env 兜底 `CUSTOM_ASR_API_KEY`）。
  - 静态 `customTranscriptionsURL(from:)`：补 `/audio/transcriptions`。
  - `transcribeCustom(...)`：multipart 上传 + 响应解析；multipart 构造与响应解析抽纯静态函数 `multipartBody(boundary:audioData:format:model:)`、`parseTranscriptionsResponse(data:)`（取 `.text`；错误经 `AIPolisher.extractAPIErrorMessage` 同款 OpenAI 形状）。
  - `transcribeAuto`：custom 与百炼同样并发压到 2（免费档限 RPM）。
- 新内部枚举 `CustomEndpoint`（base 规整 + 拼 path）：`AIPolisher.customChatCompletionsURL`/`customModelsURL` 改为委托，公开 API 与既有测试不变。
- `VoicePolishConfig.secretKeys` 加 `custom_asr_api_key`。
- 新 config keys：`custom_asr_base_url`、`custom_asr_model`（明文）、`custom_asr_api_key`（钥匙串）。

**UI（SettingsWindowController.swift）**

- 识别卡服务商分段加「自定义」：`asrProviderSegmentIndex`/`asrProviderChanged`/`refreshASRFields(.custom)`；核对 `showASRProviderSeg` 可见性逻辑确保自定义档显示分段。
- 自定义动态区：三输入（新字段属性 `customASRBaseURLField`/`customASRModelField`/`customASRKeyField`）+ 说明文案 + 获取密钥链接隐藏 + 版本行隐藏。
- `persistModelFields()` 持久化三项；`controlTextDidEndEditing` 注册新字段；切档时清引用防陈旧回存。
- 测试连接零改动（静音探测经 transcribe 自动走 custom；200+空文本=✓）。

## 关键决策

- **WAV 而非 M4A**：Gate 1 确认——WAV 是转写端点兼容性最好的通用格式；M4A 支持面参差。
- **不传 language**：模型自动判语言，中英混说更稳。
- **并发 2**：免费档普遍 20 RPM 量级，5 路分段并行易 429；错误原样回报不重试（验收）。
- **URL 规整共享**：`CustomEndpoint` 消除 ASR/润色两处重复；AIPolisher 仅内部委托重构。

## 影响面

- `transcribe*` 调用方（VoicePolishPipeline、ChunkedASRCoordinator、识别卡测试、历史重识别）经 `version.provider` 分发，零改动自动生效。
- `HostedRoute.current(ownKeyConfigured: isConfigured(version:))`：custom 配齐即自带 Key。自动成立。
- OmniTranscriber（一步直出）不在改动面；火山/百炼分支不动。

## 验证策略

- 单测：URL 拼接、三项完整性矩阵、multipart 结构、响应/错误解析、secretKeys 路由。
- 本机：XCTest 桩编译门禁 + 临时 ScratchVerify 真跑断言（验证后删除）。
- CI：push 后 runner 真跑 `swift test`（闭环已绿）。

## 项目规则

无 `CLAUDE.md`；按仓库范式：中文注释、XCTest、密钥只进钥匙串、headless 进 core。
