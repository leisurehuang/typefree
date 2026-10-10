# custom-asr-provider Specification

## Purpose
TBD - created by archiving change custom-asr-provider. Update Purpose after archive.
## Requirements
### Requirement: 自定义识别服务商档位

「设置 → 模型」页识别卡片的服务商分段控件 SHALL 提供「自定义」档。选中时 SHALL 展示 Base URL、模型、API Key 三个输入项（与润色自定义档同范式），且 SHALL NOT 显示版本/模型选择行（自定义无版本概念）。现有火山 / 百炼档行为 SHALL 保持不变。

#### Scenario: 切到自定义档
- **WHEN** 用户在识别卡服务商分段控件点选「自定义」
- **THEN** 动态区显示三输入，版本行隐藏
- **AND** `bigasr_version` 保存为 `custom`

#### Scenario: 切走再切回保留输入
- **WHEN** 填过内容后切到其他服务商再切回
- **THEN** 已填的 Base URL、模型、API Key 保留

### Requirement: 转写端点拼接

系统 SHALL 按 OpenAI 习惯拼接：Base URL（可带 /v1、可带尾斜杠）+ `/audio/transcriptions`；已带完整路径原样用；拼接前去空白与尾斜杠；仅认 http/https；非法视为未配置。

#### Scenario: 常规拼接
- **WHEN** Base URL 为 `https://api.siliconflow.cn/v1`
- **THEN** 请求发往 `https://api.siliconflow.cn/v1/audio/transcriptions`

#### Scenario: 已含完整路径
- **WHEN** Base URL 以 `/audio/transcriptions` 结尾
- **THEN** 原样使用，不重复拼接

### Requirement: 配置完整性判定

`bigasr_version == "custom"` 时，Base URL、模型、API Key 三项 SHALL 全部非空且 URL 合法才算已配置（自带 Key）。缺任一项 SHALL 走「未配 Key」相同兜底（missingCredentials / 托管通道判定），不发无效请求。

#### Scenario: 缺项不发请求
- **WHEN** 任一项为空或 URL 非法
- **THEN** 识别报未配置类错误，不发请求

#### Scenario: 配齐即自带 Key
- **WHEN** 三项齐
- **THEN** `HostedRoute` ownKeyConfigured=true，识别不走试用/会员转发

### Requirement: multipart 请求

自定义档 SHALL 以 multipart/form-data 上传：`file` 字段（WAV 16k 单声道，文件名 audio.wav，Content-Type audio/wav）+ `model` 字段 + `response_format=json` 字段，Bearer 认证；SHALL NOT 传 `language` 参数。响应 SHALL 取 `.text` 字段。

#### Scenario: 请求体结构
- **WHEN** 发起识别
- **THEN** multipart 含上述三字段，音频为 WAV

### Requirement: 错误处理与并发

非 200 响应（401/429/5xx 等）SHALL 原样回报服务端错误信息，不重试不降级；长录音分段识别时并发 SHALL 压到 2。

#### Scenario: 429 原样回报
- **WHEN** 端点返回 429
- **THEN** 用户看到服务端错误信息，无自动重试

### Requirement: 凭证与密钥存储

API Key SHALL 经 `custom_asr_api_key` 存钥匙串（`secretKeys` 路由），明文永不落 config.json；清空输入即删凭证；env 兜底 `CUSTOM_ASR_API_KEY`。

#### Scenario: 保存与删除
- **WHEN** 输入并失焦
- **THEN** 写入钥匙串且 config 无明文
- **WHEN** 清空并失焦
- **THEN** 钥匙串凭证被删除

### Requirement: 测试连接

自定义档 SHALL 复用识别卡「测试连接」（发 0.3s 静音）：HTTP 200 且响应可解析即「✓ 连接成功」（空文本也算）；失败显示简短错误。

#### Scenario: 静音测试
- **WHEN** 三项配置有效，点「测试连接」
- **THEN** 端点返回 200（文本可为空）时显示 ✓

### Requirement: 全链路接入

配置自定义 ASR 后，「按住说话 → 出整理文字」SHALL 使用自定义端点完成识别；自定义 ASR 与自定义润色 SHALL 可同时使用（配置互相独立）。

#### Scenario: 语音输入走自定义 ASR
- **WHEN** 自定义 ASR 配置齐全，用户按住说话后松手
- **THEN** 识别文本来自自定义端点，后续润色按所选担任商处理

