---
status: done
feature: ci-build-release
---

# CI 构建与发版（GitHub Actions）

## Why

仓库没有任何 CI：构建依赖作者本机的 Xcode 图形化签名（`build.sh` 的 `xcode_signing_ready` 在无证书团队的环境直接失败），发版全靠手工。上一轮 custom-model-provider 的新增 XCTest 用例也因本机无 Xcode 未真正跑过。需要一条 GitHub Actions 流水线：自动测试、构建、打 DMG，并在打 tag 时发布 GitHub Release。

## What Changes

- 新增 `.github/workflows/build-release.yml`：`macos-26` runner；push `main` / 打 `v*` tag / 手动触发；`swift test` → `xcodebuild`（`CODE_SIGNING_ALLOWED=NO` 绕开作者 team 自动签名）→ ad hoc 签名 + DMG → artifact；tag 触发时用 `gh release create` 发版（版本 = tag 名，`--generate-notes`）。
- 新增 `mac/scripts/release_dmg.sh`：ad hoc 签名（Sparkle 嵌套组件由内到外，与 `build.sh` Developer ID 重签同序）+ `hdiutil` 打 DMG（app + `/Applications` 软链）。
- 全部为新增文件，`mac/` 现有源码零改动；不配任何 secrets（无证书、无试用通道注入）。
- 不做：公证/Developer ID 正式签名、Info.plist 版本回写、appcast 更新、universal binary、自托管 runner。
