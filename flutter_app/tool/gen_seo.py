#!/usr/bin/env python3
"""由 lib/i18n/*.dart 產生各語言的 SEO 落地頁 (web/<lang>/index.html)、sitemap.xml、robots.txt。
Flutter CanvasKit 的畫面不會被搜尋引擎讀到文字，所以每種語言各有一個靜態頁，
內容直接取自 App 的 i18n 字串（改文案後重跑本腳本）。"""
import html, json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = "https://pricingai.minervaelectronics.com"
# (資料夾, i18n 檔, hreflang, og:locale, 顯示名)
LANGS = [("zh", "zh", "zh-TW", "zh_TW", "繁體中文"), ("ja", "ja", "ja", "ja_JP", "日本語"),
         ("en", "en", "en", "en_US", "English"), ("pt", "pt", "pt-BR", "pt_BR", "Português"),
         ("es", "es", "es", "es_ES", "Español")]

def load(code):
    d = {}
    for m in re.finditer(r"^\s*'([^']+)':\s*\"((?:[^\"\\]|\\.)*)\",\s*$", (ROOT / f"lib/i18n/{code}.dart").read_text(), re.M):
        d[m.group(1)] = m.group(2).replace('\\n', '\n').replace('\\"', '"').replace('\\$', '$')
    return d

CSS = """:root{--bg:#f6f7fb;--fg:#1c2433;--mut:#5b6577;--card:#fff;--brand:#263c5c;--warn:#fff4e0;--warnb:#e0a030;--line:#dde1ea}
@media(prefers-color-scheme:dark){:root{--bg:#10141c;--fg:#e8ebf2;--mut:#9aa4b6;--card:#181e2a;--brand:#9db8e8;--warn:#2a2316;--warnb:#a87a1e;--line:#2a3243}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.65 system-ui,-apple-system,"PingFang TC","Hiragino Sans","Noto Sans","Microsoft JhengHei",sans-serif}
main{max-width:860px;margin:0 auto;padding:24px 16px 48px}header{display:flex;flex-wrap:wrap;gap:8px 16px;align-items:center;justify-content:space-between;margin-bottom:24px}
.brand{display:block;background:#fff;border-radius:12px;padding:4px 10px;line-height:0}.brand img{height:44px;width:auto}nav{display:flex;flex-wrap:wrap;gap:4px 14px;font-size:14px}nav a{color:var(--mut);text-decoration:none}nav a[aria-current]{color:var(--fg);font-weight:700}
h1{font-size:clamp(26px,5vw,38px);line-height:1.25;margin:0 0 12px;color:var(--brand)}h2{font-size:20px;margin:32px 0 4px}p{margin:8px 0}.sub{color:var(--mut);white-space:pre-line}
.notice{background:var(--warn);border:1px solid var(--warnb);border-radius:12px;padding:14px 16px;margin:20px 0}.notice b{display:block;margin-bottom:4px}
.grid{display:grid;gap:12px;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));margin-top:12px}.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px 16px}.card h3{font-size:16px;margin:0 0 4px}.card p{margin:0;color:var(--mut);font-size:14px}
.cta{display:inline-block;margin-top:20px;padding:12px 24px;border-radius:99px;background:var(--brand);color:var(--bg);font-weight:700;text-decoration:none}footer{margin-top:40px;color:var(--mut);font-size:13px;border-top:1px solid var(--line);padding-top:16px}"""

