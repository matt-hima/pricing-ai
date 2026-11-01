[English](README.md) · **繁體中文** · [日本語](README.ja.md) · [Português](README.pt-BR.md) · [Español](README.es.md)

# Pricing AI

Pricing AI 協助小型服務業與軟體接案團隊有把握地定價：算出每項服務的真實成本、建立預約網站、估算軟體專案，並查出類似的政府標案實際以多少錢決標。AI 在你自己的電腦上執行，資料不會送到雲端 AI。

- 官網：https://pricingai.minervaelectronics.com/zh/
- 下載 macOS 版：https://github.com/matt-hima/pricing-ai/releases/latest
- 網頁版（沒有 AI、免安裝）：https://pricingai.minervaelectronics.com/app/?lang=zh

## 功能

App 有四個分頁。

### 1. 服務定價

適合美髮、診所、餐廳、教室與場地租借等服務業。

- 輸入時薪、每月固定成本、可預約時數、目標利潤、稅率與進位方式。
- 每項服務輸入所需分鐘與材料費，App 會算出真實成本、能達到利潤率的價格與利潤。
- 摘要顯示每小時分攤成本、損益兩平時數，以及依計畫估算的每月利潤。
- 支援 14 種幣別與各自常用的稅率與進位。可匯出 CSV，或一鍵把價目表加到預約網站。
- 桌面版：AI 依你的行業建議服務項目；「查行情」用網路搜尋同類店家的一般價格，再整理成價目表（只採用搜尋結果裡真的出現過的價格）。

### 2. 網站建置

- 從英文、繁體中文、日文、葡萄牙文或西班牙文的乾淨範本開始，可視覺化編輯。
- 加入服務與價格、常見問題、流程圖與科技感深色外觀。
- 用 Google 表單接收預約：一支 Apps Script 就能建立預約表單與顯示「忙碌」時段的日曆，每筆預約都會成為日曆事件。
- 匯出 ZIP，放到任何網站主機。
- 桌面版：用對話描述你的店，AI 就會寫出網頁、依需求重寫段落，還能繪製主圖；一鍵發布到 Firebase。

### 3. 專案估價（軟體開發）

- 輸入公司資料、人月單價與稅率、客戶與報價條件。
- 選擇專案類型、平台（網頁、iOS、Android……）、設計等級，以及最多 17 個功能模組，每個模組都可以用白話補充說明。
- 得到總價範圍（上限含 1.2–1.5 倍風險緩衝）、各階段人月拆解、預估時程與建議維護費用。
- 即時 PDF 報價單：預覽、下載、列印，或送給業務評估。
- 桌面版：本機 AI 把每個模組拆成子任務並估算工時；價格一律由 App 依你的單價計算，不由 AI 決定。
- 「查歷史案件」：打開政府電子採購網查類似的決標案件，並在你的報價旁摘要行情與競爭狀況（見下方）。

### 4. 案件分析（政府採購）

桌面版功能。真正的政府電子採購網（web.pcc.gov.tw）會在 App 內的瀏覽器開啟，由你自己瀏覽，App 只讀取你打開的頁面。

- 依採購網的查詢規則擴充關鍵字：採購網把查詢字當成一整串連續文字比對（空白會被忽略），所以 網站／網頁／官網 等寫法會分開查詢再合併。
- 決標金額：件數、中位數、中間 50%、平均、範圍與分布，以及常見採購機關與招標方式。
- 你的報價在哪裡：你的價格高於多少比例的同類案件，屬於低價區、一般行情或高價區。
- 競爭狀況：點開幾件決標公告，就能看到投標家數、決標金額占預算的比例與得標廠商。
- 潛在競爭對手：列出你點開的公告裡所有投標廠商；可查任一家廠商近 12 個月的得標與投標紀錄（得標件數、投標件數、得標率、一般得標金額、常往來機關）。
- Google AI 模式會在 App 內的瀏覽器開啟，查詢公司或市場的公開資訊，給你自己閱讀。
- 案件可匯出成 CSV。
- 官方開放資料：下載政府電子採購網的決標資料集（決標 100 萬元以上、約晚 2 個月），一次分析好幾年、不會遇到驗證碼：決標金額、常見得標廠商、機關與決標方式。資料來源：行政院公共工程委員會 政府電子採購網開放資料（政府資料開放授權條款－第1版）。

## 桌面 App 還是網頁版？

| 功能 | 桌面 App | 網頁版 |
|---|---|---|
| 服務定價計算 | ✓ | ✓ |
| 網站編輯與 ZIP 匯出 | ✓ | ✓ |
| 依內建價目表的專案估價 | ✓ | ✓ |
| AI 估價、用對話寫網站 | ✓ | — |
| 政府標案分析與歷史案件 AI 摘要 | ✓ | — |
| 競爭對手紀錄與 Google AI 模式查詢 | ✓ | — |
| 一鍵部署到 Firebase | ✓ | — |
| 資料留在你的電腦 | ✓ | ✓ |

網頁版（包括 Chrome 提示「安裝」的捷徑「Pricing AI Web」）不是桌面 App。

## 下載與安裝（macOS）

