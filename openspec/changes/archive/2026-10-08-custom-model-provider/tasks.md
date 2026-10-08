# Tasks · custom-model-provider

## 1. 核心（VoicePolishCore）

- [x] 1.1 `VoicePolishConfig.secretKeys` 加入 `custom_api_key`（含 `SecretStoreRoutingTests` 补路由断言）
- [x] 1.2 `AIPolisher.customChatCompletionsURL(from:)`：去空白/尾斜杠、已带 `/chat/completions` 不重复拼、非法返回 nil（先写单测）
- [x] 1.3 `AIPolisher.polishProvider()` 加 `case "custom"`：三项齐 + URL 合法才返回；缺任一项返回 nil
- [x] 1.4 `AIPolisher.currentPolishSelection()` 加 custom case
- [x] 1.5 `polishCloudASROutput` 的 `makeBody` 对 custom 只发通用参数（temperature 0.1 / max_tokens 2000），无厂商专属字段（先写单测）
- [x] 1.6 `AIPolisher.fetchCustomModels(baseURL:apiKey:completion:)`：GET {base}/models + Bearer，解析 `data[].id`（先写单测）
- [x] 1.7 自定义档直发、错误原样回报（403 不降级）：润色走 `callChatCompletionsWithTokens` 单发（1.3 分支天然成立）；问 AI `answer()` 的 403 分支加 `provider.name != "custom"` 守卫、不 markExhausted；两条链路的 custom 请求体（`customPolishBody` / `customAskBody`）均有通用参数单测

## 2. UI（SettingsWindowController）

- [x] 2.1 `polishSegProviders` 加 `custom` 档；`polishProviderLabel("custom") = "自定义"`；`polishModelDefault` 无需默认值
- [x] 2.2 `refreshPolishKeyField(for: "custom")`：Base URL / 模型 / API Key 三输入 + 说明文案 + 获取密钥链接隐藏
- [x] 2.3 「⤓ 拉取列表」按钮：`fetchCustomModels` 成功弹 NSMenu 选择回填；失败红字提示
- [x] 2.4 三个新字段接 `controlTextDidEndEditing` + `persistModelFields()` 持久化（key 走 saveSecret）
- [x] 2.5 测试连接在自定义档可用（复用 `testPolishConnection`，验证分支与按钮状态）

## 3. 验证

- [x] 3.1 逻辑断言全绿（ScratchVerify 临时目标 33/33，与新增 XCTest 用例一一对应后已删除；本机仅 CommandLineTools、无 XCTest.framework，完整 `swift test` 需在装有 Xcode 的机器上执行）
- [x] 3.2 编译验证全绿：核心库 `swift build`；app 源码 `swiftc -typecheck`（SettingsWindowController 等 14 文件零错误；AppDelegate/AnswerPanel 两文件为基线既有的 CLT 编译器限制，本次未改动，已用 HEAD worktree 基线对照证实）
- [x] 3.3 回归确认：qwen / doubao / zhipu / none 分支行为不变（diff 逐处核对 + 独立评审确认）
