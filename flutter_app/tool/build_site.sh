#!/bin/bash
# サイト全体を build/site に組み立てる：トップ（ランディング）= `/`、Pricing AI アプリ = `/app/`。
#   tool/build_site.sh            # アプリをビルドして組み立てる
#   tool/build_site.sh --no-app   # 既にある build/web を使う（ランディングだけ直したとき）
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tool/gen_landing.py >/dev/null
if [ "${1:-}" != "--no-app" ]; then
  flutter build web --release --base-href /app/
fi
rm -rf build/site && mkdir -p build/site/app
cp -R build/web/. build/site/app/
# 古い言語別の紹介ページ（web/zh など）は、ランディング（landing/）に置き換わったのでアプリ側には入れない
for d in en es ja pt zh; do rm -rf "build/site/app/$d"; done
rm -f build/site/app/sitemap.xml build/site/app/robots.txt
cp -R landing/. build/site/
# 公開サイトの実行時スクリプトなど、ルート直下に置く必要があるもの（書き出したサイトが https://<ドメイン>/site-runtime.js を読み込む）
for f in site-runtime.js logo.svg favicon.png og-image.png manifest.json; do cp "web/$f" "build/site/$f"; done
cp -R web/builder build/site/builder
cp -R web/s build/site/s
cp -R web/icons build/site/icons
echo "built: build/site  (landing at /, app at /app/)"
