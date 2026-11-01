**English** · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Português](README.pt-BR.md) · [Español](README.es.md)

# Pricing AI

Pricing AI helps small service businesses and software studios set prices with confidence. It works out what each service really costs, builds a booking website, estimates software projects, and shows what similar Taiwan government contracts were awarded for. The AI runs on your own computer: your data is not sent to a cloud AI.

- Website: https://pricingai.minervaelectronics.com/
- Download for macOS: https://github.com/matt-hima/pricing-ai/releases/latest
- Browser version (no AI, no install): https://pricingai.minervaelectronics.com/app/

## Features

The app has four tabs.

### 1. Service pricing

For salons, clinics, restaurants, schools and rental spaces.

- Enter your hourly pay, fixed costs per month, booked hours, target profit, tax and rounding.
- For each service, enter its minutes and materials; the app shows the real cost, the price that reaches your margin, and the profit.
- A summary shows overhead per hour, the break-even number of hours and the monthly profit at your plan.
- 14 currencies with their usual tax and rounding. Export a CSV, or add the price list to your booking site in one click.
- Desktop app: the AI suggests services for your business, and "Market prices" searches the web for what similar businesses charge and turns the findings into a price list (only prices that appear in the search results are used).

### 2. Site builder

- Start from a clean template in English, Traditional Chinese, Japanese, Portuguese or Spanish, and edit visually.
- Add services and prices, a FAQ, flow charts and a dark high-tech look.
- Take bookings with a Google Form; one Apps Script creates the form and a calendar that shows busy times, and every booking becomes a calendar event.
- Export a ZIP for any web host.
- Desktop app: describe your business in a chat and the AI writes the page, rewrites parts on request and can draw banner pictures; publish to Firebase in one click.

### 3. Project estimate (software development)

- Enter your company, man-month rate and tax, the client and the quotation terms.
- Choose the project type, platforms (web, iOS, Android, …), design level and up to 17 feature modules, each with plain-language notes.
- Get a total price range (the upper bound includes a 1.2–1.5× risk buffer), a man-month breakdown by phase, the schedule and suggested maintenance fees.
- Live PDF quotation: preview, download, print, or send it to sales.
- Desktop app: the local AI splits each module into sub-tasks and estimates the hours; prices are always calculated by the app from your rate, never by the AI.
- "Past cases": opens Taiwan's Government e-Procurement System for similar awarded projects and summarizes prices and competition next to your quote (see below).

### 4. Case analysis (Taiwan government procurement)

Desktop app. The real Government e-Procurement System (web.pcc.gov.tw) opens in a browser inside the app; you browse it yourself and the app reads only the pages you open.

- Keyword expansion that follows the site's search rule: it matches the search text as one continuous phrase (spaces are ignored), so related wordings such as 網站 / 網頁 / 官網 are searched separately and merged.
- Award amounts: count, median, middle 50%, average, range and distribution, the agencies that buy most and the tender methods.
- Where your quote stands: the share of similar cases your price is above, and whether it is low, typical or high.
- Competition: open a few award notices to see how many vendors bid, how close awards are to the budget and who wins.
- Potential competitors: every bidder in the notices you opened; look up any company's awards and bids for the last 12 months (wins, bids, win rate, typical award, agencies).
- Google AI Mode opens in the in-app browser for public information about a company or a market, for you to read.
- Export the cases as CSV.

## Desktop app or browser?

| Feature | Desktop app | Browser |
|---|---|---|
| Service pricing calculator | ✓ | ✓ |
| Site builder and ZIP export | ✓ | ✓ |
| Project estimate from the built-in price table | ✓ | ✓ |
| AI estimates and writing your site by chat | ✓ | — |
| Government case analysis and AI summary of past cases | ✓ | — |
| Competitor records and Google AI Mode lookups | ✓ | — |
| One-click deploy to Firebase | ✓ | — |
| Your data stays on your computer | ✓ | ✓ |

The browser version, including a shortcut that Chrome offers to install ("Pricing AI Web"), is not the desktop app.

## Download and install (macOS)

