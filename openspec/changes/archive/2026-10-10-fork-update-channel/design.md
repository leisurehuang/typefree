# Design · fork-update-channel

Gate 2（2026-10-10 确认）技术方案存档。

## 改动面

- `mac/Info.plist`：`SUFeedURL` → raw appcast 地址；`SUPublicEDKey` → fork 公钥；版本 3.0.13（两键）。
- `mac/Sources/AppDelegate.swift`：`AppLinks.appcastURL` → 同一 raw 地址。
- 新 `mac/scripts/make_appcast.sh`：
  - 内嵌 swift（CryptoKit）算 EdDSA：整文件字节 Ed25519、签名 base64——与 Sparkle `common_cli/Signing.swift` 的 `edSignature(data:)` 逐字节同构（公钥 32B raw / 私钥 64B raw，源码断言已核对）。
  - 条目模板：rss2.0 + sparkle 命名空间；`sparkle:version`/`sparkle:shortVersionString` = Info.plist 版本；`pubDate` RFC822；`description` CDATA；`enclosure` url=GitHub Release 资产、length、type、`sparkle:edSignature`。
  - 已有 appcast.xml 时新条目前插（保留历史）。
- `.github/workflows/build-release.yml` tag-only「Publish appcast」：`make_appcast.sh`（说明 = tag annotation）→ `gh api PUT /repos/.../contents/appcast.xml`（GITHUB_TOKEN 已有 contents:write）。
- 仓库根种子 `appcast.xml`（空 channel）。

## 密钥流程（一次性）

本机 CryptoKit 生成 Ed25519 密钥对；公钥进 Info.plist；私钥打印一次给用户（密码管理器）+ 用户手动配仓库 Secret `SPARKLE_PRIVATE_KEY`。**打 v3.0.13 tag 前必须配好**，否则 CI 步骤明确报错。

## 验证

- 本机：ed25519 verify 反向自证签名；生成的 appcast 用仓库 `AppcastParser` 解析验证。
- CI：tag run 全绿 + appcast 提交回 main + raw 可访问。
- E2E（弹窗→下载→校验→安装）在 v3.0.14 发布时验证。

## 影响面

- Sparkle（读 Info.plist）与更新历史（读 AppLinks）自动切换；v3.0.12 及更早版本仍指官方源——不要在其上点更新。
- main 构建不受影响；raw CDN 缓存约 5 分钟可接受。
