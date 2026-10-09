## ADDED Requirements

### Requirement: CI 触发与权限

工作流 SHALL 在 push 到 `main`、push `v*` tag、手动触发（workflow_dispatch）三种情况下运行；SHALL 声明 `contents: write` 权限（发 Release 所需）；SHALL 按 ref 分组做 concurrency 去重。

#### Scenario: 三种触发
- **WHEN** push 到 `main`、push `v*` tag、或在 Actions 页手动触发
- **THEN** 工作流均启动并完成测试→构建→打包

### Requirement: 构建前跑核心测试

工作流 SHALL 先在 `mac/VoicePolishCore` 执行 `swift test`；测试失败 SHALL 阻断后续构建步骤。

#### Scenario: 测试失败阻断构建
- **WHEN** 任一 XCTest 用例失败
- **THEN** 工作流以失败结束，不产出 DMG、不发 Release

### Requirement: 无证书构建

工作流 SHALL 在 GitHub 托管 `macos-26` runner 上以 `CODE_SIGNING_ALLOWED=NO` 执行 `xcodebuild`（scheme `VoicePolish`、configuration `Release`、`arm64`），绕开工程内写死的作者签名团队；不依赖任何证书类 secrets。

#### Scenario: 无证书环境构建成功
- **WHEN** runner 无任何签名证书
- **THEN** `xcodebuild` 构建产出 `Typefree.app`（未签名）

### Requirement: ad hoc 签名

打包脚本 SHALL 对 app 做 ad hoc 签名（`codesign --sign -` + entitlements），顺序由内到外：Sparkle XPCServices → Autoupdate → Updater.app → Sparkle.framework → app 本体；完成后 SHALL 通过 `codesign --verify --strict`。

#### Scenario: 签名与校验
- **WHEN** 打包脚本运行
- **THEN** 所有嵌套组件与 app 本体被 ad hoc 签名，`codesign --verify` 通过

### Requirement: DMG 打包

打包脚本 SHALL 产出 DMG：卷名 `Typefree`，内含 `Typefree.app` 与 `/Applications` 软链（拖拽安装），`UDZO` 压缩；文件名带版本（tag 触发为 tag 名，其余为 `ci-<短sha>`）。

#### Scenario: DMG 内容
- **WHEN** DMG 打包完成
- **THEN** 挂载后可见 `Typefree.app` 与 `Applications` 快捷方式

### Requirement: 产物分流

非 tag 触发 SHALL 仅上传 workflow artifact（DMG）；`v*` tag 触发 SHALL 额外创建 GitHub Release：标题与 tag 同名、正文用 `--generate-notes` 自动生成、DMG 作为附件。

#### Scenario: push main 不发版
- **WHEN** push 到 `main`
- **THEN** 仅上传 artifact，不创建 Release

#### Scenario: tag 发版
- **WHEN** push `v3.0.10` tag
- **THEN** 创建名为 `v3.0.10` 的 Release，附件含 `Typefree-v3.0.10-*.dmg`，正文为自动生成的 notes

### Requirement: 现有源码零改动

本变更 SHALL NOT 修改 `mac/` 下任何现有文件；所有逻辑位于新 workflow 与新脚本内。

#### Scenario: 增量变更
- **WHEN** 检视本变更的 diff
- **THEN** 除 `openspec/` 外仅新增 `.github/workflows/build-release.yml` 与 `mac/scripts/release_dmg.sh`