def page(folder, code, hl, loc, name, T):
    esc = html.escape
    title = f"{T['app.title']} · {T['intro.title']}"
    desc = T['intro.subtitle'].replace('\n', ' ')
    if len(desc) > 150:
        desc = desc[:150].rsplit(' ', 1)[0].rstrip(',;:、，') + '…' if ' ' in desc[:150] else desc[:140] + '…'
    url = f"{SITE}/{folder}/"
    alts = "\n".join(f'<link rel="alternate" hreflang="{h}" href="{SITE}/{f}/">' for f, _, h, _, _ in LANGS)
    alts += f'\n<link rel="alternate" hreflang="x-default" href="{SITE}/">'
    og_alt = "\n".join(f'<meta property="og:locale:alternate" content="{l}">' for f, _, _, l, _ in LANGS if f != folder)
    nav = "".join(f'<a href="/{f}/" hreflang="{h}" lang="{h}"{" aria-current=\"page\"" if f == folder else ""}>{esc(n)}</a>' for f, _, h, _, n in LANGS)
    steps = "".join(f'<div class="card"><h3>{i}. {esc(T[f"intro.step{i}.t"])}</h3><p>{esc(T[f"intro.step{i}.b"])}</p></div>' for i in range(1, 5))
    outs = "".join(f'<div class="card"><h3>{esc(T[f"intro.out{i}.t"])}</h3><p>{esc(T[f"intro.out{i}.b"])}</p></div>' for i in range(1, 4))
    ld = {"@context": "https://schema.org", "@type": "WebApplication", "name": T['app.title'], "url": url,
          "description": desc, "inLanguage": hl, "applicationCategory": "BusinessApplication",
          "operatingSystem": "Any (WebGPU / WebAssembly browser)", "browserRequirements": "Requires JavaScript",
          "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"}}
    return f"""<!doctype html>
<html lang="{hl}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(desc)}">
<link rel="canonical" href="{url}">
{alts}
<meta property="og:type" content="website">
<meta property="og:site_name" content="Pricing AI">
<meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(desc)}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{SITE}/og-image.png">
<meta property="og:locale" content="{loc}">
{og_alt}
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{esc(title)}">
<meta name="twitter:description" content="{esc(desc)}">
<meta name="twitter:image" content="{SITE}/og-image.png">
<link rel="icon" type="image/png" href="/favicon.png">
<script type="application/ld+json">{json.dumps(ld, ensure_ascii=False)}</script>
<style>{CSS}</style>
</head>
<body>
<main>
<header><a class="brand" href="/{folder}/"><img src="/logo.svg" alt="Pricing AI" height="44"></a><nav aria-label="Language">{nav}</nav></header>
<h1>{esc(T['intro.title'])}</h1>
<p class="sub">{esc(T['intro.subtitle'])}</p>
<div class="notice" role="note"><b>{esc(T['intro.notice.title'])}</b>{esc(T['intro.notice.body'])}</div>
<a class="cta" href="/?lang={folder}">{esc(T['intro.start'])}</a>
<h2>{esc(T['intro.flow.title'])}</h2><p class="sub">{esc(T['intro.flow.sub'])}</p>
<div class="grid">{steps}</div>
<h2>{esc(T['intro.out.title'])}</h2><p class="sub">{esc(T['intro.out.sub'])}</p>
<div class="grid">{outs}</div>
<a class="cta" href="/?lang={folder}">{esc(T['intro.start'])}</a>
<footer>{esc(T['intro.footer'])}</footer>
</main>
</body>
</html>
"""

def main():
    web = ROOT / "web"
    for folder, code, hl, loc, name in LANGS:
        d = web / folder
        d.mkdir(exist_ok=True)
        (d / "index.html").write_text(page(folder, code, hl, loc, name, load(code)))
    urls = [("/", None)] + [(f"/{f}/", f) for f, *_ in LANGS]
    def alts(): return "".join(f'<xhtml:link rel="alternate" hreflang="{h}" href="{SITE}/{f}/"/>' for f, _, h, _, _ in LANGS) + f'<xhtml:link rel="alternate" hreflang="x-default" href="{SITE}/"/>'
    sm = ['<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">']
    for path, _ in urls:
        sm.append(f"<url><loc>{SITE}{path}</loc>{alts()}</url>")
    sm.append("</urlset>")
    (web / "sitemap.xml").write_text("\n".join(sm) + "\n")
    (web / "robots.txt").write_text(f"User-agent: *\nAllow: /\n\nSitemap: {SITE}/sitemap.xml\n")
    print("generated:", ", ".join(f for f, *_ in LANGS), "+ sitemap.xml robots.txt")

main()
