## ADDED Requirements

### Requirement: 更新源指向本仓库

App 的 Sparkle 订阅源（`SUFeedURL`）与「更新历史」视图的数据源（`AppLinks.appcastURL`）SHALL 均指向 `https://raw.githubusercontent.com/leisurehuang/typefree/main/appcast.xml`；SHALL NOT 再请求 `typefree.app/appcast.xml`。

#### Scenario: 检查更新走 fork 源
- **WHEN** v3.0.13 及之后的版本执行「检查更新」或打开「更新历史」
- **THEN** 请求发往仓库 raw appcast 地址，不请求官方源

### Requirement: fork 专属签名密钥

Info.plist 的 `SUPublicEDKey` SHALL 替换为 fork 专属 Ed25519 公钥（32 字节 raw 的 base64，与 Sparkle 格式兼容）；对应私钥只存于用户离线保管与仓库 Secret `SPARKLE_PRIVATE_KEY`，SHALL NOT 出现在仓库、日志或构建产物中。

#### Scenario: 公钥替换
- **WHEN** 检查 Info.plist
- **THEN** `SUPublicEDKey` 为新公钥，非作者原公钥

### Requirement: appcast 生成与签名

`make_appcast.sh` SHALL 对 DMG 整文件字节做 Ed25519 签名（签名 base64，与 Sparkle `edSignature` 逐字节同构），生成含 `sparkle:version`、`sparkle:shortVersionString`、`pubDate`、`description`（CDATA）与 `enclosure`（url=GitHub Release 资产、length、type、`sparkle:edSignature`）的条目，并前插到已有 `appcast.xml`（保留历史条目）。生成的 appcast SHALL 能被仓库内 `AppcastParser` 解析出版本、日期与说明。

#### Scenario: 条目生成
- **WHEN** 以 DMG、版本 3.0.13、说明文本与私钥运行脚本
- **THEN** appcast 首条为 v3.0.13，enclosure 指向该 Release 的 DMG 且签名可用公钥验证

### Requirement: CI 发布 appcast

tag 触发的构建 SHALL 在 Release 创建后自动生成 appcast 并提交回 main 分支（仓库根 `appcast.xml`）；Secret 缺失时 SHALL 明确报错并指路配置。main 分支构建 SHALL NOT 触碰 appcast。

#### Scenario: tag 发布提交 appcast
- **WHEN** push `v*` tag 且 Secret 已配置
- **THEN** main 分支多一条 appcast 提交，raw 地址返回含新版本的 XML

#### Scenario: main 构建不写 appcast
- **WHEN** push main（无 tag）
- **THEN** 不产生任何 appcast 提交

### Requirement: 种子 appcast

仓库根 SHALL 预置空 channel 的 `appcast.xml`，使 raw 地址在首个版本发布前即可访问（无条目）。

#### Scenario: 预置
- **WHEN** 本变更合入后访问 raw 地址
- **THEN** 返回合法 XML（channel 无 item）

### Requirement: 版本 3.0.13

Info.plist 版本（`CFBundleShortVersionString` 与 `CFBundleVersion`）SHALL 升至 3.0.13，并以 `v3.0.13` tag 发布。

#### Scenario: 版本号
- **WHEN** 检查 Info.plist
- **THEN** 两个版本键均为 3.0.13
