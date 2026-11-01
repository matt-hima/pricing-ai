#!/usr/bin/env python3
"""第三方授權聲明：產生 repo 根目錄的 NOTICE、THIRD_PARTY_NOTICES.md（清單）與 THIRD_PARTY_LICENSES.txt（全文）。
- Dart 套件：從 `dart pub deps --json` 走 pubspec 的正式相依（不含 dev），授權全文取自本機的套件快取
- 打包或從 CDN 載入的 JavaScript、字型、執行時下載的引擎：授權全文取自官方套件 / repo 的固定版本
- 執行時下載的 AI 模型：不隨 App 散布，只列出授權與連結（使用者下載時適用各模型的授權）
改了相依套件或版本後重跑：python3 tool/gen_notices.py"""
import glob, json, os, re, subprocess, sys

APP = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
REPO = os.path.join(APP, "..")

# 打包在 App / 網站裡，或從 CDN 載入的程式庫（名稱, 版本, 授權, 用途, 授權全文網址）
BUNDLED = [
    ("GrapesJS", "0.21.13", "BSD-3-Clause", "Site builder editor (bundled in assets/editor/vendor)", "https://unpkg.com/grapesjs@0.21.13/LICENSE"),
    ("grapesjs-blocks-basic", "1.0.2", "BSD-3-Clause", "Site builder blocks (bundled)", "https://unpkg.com/grapesjs-blocks-basic@1.0.2/LICENSE"),
    ("Mermaid", "11.4.0", "MIT", "Flow charts in the site builder (bundled)", "https://unpkg.com/mermaid@11.4.0/LICENSE"),
    ("pdfmake", "0.3.11", "MIT", "PDF quotation (bundled in web/vendor; includes PDFKit and fontkit)", "https://unpkg.com/pdfmake@0.3.11/LICENSE"),
    ("PDF.js", "3.11.174", "Apache-2.0", "PDF preview (bundled in web/vendor)", "https://unpkg.com/pdfjs-dist@3.11.174/LICENSE"),
    ("WebLLM", "0.2.80", "Apache-2.0", "Browser AI on WebGPU (loaded from jsDelivr)", "https://unpkg.com/@mlc-ai/web-llm@0.2.80/LICENSE"),
    ("wllama", "3.8.1", "MIT", "Browser AI on WebAssembly (loaded from jsDelivr)", "https://unpkg.com/@wllama/wllama@3.8.1/LICENCE"),
    ("JSZip", "3.10.1", "MIT (dual MIT / GPL-3.0, used under MIT)", "ZIP export of sites (loaded from cdnjs)", "https://unpkg.com/jszip@3.10.1/LICENSE.markdown"),
    ("Noto Sans CJK (TC / JP)", "165c01b", "OFL-1.1", "Fonts for the PDF and site (web/fonts and jsDelivr)", "https://raw.githubusercontent.com/notofonts/noto-cjk/165c01b46ea533872e002e0785ff17e44f6d97d8/LICENSE"),
    ("Source Sans 3", "7c691c2", "OFL-1.1", "Latin font for the PDF and site (web/fonts and jsDelivr)", "https://raw.githubusercontent.com/adobe-fonts/source-sans/7c691c2772570a0d3a9e1bffe8a9d6074257d985/LICENSE.md"),
    ("Font Awesome", "4.7.0", "OFL-1.1 (font) / MIT (CSS)", "Icons in site templates (loaded from cdnjs)", "https://unpkg.com/font-awesome@4.7.0/README.md"),
]

# 桌面版在第一次使用 AI 時下載的引擎（不包含在安裝檔裡）
ENGINES = [
    ("llama.cpp (llama-server)", "b11878", "MIT", "Local text AI engine, downloaded from GitHub on first use", "https://raw.githubusercontent.com/ggml-org/llama.cpp/b11878/LICENSE"),
    ("stable-diffusion.cpp", "master-1015-e41fbcf", "MIT", "Local picture engine, downloaded from GitHub on first use", "https://raw.githubusercontent.com/leejet/stable-diffusion.cpp/master/LICENSE"),
]

# AI 模型：使用者選用時才從 Hugging Face 下載，不隨 App 散布；使用時適用各自的授權
MODELS = [
    ("Qwen2.5 0.5B / 1.5B / 7B Instruct", "Apache-2.0", "https://huggingface.co/Qwen/Qwen2.5-7B-Instruct/blob/main/LICENSE"),
    ("Llama 3.1 8B Instruct", "Llama 3.1 Community License (Built with Llama)", "https://www.llama.com/llama3_1/license/"),
    ("Stable Diffusion 1.5", "CreativeML OpenRAIL-M", "https://huggingface.co/spaces/CompVis/stable-diffusion-license"),
    ("Stable Diffusion 2.1 / SDXL base 1.0", "CreativeML OpenRAIL++-M", "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md"),
]


def fetch(url):
    # 用 curl（系統憑證）：python.org 版 Python 常沒有裝 CA 憑證
    return subprocess.run(["curl", "-sfL", "--max-time", "30", url], capture_output=True, check=True).stdout.decode("utf-8", "replace")


