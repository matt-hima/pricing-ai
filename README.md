# Pricing AI

Price your services, build your booking site, estimate software projects and analyze Taiwan government procurement cases, with AI that runs on your own computer.

- Website: https://pricingai.minervaelectronics.com/
- Download for macOS: https://github.com/matt-hima/pricing-ai-releases/releases/latest
- Browser version (no AI): https://pricingai.minervaelectronics.com/app/

## What is in this repository

| Folder | What it is |
|---|---|
| `flutter_app/` | The Pricing AI app (Flutter): macOS, Windows and web builds, the landing page generator and the deploy scripts |
| `site_builder/` | An earlier standalone version of the site builder |
| `css/`, `js/`, `index.html`, `logo/` | The original static quotation page |

## Build

Requires Flutter (Dart 3.12 or later). For macOS builds, Xcode; for Windows builds, Visual Studio on Windows.

```bash
cd flutter_app
flutter pub get
flutter test
flutter run -d macos              # desktop app with local AI
flutter build web --base-href /app/
```

`tool/deploy.sh` checks, builds and deploys the website (landing page at `/`, web app at `/app/`) to Firebase Hosting.

## License

Pricing AI is licensed under the [Apache License 2.0](LICENSE). It uses third-party software under their own licenses, listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) with full texts in [THIRD_PARTY_LICENSES.txt](THIRD_PARTY_LICENSES.txt) (regenerate with `python3 flutter_app/tool/gen_notices.py`).

AI models are not part of this repository or the installers: the desktop app downloads them from Hugging Face when you choose one, and each model has its own license (Qwen2.5: Apache-2.0; Llama 3.1: Llama 3.1 Community License, Built with Llama; Stable Diffusion: CreativeML OpenRAIL).