1. Download `PricingAI-mac.dmg` from the [latest release](https://github.com/matt-hima/pricing-ai/releases/latest).
2. Open the .dmg and drag **Pricing AI** to **Applications**.
3. Start Pricing AI. This build is not yet signed with an Apple Developer ID, so the first time macOS may say it cannot verify the developer: open **System Settings → Privacy & Security** and click **Open Anyway** (only once).
4. The first AI task downloads the AI engine and a model once (0.5–5 GB). After that the AI runs on your computer.

The Windows version is coming soon.

### System requirements

| | |
|---|---|
| macOS | 10.15 or later; Apple silicon recommended (picture generation needs Apple silicon) |
| Windows | 10 or 11, 64-bit; a graphics card with Vulkan support recommended (NVIDIA, AMD or Intel) |
| Memory | 8 GB RAM or more; 16 GB for the larger AI models |
| Disk | About 1–6 GB free for the AI engine and model |
| Internet | To download the AI model once, and to look up procurement cases |

## Privacy

- Desktop app: the AI models run on your computer through llama.cpp (Metal on Mac, Vulkan on Windows). Your quotes, prices and sites are stored on your computer.
- Browser version: no AI; your data is stored in your browser.
- Network use: downloading the AI engine and models (GitHub, Hugging Face); the procurement site and Google, only in the in-app browser when you use case analysis; "Market prices" sends your search words to Bing.
- Estimates and prices are a planning aid, not advice and not a binding quotation.

## AI models

Models are downloaded only when you choose them and are not part of this repository or the installers. Each model has its own license.

| Model | Size | License |
|---|---|---|
| Qwen2.5 0.5B / 1.5B / 7B Instruct | 0.5 / 1.1 / 4.7 GB | Apache-2.0 |
| Llama 3.1 8B Instruct | 4.9 GB | Llama 3.1 Community License (Built with Llama) |
| Stable Diffusion 1.5 / 2.1 / SDXL (pictures) | 1.7–4.8 GB | CreativeML OpenRAIL-M / OpenRAIL++-M |

## Build from source

Requires [Flutter](https://flutter.dev) with Dart 3.12 or later; Xcode for macOS builds; Visual Studio on Windows for Windows builds.

```bash
cd flutter_app
flutter pub get
flutter test                      # unit and widget tests
flutter run -d macos              # desktop app with local AI
flutter build macos --release     # Pricing AI.app
flutter build web --base-href /app/
```

Integration test of the real Mac app (live procurement site and local AI):

```bash
cd flutter_app
LIVE_ENGINE_STORAGE=/path/to/pricing-ai caffeinate -d -i flutter test integration_test/case_analysis_app_test.dart -d macos
```

Website and tools:

| Command | What it does |
|---|---|
| `tool/deploy.sh` | Checks, tests, builds the web app under `/app/`, assembles the site and deploys it to Firebase Hosting (`--no-deploy` builds only) |
| `tool/build_site.sh` | Assembles `build/site`: landing page at `/`, web app at `/app/` |
| `python3 tool/gen_landing.py` | Generates the download-first landing page in 5 languages (installer links in `HOSTED_URLS`) |
| `python3 tool/gen_notices.py` | Regenerates the third-party notices and license texts |
| `python3 tool/check_i18n.py` | Checks that all 5 languages have the same strings |

## Repository layout

| Folder | What it is |
|---|---|
| `flutter_app/lib/` | App code: `service_pricing/`, `site/` (site builder), `estimator.dart` (project estimate), `case_analysis/` (procurement analysis), `engine/` (local AI engine), `i18n/` (5 languages), `ui/` |
| `flutter_app/assets/editor/` | The site editor (GrapesJS) that runs inside the app |
| `flutter_app/web/` | Web build files, PDF and browser-AI bridges, fonts |
| `flutter_app/landing/` | Generated landing pages |
| `flutter_app/test/`, `integration_test/` | Tests, with saved procurement pages as fixtures |
| `flutter_app/macos/`, `windows/` | Desktop projects |
| `site_builder/` | An earlier standalone version of the site builder |
| `css/`, `js/`, `index.html`, `logo/` | The original static quotation page |

## License

Pricing AI is licensed under the [Apache License 2.0](LICENSE). It uses third-party software under their own licenses, listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) with full texts in [THIRD_PARTY_LICENSES.txt](THIRD_PARTY_LICENSES.txt). All bundled libraries are BSD, MIT or Apache licensed, and the fonts use the SIL Open Font License.
