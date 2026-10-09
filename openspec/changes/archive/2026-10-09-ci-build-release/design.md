# Design · ci-build-release

Gate 2（2026-10-08 确认）技术方案存档。

## 改动面（全部新增）

- `.github/workflows/build-release.yml`
  - 触发：`push: branches [main], tags ['v*']` + `workflow_dispatch`
  - `permissions: contents: write`；`concurrency: group build-${{ github.ref }}`，`cancel-in-progress: false`
  - `runs-on: macos-26`（默认 Xcode 26.2），`timeout-minutes: 60`
  - 步骤：checkout → 打印工具链版本 → `swift test`（`mac/VoicePolishCore`）→ `xcodebuild` Release（`ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO`，derivedData 在 `mac/.build-ci`）→ 版本号推导写入 `GITHUB_ENV`（tag → `GITHUB_REF_NAME`，其余 → `ci-<GITHUB_SHA 前 7 位>`）→ `release_dmg.sh` → `upload-artifact` → tag 时 `gh release create --verify-tag --generate-notes`（`GH_TOKEN: github.token`）
- `mac/scripts/release_dmg.sh`（可执行）
  - ad hoc 签名（`--force --options runtime --sign -`），顺序与 `build.sh` 的 Developer ID 重签一致：XPCServices → Autoupdate → Updater.app → Sparkle.framework → app（带 `Resources/VoicePolish.entitlements`），最后 `codesign --verify --strict`
  - DMG：`mktemp -d` 暂存（trap 清理）→ `cp -R` app + `ln -s /Applications` → `hdiutil create -volname Typefree -format UDZO`

## 关键决策

- **`CODE_SIGNING_ALLOWED=NO`**：工程 Release 配置写死了作者 team（NHC4C4K7X7）的 Automatic 签名，CI 无证书必失败；先无签名构建、后由脚本 ad hoc 补签是标准解法，且不改工程文件。
- **签名顺序内→外**：macOS codesign 要求外层签名包含内层组件哈希，Sparkle 的 XPC 服务必须先签；照抄 `build.sh` 既有顺序，避免分叉。
- **`gh` CLI 而非第三方 action**：runner 预装 gh，`GITHUB_TOKEN` 即可用，少一个第三方依赖。
- **版本号不回写 Info.plist**：Release 版本 = tag；App 内版本仍由仓库源码管理（当前 3.0.9），两者解耦（Gate 1 确认）。

## 风险与回退

- runner 默认 Xcode 26.2 vs README 的 26.3：项目 Swift 5 / deployment 14，兼容概率高；若编译失败，在 workflow 加 `sudo xcode-select -s` 选镜像内更新的 side-by-side Xcode（单点改动）。
- Sparkle 经 SPM 远程解析：GitHub hosted runner 网络可用，无风险。
- 首次真实验证只能发生在 push 之后（本机无 runner/无 Xcode）；脚本静态检查 + 评审兜底。

## 项目规则

无 `CLAUDE.md`；bash 与 `build.sh` 同风格（`set -euo pipefail`、中文注释）；零 secrets 依赖。
