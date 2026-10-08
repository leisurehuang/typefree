## ADDED Requirements

### Requirement: 自定义润色服务商档位

「设置 → 模型」页的润色服务商分段控件 SHALL 提供「自定义」档位。选中时 SHALL 展示 Base URL、模型、API Key 三个输入项与「测试连接」按钮，交互范式与现有档位一致。现有 qwen / doubao（及隐藏的 zhipu）档位行为 SHALL 保持不变。

#### Scenario: 切到自定义档
- **WHEN** 用户在润色服务商分段控件点选「自定义」
- **THEN** 动态区显示 Base URL、模型、API Key 输入项与「测试连接」按钮
- **AND** `polish_provider` 保存为 `custom`

#### Scenario: 切走再切回保留输入
- **WHEN** 用户在自定义档填过内容后切到其他档位，再切回自定义
- **THEN** 之前填写的 Base URL、模型、API Key 仍在

### Requirement: Base URL 拼接规则

系统 SHALL 按 OpenAI 生态习惯拼接端点：用户填 Base URL（如 `https://api.deepseek.com` 或 `https://api.openai.com/v1`），App 追加 `/chat/completions`。若所填 URL 已以 `/chat/completions` 结尾，SHALL 原样使用、不重复拼接。拼接前 SHALL 去除首尾空白与末尾多余斜杠。无法构成合法 URL 时 SHALL 视为未配置。

#### Scenario: 常规 Base URL
- **WHEN** Base URL 为 `https://api.deepseek.com`
- **THEN** 实际请求发往 `https://api.deepseek.com/chat/completions`

#### Scenario: 带版本路径与尾斜杠
- **WHEN** Base URL 为 `https://api.openai.com/v1/`
- **THEN** 实际请求发往 `https://api.openai.com/v1/chat/completions`

#### Scenario: 已含完整路径
- **WHEN** Base URL 为 `https://example.com/v1/chat/completions`
- **THEN** 实际请求发往该 URL 本身

### Requirement: 自定义档配置完整性判定

`polish_provider` 为 `custom` 时，Base URL、模型名、API Key 三项 SHALL 全部非空才视为已配置（等价于自带 Key 已配）。任何一项缺失时 SHALL 与「未配 API Key」走相同的兜底路径（托管通道或明确报错），不发出无效请求。

#### Scenario: 缺任一项不发请求
- **WHEN** `polish_provider == "custom"` 且三项中任一项为空
- **THEN** `AIPolisher.polishProvider()` 返回 nil
- **AND** 链路落入与未配 Key 相同的兜底分支（无托管通道时报「未配置」类错误）

#### Scenario: 配齐即视为自带 Key
- **WHEN** 三项全部非空且 URL 合法
- **THEN** `HostedRoute` 判定 own key 已配置，不走作者服务器托管通道
- **AND** 润色/问 AI 请求从本机直发该端点

### Requirement: 通用请求参数

自定义档的 chat/completions 请求体 SHALL 只包含通用参数（`model`、`messages`、`temperature: 0.1`、`max_tokens: 2000`），SHALL NOT 携带 `enable_thinking`、`result_format`、`top_p` 等特定厂商字段。错误（含 403）SHALL 原样回报，不做模型降级重试。

#### Scenario: 请求体内容
- **WHEN** 自定义档发起润色请求
- **THEN** 请求体仅含 `model` / `messages` / `temperature` / `max_tokens`，无厂商专属字段

### Requirement: 模型列表拉取

自定义档 SHALL 提供「拉取列表」操作：以已填的 Base URL 与 API Key 请求 `GET {Base URL}/models`（Bearer 认证），解析 OpenAI 格式响应（`data[].id`）供用户选择；选择后回填模型输入框。拉取失败 SHALL 显示简短错误，不影响手填。

#### Scenario: 拉取成功
- **WHEN** Base URL 与 Key 有效，用户点「拉取列表」
- **THEN** 弹出模型候选菜单（来自 `data[].id`），点选后回填模型输入框并保存

#### Scenario: 拉取失败
- **WHEN** 端点不可达或不支持 `/models`
- **THEN** 显示错误提示，模型输入框仍可手填

### Requirement: API Key 钥匙串存储

自定义档的 API Key SHALL 通过 `VoicePolishConfig` 的 secret 路由存入钥匙串（`custom_api_key` 加入 `secretKeys`），绝不写入明文 config.json。清空输入框 SHALL 删除该凭证。

#### Scenario: 保存与删除凭证
- **WHEN** 用户在 API Key 框输入并失焦
- **THEN** Key 写入钥匙串且 config.json 无明文
- **WHEN** 用户清空该框并失焦
- **THEN** 钥匙串中该凭证被删除

### Requirement: 测试连接

自定义档 SHALL 复用现有「测试连接」：以当前输入的配置发一次真实润色请求（文本「测试」），成功显示「✓ 连接成功」，失败显示简短错误。

#### Scenario: 测试成功
- **WHEN** 三项配置有效且端点可用，点「测试连接」
- **THEN** 显示「✓ 连接成功」

#### Scenario: 测试失败
- **WHEN** URL/Key/模型任一无效
- **THEN** 显示「✗」加简短错误原因

### Requirement: 润色与问 AI 链路接入

配置自定义档后，「按住说话 → 松手出整理文字」与「空白处问 AI → 右上角面板出答案」两条链路 SHALL 使用自定义端点完成。

#### Scenario: 语音输入走自定义模型
- **WHEN** 自定义档配置齐全，用户按住说话后松手
- **THEN** 整理文字由自定义端点的模型生成并输入光标处

#### Scenario: 问 AI 走自定义模型
- **WHEN** 自定义档配置齐全，用户在空白处按住提问
- **THEN** 回答由自定义端点的模型生成并显示在右上角面板
