# Tasks · fork-update-channel

## 1. 密钥与配置

- [x] 1.1 本机生成 Ed25519 密钥对（32B/64B raw base64），公钥留档、私钥交付用户保存
- [x] 1.2 Info.plist：SUFeedURL / SUPublicEDKey / 版本 3.0.13×2
- [x] 1.3 AppDelegate `AppLinks.appcastURL` → raw 地址

## 2. 脚本与种子

- [x] 2.1 `make_appcast.sh`：CryptoKit 签名 + 条目生成/前插（先写验证：签名 verify、AppcastParser 解析）
- [x] 2.2 种子 `appcast.xml`（空 channel）落仓库根
- [x] 2.3 shellcheck 零告警

## 3. CI

- [x] 3.1 workflow tag-only「Publish appcast」步骤（make_appcast + gh api contents 提交）
- [x] 3.2 actionlint / YAML 校验；Secret 缺失时报错文案明确

## 4. 验证

- [x] 4.1 本机门禁：swift build + UI typecheck + 签名/appcast 本地验证脚本全绿
- [x] 4.2 独立评审（spec vs 实现）
- [ ] 4.3 用户配置 Secret 后：提交推送 + tag v3.0.13，CI 全绿 + appcast 回写 main + raw 可访问
