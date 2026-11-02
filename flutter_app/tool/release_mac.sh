#!/usr/bin/env bash
# macOS 發佈：檢查 → 建置 → DMG → Sparkle 簽章 → appcast，全部輸出到 dist/
#   1. pubspec.yaml 的 version 改成新版（例如 0.2.0+2）：名稱給人看，組建號（+ 後面）每次發佈都要加一，Sparkle 用它比較新舊
#   2. 寫好 dist/release-notes-<名稱>.md（SHA-256 那行由本腳本填）
#   3. tool/release_mac.sh
#   4. gh release create v<名稱> dist/PricingAI-mac.dmg dist/appcast.xml --title "Pricing AI <名稱>" --notes-file dist/release-notes-<名稱>.md
# 已安裝的 App 讀 releases/latest/download/appcast.xml，發佈後就會收到更新。
# 簽章私鑰在登入鑰匙圈的 pricing-ai 帳號（Sparkle 的 generate_keys --account pricing-ai 產生，公鑰在 macos/Runner/Info.plist 的 SUPublicEDKey）；
# 換電腦時用 macos/Pods/Sparkle/bin/generate_keys --account pricing-ai -x / -f 匯出、匯入。私鑰遺失後舊版 App 就無法再自動更新。
set -euo pipefail
cd "$(dirname "$0")/.."

ver=$(sed -n 's/^version: *//p' pubspec.yaml)
name=${ver%+*}
build=${ver#*+}
[ "$name" != "$ver" ] || { echo "pubspec.yaml 的 version 需要組建號，例如 $ver+1" >&2; exit 1; }
notes=dist/release-notes-$name.md
[ -f "$notes" ] || { echo "先寫好 $notes" >&2; exit 1; }

# 組建號必須大於目前已發佈的版本，否則已安裝的 App 不會更新
published=$(curl -sfL https://github.com/matt-hima/pricing-ai/releases/latest/download/appcast.xml | sed -n 's:.*<sparkle\:version>\(.*\)</sparkle\:version>.*:\1:p' || true)
if [ -n "$published" ] && [ "$build" -le "$published" ]; then
  echo "組建號 $build 不大於已發佈的 $published：請把 pubspec.yaml 的 +$build 加大" >&2
  exit 1
fi

python3 tool/check_i18n.py
flutter test
flutter build macos --release
app="build/macos/Build/Products/Release/Pricing AI.app"
built=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")
[ "$built" = "$build" ] || { echo "建置出的組建號 $built 與 pubspec.yaml 的 $build 不符" >&2; exit 1; }

# DMG：App 加上 /Applications 捷徑，讓使用者拖曳安裝
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Pricing AI.app"
ln -s /Applications "$stage/Applications"
mkdir -p dist
dmg=dist/PricingAI-$name-mac.dmg
hdiutil create -volname "Pricing AI" -srcfolder "$stage" -format UDZO -ov "$dmg" >/dev/null
cp "$dmg" dist/PricingAI-mac.dmg

# Sparkle 的 EdDSA 簽章（App 沒有 Apple 簽章，更新完全靠這個驗證）
sig=$(macos/Pods/Sparkle/bin/sign_update --account pricing-ai -p dist/PricingAI-mac.dmg)
python3 tool/gen_appcast.py dist/PricingAI-mac.dmg "$name" "$build" "$notes" "$sig" >/dev/null

sha=$(shasum -a 256 dist/PricingAI-mac.dmg | cut -d' ' -f1)
if grep -q '^SHA-256:' "$notes"; then
  sed -i '' "s/^SHA-256:.*/SHA-256: \`$sha\`/" "$notes"
else
  printf '\nSHA-256: `%s`\n' "$sha" >>"$notes"
fi

echo "dist/PricingAI-mac.dmg  dist/appcast.xml  $notes"
echo "gh release create v$name dist/PricingAI-mac.dmg dist/appcast.xml --title \"Pricing AI $name\" --notes-file $notes"
