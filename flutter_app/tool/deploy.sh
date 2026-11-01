#!/usr/bin/env bash
# 檢查 → 乾淨建置 → 組合整個網站（官網在 /、網頁版 App 在 /app/）→ 部署到 Firebase Hosting（站台 ai-invoicing）
#   tool/deploy.sh             # 全部
#   tool/deploy.sh --no-deploy # 只檢查與建置（build/site），不上傳
# --pwa-strategy=none：不產生 service worker，部署後使用者不會卡在舊版程式碼
# 先刪 build/web：Flutter 不會清掉舊檔，殘留檔案會被一併部署
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tool/check_i18n.py
flutter test
rm -rf build/web
flutter build web --release --base-href /app/ --pwa-strategy=none
bash tool/build_site.sh --no-app # 產生官網（tool/gen_landing.py）並和 build/web 組合成 build/site
if [ "${1:-}" != "--no-deploy" ]; then
  firebase deploy --only hosting:ai-invoicing --project task-exchange-f8f97
fi
