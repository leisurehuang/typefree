<p align="center">
  <img src="readme-assets/icon.png" width="96" height="96" alt="Typefree">
</p>

<h1 align="center">Typefree</h1>

<p align="center"><b>macOS 上的 AI 语音输入：按住说话，松手时文字已经整理好、进了光标处。</b></p>

<p align="center">
  <a href="https://github.com/leisurehuang/typefree/releases/latest"><img src="https://img.shields.io/github/v/release/leisurehuang/typefree?label=%E6%9C%80%E6%96%B0%E7%89%88&color=1d1d1f" alt="最新版"></a>
  <a href="mac/LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-1d1d1f" alt="GPL-3.0"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-1d1d1f" alt="macOS 14+">
</p>

<p align="center">
  <a href="https://github.com/leisurehuang/typefree/releases/latest/download/Typefree.dmg"><b>下载 Mac 版</b></a> ·
  <a href="https://typefree.app">官网</a> ·
  <a href="https://typefree.app/setup-guide.html">API Key 配置教程</a> ·
  <a href="README.en.md">English</a>
</p>

<p align="center">
  <img src="readme-assets/zh-mouse.gif" width="768" alt="在输入框里按住鼠标说话，松开后整理好的文字自动输入；向下拖锁定，拖远取消">
</p>

## 它做什么

在任何 App 的输入框里，按住快捷键或鼠标左键说话。松手后，识别出的口语会被 AI 去掉「嗯、啊、那个」，理顺句子、加上标点和分段，然后直接输入到光标处。说一句是一句，不用再改。

- **说话变文字**：识别 + AI 整理一步到位，微信、备忘录、浏览器、代码编辑器都能用
- **鼠标长按说话**：不想按快捷键，就在输入框里按住鼠标；说一半想松手，向下拖一点锁定；不想要了，拖远取消
- **随时问 AI**：在空白处按住鼠标说出问题，回答出现在屏幕右上角，可追问、可固定
- **语音翻译**：说完正文，结尾加一句「用英文」，这句直接输入成英文；日文、韩文同理
- **越用越准**：识别错的人名、产品名，你改过一次，下次自动认对；常用词也可以加进词库
- **历史记录**：所有输入在本机加密保存，可导出，保留多久自己定
- **多家模型**：识别用火山引擎，整理用通义千问，模型按质量和速度自动选；本 fork 另支持任意 OpenAI 兼容端点（见下）

## 本 Fork 的差异（相对上游 [kdsz001/typefree](https://github.com/kdsz001/typefree)）

在保留上游全部功能的基础上新增（每项都有 OpenSpec 规格与测试，归档于 `openspec/changes/archive/`）：

| 能力 | 说明 |
|---|---|
| **自定义润色 / 问 AI 模型** | 「设置 → 模型 → 语音优化」服务商新增「自定义」档：Base URL + 模型 + API Key 三项自填，接入任意 OpenAI 兼容端点（DeepSeek、Kimi、OpenRouter、本地 Ollama 等）；模型可手填或「拉取列表」从 `/models` 获取，配好即视为自带 Key 直连 |
| **自定义语音识别** | 「语音识别」服务商新增「自定义」档：标准 `POST {Base}/audio/transcriptions` 上传 WAV，可接硅基流动 SenseVoice-Small（免费、中文强）、Groq whisper-large-v3-turbo（免费档）等任意兼容端点；不支持热词 biasing，词库后处理纠错照常生效 |
| **更新通道指向本仓库** | Sparkle 检查更新读本仓库的 `appcast.xml`（发版时 CI 自动签名回写），fork 专属 Ed25519 签名——不会再被引导升级官方版而丢失自定义功能 |
| **GitHub Actions CI** | push 自动跑测试 + 构建；打 `v*` tag 自动发 Release：测试 → 构建 → ad hoc 签名 → DMG → 更新 appcast 一条龙 |

说明：API Key 仍然只存本机钥匙串、不经过任何中间服务器；CI 产物为 ad hoc 签名，首次打开需右键 → 「打开」。上游更新通过合并 `kdsz001:main` 定期同步。

## 三种用法

| | 怎么开始 | 费用 |
|---|---|---|
| **免费试用** | [下载 DMG](https://github.com/leisurehuang/typefree/releases/latest/download/Typefree.dmg)，装好就能用，不用配任何东西 | 7 天免费，由作者承担 |
| **自带 Key** | 在「设置 → 模型」填入你自己的 API Key（[教程](https://typefree.app/setup-guide.html)，几分钟） | **永久免费，不限字数**；费用走你自己的账户 |
| **会员** | 不想申请 Key，就开通会员，识别、整理、问 AI 全包 | ¥188 / 年 |

试用和会员通道只在官方签名版（官网 / Releases 的 DMG）里可用。自己从源码编译的版本没有这两条通道，装好后填入自己的 Key 即可，功能完全一样。

## 随时问 AI

<p align="center">
  <img src="readme-assets/zh-ask.gif" width="768" alt="在空白处按住鼠标提问，回答出现在右上角；按住面板追问；点外面收起">
</p>

看到不懂的，不用切窗口、不用复制，在空白处按住鼠标问一句。按住回答面板可以接着问；点面板外面它会缩成一行、几秒后消失，想留住就点图钉。

## 语音翻译

<p align="center">
  <img src="readme-assets/zh-translate.gif" width="768" alt="说完正文，结尾加一句「用英文」，这句直接输入成英文">
</p>

口令是程序规则识别的，不靠模型猜：默认支持英文、日文、韩文、中文，法语、德语、西班牙语可以在「探索」页打开。也可以固定一种输出语言，不用每次说口令。

## 隐私

- API Key 只保存在本机钥匙串，不上传
- 自带 Key 时，音频直接发给你选的模型厂商，不经过作者的服务器
- 试用和会员通道经作者的服务器转发，只转发、不保存音频和文字
- 历史记录在本机加密存储

完整说明见 [隐私政策](https://typefree.app/privacy.html)。

## 从源码构建

要求 macOS 14+、Xcode 26.3。

```bash
git clone https://github.com/leisurehuang/typefree.git
cd typefree/mac
./build.sh                      # 产物在 dist/
bash scripts/install_app.sh     # 安装到 /Applications
```

细节、目录说明和测试方法见 [mac/README.md](mac/README.md)。

## 仓库结构

- `mac/` — macOS App 完整源码（Swift，GPL-3.0）
- `openspec/` — 本 fork 的规格与变更归档（spec-driven 开发流程）
- `.github/workflows/` — CI：测试、构建、发版（fork 新增）
- 根目录 — 官网 [typefree.app](https://typefree.app)（GitHub Pages）

## 许可与商标

代码以 [GNU GPL-3.0](mac/LICENSE) 开源：可以自由使用、修改、再分发，但基于它的软件也必须以 GPL 开源。**「Typefree」名称、图标与官网内容不在开源许可范围内**，请勿用于你自己发布的版本，以免用户混淆。

## 反馈

- App 侧栏的「反馈」页可以直接和作者对话，能附截图
- 或者提 [Issue](https://github.com/leisurehuang/typefree/issues)：bug、想法、识别不准的例子都行
- Pull Request 目前只接受小修，见 [CONTRIBUTING](mac/CONTRIBUTING.md)