def classify(text):
    t = text[:4000]
    if "Apache License" in t: return "Apache-2.0"
    if "Permission is hereby granted, free of charge" in t: return "MIT"
    if "Redistribution and use in source and binary forms" in t:
        return "BSD-3-Clause" if re.search(r"Neither the name|names of its contributors|name of the copyright holder", t) else "BSD-2-Clause"
    return "see text"


def dart_packages():
    deps = json.loads(subprocess.run(["dart", "pub", "deps", "--json"], cwd=APP, capture_output=True, text=True, check=True).stdout)
    pk = {p["name"]: p for p in deps["packages"]}
    seen, stack = set(), list(pk[deps["root"]]["directDependencies"])  # 只走正式相依，不含 dev_dependencies
    while stack:
        n = stack.pop()
        if n in seen or n not in pk: continue
        seen.add(n)
        stack += pk[n].get("dependencies", [])
    cfg = json.load(open(os.path.join(APP, ".dart_tool/package_config.json")))
    roots = {p["name"]: p["rootUri"] for p in cfg["packages"]}
    out = []
    for n in sorted(seen):
        u = roots.get(n, "")
        d = u[7:] if u.startswith("file://") else os.path.normpath(os.path.join(APP, ".dart_tool", u))
        files = sorted(glob.glob(d + "/LICENSE*") + glob.glob(d + "/COPYING*"))
        if not files and pk[n].get("source") == "sdk":  # Flutter SDK 內的套件沒有各自的授權檔：用 Flutter 的授權
            r = roots.get("flutter", "")
            files = glob.glob((r[7:] if r.startswith("file://") else r) + "/LICENSE")
        if not files:
            sys.exit(f"no license file for Dart package {n}")
        text = open(files[0], encoding="utf-8", errors="replace").read().strip()
        out.append((n, pk[n]["version"], "BSD-3-Clause (Flutter SDK)" if pk[n].get("source") == "sdk" else classify(text), text))
    return out


def main():
    dart = dart_packages()
    remote = [(n, v, l, use, fetch(url).strip(), url) for n, v, l, use, url in BUNDLED + ENGINES]

    md = ["# Third-party notices", "",
          "Pricing AI is licensed under the Apache License 2.0 (see [LICENSE](LICENSE)). It uses the third-party software below;",
          "the full license texts are in [THIRD_PARTY_LICENSES.txt](THIRD_PARTY_LICENSES.txt). Generated by `flutter_app/tool/gen_notices.py`.", "",
          "## Bundled or loaded by the app", "", "| Library | Version | License | Used for |", "|---|---|---|---|"]
    md += [f"| {n} | {v} | {l} | {use} |" for n, v, l, use, _, _ in remote[:len(BUNDLED)]]
    md += ["", "## Downloaded on first use (desktop app)", "", "| Engine | Version | License | Used for |", "|---|---|---|---|"]
    md += [f"| {n} | {v} | {l} | {use} |" for n, v, l, use, _, _ in remote[len(BUNDLED):]]
    md += ["", "## AI models (not distributed with the app)", "",
           "Models are downloaded from Hugging Face only when you choose them, and your use of each model is subject to its own license.",
           "Llama 3.1 is licensed under the Llama 3.1 Community License, Copyright © Meta Platforms, Inc. All Rights Reserved. Built with Llama.", "",
           "| Model | License |", "|---|---|"]
    md += [f"| {n} | [{l}]({u}) |" for n, l, u in MODELS]
    md += ["", f"## Dart and Flutter packages ({len(dart)})", "", "| Package | Version | License |", "|---|---|---|"]
    md += [f"| {n} | {v} | {l} |" for n, v, l, _ in dart]
    open(os.path.join(REPO, "THIRD_PARTY_NOTICES.md"), "w", encoding="utf-8").write("\n".join(md) + "\n")

    sep = "\n\n" + "=" * 78 + "\n"
    parts = ["Full license texts of the third-party software used by Pricing AI.\nSee THIRD_PARTY_NOTICES.md for the list."]
    parts += [f"{n} {v} ({l})\n{url}\n\n{text}" for n, v, l, _, text, url in remote]
    # 授權全文相同的 Dart 套件合併成一段（例如同一份 Flutter / Dart 團隊的 BSD 授權）
    by_text = {}
    for n, v, _, text in dart:
        by_text.setdefault(text, []).append(f"{n} {v}")
    parts += [f"Dart packages: {', '.join(names)}\n\n{text}" for text, names in by_text.items()]
    open(os.path.join(REPO, "THIRD_PARTY_LICENSES.txt"), "w", encoding="utf-8").write(sep.join(parts) + "\n")

    open(os.path.join(REPO, "NOTICE"), "w", encoding="utf-8").write(
        "Pricing AI\nCopyright 2026 himalayasoft.xyz\n\n"
        "This product includes third-party software under their own licenses;\n"
        "see THIRD_PARTY_NOTICES.md and THIRD_PARTY_LICENSES.txt.\n")
    print(f"notices: {len(remote)} bundled/engine libraries, {len(dart)} Dart packages, {len(by_text)} distinct Dart license texts")


if __name__ == "__main__":
    main()
