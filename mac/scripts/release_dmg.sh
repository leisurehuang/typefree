#!/bin/bash
# CI / 本地通用的 DMG 打包：对 Typefree.app 做 ad hoc 签名（内→外，与 build.sh 的
# Developer ID 重签同序，只是身份换成 "-"），再打出带 /Applications 软链的 UDZO DMG。
# 用法：release_dmg.sh <Typefree.app 路径> <输出 .dmg 路径>
set -euo pipefail

APP_PATH="${1:?用法: release_dmg.sh <Typefree.app> <output.dmg>}"
DMG_PATH="${2:?用法: release_dmg.sh <Typefree.app> <output.dmg>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENTITLEMENTS="$SCRIPT_DIR/../Resources/VoicePolish.entitlements"
VOLNAME="Typefree"

[ -d "$APP_PATH" ] || { echo "❌ app 不存在: $APP_PATH"; exit 1; }
[ -f "$ENTITLEMENTS" ] || { echo "❌ entitlements 不存在: $ENTITLEMENTS"; exit 1; }

# ad hoc 签名：hardened runtime 与正式发版一致；身份 "-" 即本机 ad hoc（无需证书）。
sign_adhoc() { codesign --force --options runtime --sign - "$1"; }

# 1) 嵌套组件由内到外（外层签名要覆盖内层组件哈希，顺序不能反）：
#    Sparkle XPC 服务 → Autoupdate → Updater.app → Sparkle.framework
SPARKLE_B="$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B"
if [ -d "$SPARKLE_B" ]; then
    for xpc in "$SPARKLE_B/XPCServices/"*.xpc; do
        [ -e "$xpc" ] && sign_adhoc "$xpc"
    done
    [ -e "$SPARKLE_B/Autoupdate" ]  && sign_adhoc "$SPARKLE_B/Autoupdate"
    [ -e "$SPARKLE_B/Updater.app" ] && sign_adhoc "$SPARKLE_B/Updater.app"
    sign_adhoc "$APP_PATH/Contents/Frameworks/Sparkle.framework"
fi

# 2) app 本体（带麦克风 entitlement），签名后校验
codesign --force --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign - "$APP_PATH"
# --deep 连嵌套的 Sparkle 组件一起校验（与 build.sh 的导出校验同款）
codesign --verify --deep --strict "$APP_PATH"
echo "✅ ad hoc 签名完成: $APP_PATH"

# 3) DMG：暂存区放 app 副本 + /Applications 软链（拖拽安装），UDZO 压缩
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP_PATH" "$STAGING/Typefree.app"
ln -s /Applications "$STAGING/Applications"

mkdir -p "$(dirname "$DMG_PATH")"
rm -f "$DMG_PATH"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
echo "✅ DMG 打包完成: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
