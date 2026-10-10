# Tasks · custom-asr-provider

## 1. 核心（VoicePolishCore）

- [x] 1.1 `CustomEndpoint` 共享规整（新文件）+ `AIPolisher` 两个 URL 函数委托改造（现有测试不回归）
- [x] 1.2 `VoicePolishConfig.secretKeys` 加 `custom_asr_api_key`（+ 路由测试）
- [x] 1.3 `CloudASRTranscriber`：`ASRProvider.custom` / `ASRVersion.custom` / `isConfigured` / `missingConfigurationHint` / 分发 switch（先写单测：URL 拼接、三项矩阵）
- [x] 1.4 `customASRProvider` + `customTranscriptionsURL` + `transcribeCustom`（multipart + 响应解析纯函数先行单测）
- [x] 1.5 `transcribeAuto` 并发对 custom 压到 2
- [x] 1.6 `CustomASRProviderTests`：URL 拼接 / 完整性矩阵 / multipart 结构 / 响应与错误解析

## 2. UI（SettingsWindowController）

- [x] 2.1 识别卡分段加「自定义」档（index 映射 / provider 切换 / `showASRProviderSeg` 可见性核对）
- [x] 2.2 `refreshASRFields(.custom)`：三输入 + 说明 + 链接隐藏 + 版本行隐藏 + 切档清引用
- [x] 2.3 `persistModelFields` 持久化三项 + `controlTextDidEndEditing` 注册
- [x] 2.4 测试连接在自定义档验证（静音 → 200+空文本 = ✓）

## 3. 验证

- [x] 3.1 本机门禁：XCTest 桩 typecheck 全测试文件 + ScratchVerify 断言全绿（验证后删除）
- [x] 3.2 App 源码 swiftc -typecheck 绿
- [x] 3.3 独立评审（spec vs 实现）
- [ ] 3.4 push 后 CI `swift test` 全绿（含跳过守卫）
