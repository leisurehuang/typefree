# Tasks · ci-build-release

## 1. 脚本

- [x] 1.1 新增 `mac/scripts/release_dmg.sh`：ad hoc 签名（内→外 + entitlements + verify）与 DMG 打包（app + /Applications、UDZO），`chmod +x`
- [x] 1.2 脚本静态检查：`bash -n` + `shellcheck` + `actionlint` 零告警

## 2. 工作流

- [x] 2.1 新增 `.github/workflows/build-release.yml`：三触发、permissions、concurrency、macos-26、60min 超时
- [x] 2.2 步骤实现：工具链打印 → swift test → xcodebuild（CODE_SIGNING_ALLOWED=NO）→ 版本号推导 → release_dmg.sh → upload-artifact
- [x] 2.3 tag 分流：`refs/tags/v*` 时 `gh release create --verify-tag --generate-notes` 附 DMG
- [x] 2.4 YAML 语法校验（python yaml 解析通过）

## 3. 验证

- [x] 3.1 spec 一致性核对：delta spec 的每个 Scenario 在 workflow/脚本里有对应实现
- [x] 3.2 独立代码评审（spec vs 实现）
- [x] 3.3 终检：diff 仅含两个新文件 + openspec/；`openspec validate --strict` 通过
