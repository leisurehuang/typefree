---
status: done
feature: custom-asr-provider
---

# 自定义语音识别服务商（OpenAI 兼容 /audio/transcriptions）

## Why

识别（ASR）目前只有火山引擎 / 阿里百炼两家，协议专有、端点写死。用户希望接入任意 OpenAI 兼容的转写端点——典型是硅基流动 SenseVoice-Small（国内、免费、中文强）与 Groq whisper-large-v3-turbo（海外、免费档）。

## What Changes

- 识别卡片服务商分段控件加第三档「**自定义**」：填 Base URL、模型名、API Key（与润色自定义档完全独立的配置）。
- 运行时上传 WAV（16k 单声道）到 `POST {Base URL}/audio/transcriptions`（multipart：file + model + response_format=json，Bearer），取响应 `.text`。
- Base URL 拼接/容错规则与润色自定义档一致；三项齐才算已配置（= 自带 Key，不走托管通道）。
- `custom_asr_api_key` 进钥匙串路由；错误原样回报不重试；分段识别并发压到 2。
- 不做：本地模型、流式识别、热词 biasing（词库后处理纠错照常）、/models 拉取、多配置；内置火山/百炼行为零变化。
