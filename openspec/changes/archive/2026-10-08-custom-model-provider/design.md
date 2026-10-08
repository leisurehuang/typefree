# Design · custom-model-provider

Gate 2（2026-10-08 确认）技术方案存档。

## 改动面

**VoicePolishCore（headless 核心，SwiftPM 包）**

- `VoicePolishConfig.swift`
  - `secretKeys` 集合新增 `custom_api_key`：密钥经既有 secret 路由写钥匙串；`reconcileSecrets()` 启动时自动收敛明文残留，无需迁移代码。
- `AIPolisher.swift`
  - `polishProvider()` 新增 `case "custom"`：读 `custom_api_key`（env 兜底 `CUSTOM_API_KEY`）、`custom_polish_base_url`、`custom_polish_model`，三项齐且 URL 合法才返回非 nil。
  - 新增静态 `customChatCompletionsURL(from:)`：去空白/尾斜杠；已带 `/chat/completions` 原样用；否则追加。非法返回 nil。
  - `currentPolishSelection()` 加 custom case（首页健康卡正确显示）。
  - `makeBody` 对 custom 只发通用参数：`temperature: 0.1`、`max_tokens: 2000`；不发 `enable_thinking` / `result_format` / `top_p`。
  - 新增 `fetchCustomModels(baseURL:apiKey:completion:)`：`GET {base}/models` + Bearer，解析 `data[].id`。
- 新 config keys：`custom_polish_base_url`、`custom_polish_model`（config.json 明文）、`custom_api_key`（钥匙串）。

**mac/Sources（App UI）**

- `SettingsWindowController.swift`
  - `polishSegProviders`：`["qwen", "custom", "none"]`；豆包老用户 `["qwen", "doubao", "custom", "none"]`。
  - `polishProviderLabel("custom") = "自定义"`。
  - `refreshPolishKeyField(for: "custom")`：Base URL 文本框 + 模型文本框（手填）+「⤓ 拉取列表」按钮（成功弹 NSMenu 选择回填）+ API Key 密码框（`NSSecureTextField`）+ 说明文案；获取密钥链接隐藏。
  - 新增字段属性 `customBaseURLField` / `customModelField` / `customAPIKeyField`，delegate 接 `controlTextDidEndEditing` 即时保存。
  - `persistModelFields()` 持久化三项（key 走 `saveSecret`，URL/模型走 `config.save`）。
  - 测试连接复用 `testPolishConnection`（`polishCloudASROutput(text: "测试")` 自动走 custom 分支）。

## 影响面 & 调用路径（Grep/Read 调研，仓库无 .codegraph 索引）

- `polishCloudASROutput` 全部调用方（`VoicePolishPipeline.swift:273/324`、`SettingsWindowController.swift:5414/6038/6153`）经 `polishProvider()` 取配置——零改动自动生效。
- `HostedRoute.current(ownKeyConfigured: polishProvider() != nil)`（HostedRoute.swift:30）：custom 配齐即自带 Key，不走托管。
- 直连成功走 `TrialManager.recordSelfKeyUsage` 本地记账，不变。
- 403 降级（`attemptQwenPolish`）只在 qwen 分支；custom 走 `callChatCompletionsWithTokens` 单发、错误原样回报。
- 现有 qwen / doubao / 隐藏 zhipu 分支不动。

## 数据模型 / 迁移

无数据库。3 个新 config key，老用户无感知，无迁移。

## 接口设计

App 是纯客户端，无对外 API 变化。新增对目标端点的请求：`GET {base}/models`、`POST {base}/chat/completions`（OpenAI 标准协议）。

## 项目规则

仓库无 `CLAUDE.md`；遵循 `mac/CONTRIBUTING.md` 与既有范式：密钥只进钥匙串、headless 逻辑进 `VoicePolishCore`、UI 进 app target、中文注释、XCTest。
