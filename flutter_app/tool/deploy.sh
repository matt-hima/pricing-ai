#!/usr/bin/env bash
# 檢查 → 乾淨建置 → 部署到 Firebase Hosting（站台 ai-invoicing）
# --pwa-strategy=none：不產生 service worker，部署後使用者不會卡在舊版程式碼
# 先刪 build/web：Flutter 不會清掉舊檔，殘留檔案會被一併部署
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tool/check_i18n.py
python3 tool/gen_seo.py
flutter test
rm -rf build/web
flutter build web --pwa-strategy=none
firebase deploy --only hosting:ai-invoicing --project task-exchange-f8f97
