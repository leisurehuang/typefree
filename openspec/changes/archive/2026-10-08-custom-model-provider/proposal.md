---
status: done
feature: custom-model-provider
---

# 自定义模型通道（润色 / 问 AI）

## Why

Typefree 的润色（AI 整理）与问 AI 目前只能从内置服务商（百炼/智谱/豆包）和固定模型列表中选择，端点 URL 全部硬编码。希望使用 DeepSeek、Kimi、OpenRouter、本地 Ollama/LM Studio 等任意 OpenAI 兼容端点的用户无法接入。

## What Changes

- 「设置 → 模型」页润色服务商分段控件新增第四档「**自定义**」：填 Base URL、模型名、API Key 三项。
- 运行时润色与问 AI（共用 `AIPolisher.polishCloudASROutput` 链路）直接请求 `{Base URL}/chat/completions`，OpenAI 兼容协议 + Bearer 认证 + 通用参数。
- 模型名可手填，也可「拉取列表」（`GET {Base URL}/models`）后选择。
- API Key 沿用钥匙串存储（`secretKeys` 路由），清空即删除凭证。
- 自定义档视为「自带 Key」：`HostedRoute` 判定 own key 已配置，不走作者服务器托管通道。
- 不做：语音识别/一步直出自定义、多配置管理、流式输出、403 自动降级队列、非 OpenAI 兼容协议。
