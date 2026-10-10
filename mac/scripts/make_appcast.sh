#!/bin/bash
# 生成/更新 Sparkle appcast：对 DMG 整文件做 Ed25519 签名（appcast_sign.swift；签名输出与
# Sparkle 的 edSignature 逐字节一致——两者都是 RFC 8032 对文件整字节的确定性签名），把新条目
# 前插进 appcast.xml。密钥格式注意：SPARKLE_PRIVATE_KEY 为 64B（seed||pub）base64；
# Sparkle 官方 sign_update/generate_appcast 吃 32B seed——即本格式的 base64 前 44 个字符。
# 用法：SPARKLE_PRIVATE_KEY=<base64> make_appcast.sh <dmg> <version> <notes-file> <download-url> <appcast.xml>
set -euo pipefail

DMG="${1:?用法: make_appcast.sh <dmg> <version> <notes-file> <download-url> <appcast.xml>}"
VERSION="${2#v}"   # 防御性去掉 v 前缀：appcast 版本必须与 Info.plist CFBundleVersion 同格式
VERSION="${VERSION:?缺少 version}"
NOTES_FILE="${3:?缺少 notes-file}"
DOWNLOAD_URL="${4:?缺少 download-url}"
APPCAST_OUT="${5:?缺少 appcast.xml 输出路径}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

[ -f "$DMG" ] || { echo "❌ DMG 不存在: $DMG"; exit 1; }
[ -f "$NOTES_FILE" ] || { echo "❌ 说明文件不存在: $NOTES_FILE"; exit 1; }
[ -n "${SPARKLE_PRIVATE_KEY:-}" ] || { echo "❌ 缺少 SPARKLE_PRIVATE_KEY（64B seed||pub 的 base64）；本地跑请 export，CI 请在仓库 Secrets 配置"; exit 1; }

DMG_DIR="$(cd "$(dirname "$DMG")" && pwd)"
DMG_NAME="$(basename "$DMG")"
# LC_ALL=C：星期/月份缩写必须是英文，AppcastParser 的 en_US_POSIX 格式器才认
PUBDATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"
LENGTH=$(wc -c < "$DMG" | tr -d ' ')

SIG="$(cd "$DMG_DIR" && DMG_PATH="$DMG_NAME" SPARKLE_PRIVATE_KEY="$SPARKLE_PRIVATE_KEY" \
    swift "$SCRIPT_DIR/appcast_sign.swift")"
[ -n "$SIG" ] || { echo "❌ 签名为空"; exit 1; }

# 说明进 CDATA；正文里的 ]]> 拆开防提前闭合
NOTES="$(sed 's/]]>/]]]]><![CDATA[>/g' "$NOTES_FILE")"

# printf %s 组装：说明文本按字面量嵌入，不做命令替换
ITEM_XML="$(printf '        <item>
            <title>版本 %s</title>
            <pubDate>%s</pubDate>
            <sparkle:version>%s</sparkle:version>
            <sparkle:shortVersionString>%s</sparkle:shortVersionString>
            <description><![CDATA[%s]]></description>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure url="%s" sparkle:edSignature="%s" length="%s" type="application/octet-stream"/>
        </item>' "$VERSION" "$PUBDATE" "$VERSION" "$VERSION" "$NOTES" "$DOWNLOAD_URL" "$SIG" "$LENGTH")"

if [ ! -f "$APPCAST_OUT" ]; then
    cat > "$APPCAST_OUT" <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Typefree</title>
        <link>https://github.com/leisurehuang/typefree</link>
        <description>Typefree fork 更新</description>
$ITEM_XML
    </channel>
</rss>
EOF
else
    # 已有 appcast：新条目前插到 <channel> 内最前（保留历史条目）
    python3 - "$APPCAST_OUT" "$ITEM_XML" <<'EOF'
import sys
path, item = sys.argv[1], sys.argv[2]
s = open(path).read()
anchor = "<channel>"
i = s.index(anchor) + len(anchor)
open(path, "w").write(s[:i] + "\n" + item + s[i:])
EOF
fi

echo "[ok] appcast updated: $APPCAST_OUT (version $VERSION, ${LENGTH} bytes, pubDate $PUBDATE)"