1. 從[最新版本](https://github.com/matt-hima/pricing-ai/releases/latest)下載 `PricingAI-mac.dmg`。
2. 打開 .dmg，把 **Pricing AI** 拖到「**應用程式**」。
3. 啟動 Pricing AI。這個版本還沒有 Apple Developer ID 簽章，第一次打開時 macOS 可能會說無法驗證開發者：請到「**系統設定 → 隱私權與安全性**」按「**仍要打開**」（只需一次）。
4. 第一次使用 AI 時會下載一次 AI 引擎與模型（0.5–5 GB），之後 AI 就在你的電腦上執行。

從 0.2.0 版起 App 會自動更新：啟動時與每天檢查一次新版，右欄「評估方式」裡也有「檢查更新」。0.1.0 版沒有更新功能，請手動安裝一次 0.2.0。

Windows 版即將推出。

### 系統需求

| | |
|---|---|
| macOS | 10.15 以上；建議 Apple 晶片（繪製圖片需要 Apple 晶片） |
| Windows | 10 或 11，64 位元；建議有支援 Vulkan 的顯示卡（NVIDIA、AMD 或 Intel） |
| 記憶體 | 8 GB 以上；較大的 AI 模型建議 16 GB |
| 硬碟 | AI 引擎與模型約需 1–6 GB 空間 |
| 網路 | 第一次下載 AI 模型，以及查詢採購案件時需要 |

## 隱私

- 桌面版：AI 模型透過 llama.cpp 在你的電腦上執行（Mac 用 Metal，Windows 用 Vulkan）。報價、價格與網站都存在你的電腦。
- 網頁版：沒有 AI；資料存在你的瀏覽器。
- 會連網的情況：下載 AI 引擎與模型（GitHub、Hugging Face）；使用案件分析時，在 App 內的瀏覽器開啟採購網與 Google；「查行情」會把搜尋關鍵字送到 Bing。
- 估價與價格僅供規劃參考，不構成建議，也不是有約束力的報價。

## AI 模型

模型只在你選用時才下載，不包含在這個 repo 或安裝檔裡。每個模型有各自的授權。

| 模型 | 大小 | 授權 |
|---|---|---|
| Qwen2.5 0.5B / 1.5B / 7B Instruct | 0.5 / 1.1 / 4.7 GB | Apache-2.0 |
| Llama 3.1 8B Instruct | 4.9 GB | Llama 3.1 Community License（Built with Llama） |
| Stable Diffusion 1.5 / 2.1 / SDXL（繪圖） | 1.7–4.8 GB | CreativeML OpenRAIL-M / OpenRAIL++-M |

## 從原始碼建置

需要 [Flutter](https://flutter.dev)（Dart 3.12 以上）；建置 macOS 版需要 Xcode；建置 Windows 版需要在 Windows 上安裝 Visual Studio。

```bash
cd flutter_app
flutter pub get
flutter test                      # 單元與元件測試
flutter run -d macos              # 有本機 AI 的桌面版
flutter build macos --release     # Pricing AI.app
flutter build web --base-href /app/
```

真正的 Mac App 整合測試（實際連到採購網，並使用本機 AI）：

```bash
cd flutter_app
LIVE_ENGINE_STORAGE=/path/to/pricing-ai caffeinate -d -i flutter test integration_test/case_analysis_app_test.dart -d macos
```

網站與工具：

| 指令 | 用途 |
|---|---|
| `tool/deploy.sh` | 檢查、測試、以 `/app/` 建置網頁版、組合網站並部署到 Firebase Hosting（`--no-deploy` 只建置） |
| `tool/build_site.sh` | 組合 `build/site`：官網在 `/`，網頁版在 `/app/` |
| `python3 tool/gen_landing.py` | 產生 5 種語言、以下載為主的官網（安裝檔連結在 `HOSTED_URLS`） |
| `tool/release_mac.sh` | 建置 Mac 發佈檔到 `dist/`：DMG、自動更新用的 Sparkle 簽章 `appcast.xml`、release notes 的 SHA-256（步驟寫在腳本開頭） |
| `python3 tool/gen_notices.py` | 重新產生第三方授權聲明與全文 |
| `python3 tool/check_i18n.py` | 檢查 5 種語言的字串是否一致 |

## Repo 結構

| 資料夾 | 內容 |
|---|---|
| `flutter_app/lib/` | App 程式：`service_pricing/`、`site/`（網站建置）、`estimator.dart`（專案估價）、`case_analysis/`（採購分析）、`engine/`（本機 AI 引擎）、`i18n/`（5 種語言）、`ui/` |
| `flutter_app/assets/editor/` | 在 App 內執行的網站編輯器（GrapesJS） |
| `flutter_app/web/` | 網頁版檔案、PDF 與瀏覽器 AI 的橋接程式、字型 |
| `flutter_app/landing/` | 產生出來的官網頁面 |
| `flutter_app/test/`、`integration_test/` | 測試（含存下來的採購網頁面作為測試資料） |
| `flutter_app/macos/`、`windows/` | 桌面版專案 |
| `site_builder/` | 較早的獨立版網站建置器 |
| `css/`、`js/`、`index.html`、`logo/` | 最初的靜態報價頁 |

## 授權

Pricing AI 採用 [Apache License 2.0](LICENSE) 授權。使用的第三方軟體各有其授權，清單見 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)，全文見 [THIRD_PARTY_LICENSES.txt](THIRD_PARTY_LICENSES.txt)。所有打包的程式庫皆為 BSD、MIT 或 Apache 授權，字型採用 SIL Open Font License。
