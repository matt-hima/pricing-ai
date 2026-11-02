#!/usr/bin/env python3
"""產生 Sparkle 自動更新用的 dist/appcast.xml（只含最新一版）。由 tool/release_mac.sh 呼叫：
  python3 tool/gen_appcast.py <dmg> <版本名稱> <組建號> <release-notes.md> <EdDSA 簽章>
appcast 跟 DMG 一起上傳到 GitHub Release；App 讀 releases/latest/download/appcast.xml，
DMG 網址指向該版的 tag（releases/download/v<版本>/PricingAI-mac.dmg）。
本機測試可用環境變數 APPCAST_DOWNLOAD_URL 覆寫 DMG 網址。"""
import html, os, re, sys
from email.utils import formatdate

REPO = "https://github.com/matt-hima/pricing-ai"
MIN_MACOS = "10.15"


def md_to_html(md):
    # 只轉 release notes 用到的語法：段落、**粗體**、*斜體*、`程式碼`、1. / - 清單、網址
    def inline(s):
        s = html.escape(s)
        s = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)
        s = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<i>\1</i>", s)
        s = re.sub(r"`(.+?)`", r"<code>\1</code>", s)
        return re.sub(r"(https://[^\s<]+[^\s<.,)])", r'<a href="\1">\1</a>', s)

    out = []
    for block in re.split(r"\n\s*\n", md.strip()):
        lines = block.splitlines()
        items = [re.match(r"^\s*(?:\d+\.|-)\s+(.*)$", l) for l in lines]
        if all(items):
            tag = "ol" if re.match(r"^\s*\d+\.", lines[0]) else "ul"
            out.append(f"<{tag}>" + "".join(f"<li>{inline(m.group(1))}</li>" for m in items) + f"</{tag}>")
        elif lines and items[0] is None and all(items[1:]) and len(lines) > 1:
            # 標題行接清單（例如 **Install** 加 1. 2. 3.）
            tag = "ol" if re.match(r"^\s*\d+\.", lines[1]) else "ul"
            out.append(f"<p>{inline(lines[0])}</p><{tag}>" + "".join(f"<li>{inline(m.group(1))}</li>" for m in items[1:]) + f"</{tag}>")
        else:
            out.append("<p>" + "<br>".join(inline(l) for l in lines) + "</p>")
    return "\n".join(out)


def main():
    dmg, name, build, notes, signature = sys.argv[1:6]
    url = os.environ.get("APPCAST_DOWNLOAD_URL") or f"{REPO}/releases/download/v{name}/PricingAI-mac.dmg"
    body = md_to_html(open(notes, encoding="utf-8").read()).replace("]]>", "]]&gt;")
    xml = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Pricing AI</title>
    <link>{REPO}/releases</link>
    <item>
      <title>Pricing AI {html.escape(name)}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <link>{REPO}/releases/tag/v{html.escape(name)}</link>
      <sparkle:version>{html.escape(build)}</sparkle:version>
      <sparkle:shortVersionString>{html.escape(name)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{MIN_MACOS}</sparkle:minimumSystemVersion>
      <description><![CDATA[{body}]]></description>
      <enclosure url="{html.escape(url)}" length="{os.path.getsize(dmg)}" type="application/octet-stream" sparkle:edSignature="{html.escape(signature)}"/>
    </item>
  </channel>
</rss>
"""
    out = os.path.join(os.path.dirname(dmg), "appcast.xml")
    with open(out, "w", encoding="utf-8") as f:
        f.write(xml)
    print(out)


if __name__ == "__main__":
    main()
