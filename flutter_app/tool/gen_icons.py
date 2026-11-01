#!/usr/bin/env python3
"""App 圖示：由 Pricing AI 的標誌（logo/pricing-ai-logo.svg 的價格標籤 + AI 星芒）產生 macOS 與 Windows 的圖示。
- macOS：照 Apple 的圖示格線，1024 畫布上 824×824 的圓角方塊、四周留白並加淡陰影（和其他 Mac App 一樣大小）
- Windows：同樣的圖案，滿版圓角方塊，存成多尺寸 .ico
網頁版的圖示（web/icons、favicon）已經是這個標誌，不在這裡產生。
需要 Inkscape（把 SVG 轉成 PNG）與 Pillow：python3 tool/gen_icons.py"""
import os, subprocess, tempfile
from PIL import Image

APP = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
REPO = os.path.join(APP, "..")
INKSCAPE = "/Applications/Inkscape.app/Contents/MacOS/inkscape"

# 標誌的圖案（與 logo/pricing-ai-logo.svg 相同）：200×200 的徽章，中心在 (120, 120)
BADGE = """
  <rect x="20" y="20" width="200" height="200" rx="45" fill="url(#bg)"/>
  <g transform="translate(120 120) rotate(45)">
    <path fill="#fff" fill-rule="evenodd"
      d="M0 -66 L40 -32 L40 56 Q40 64 32 64 L-32 64 Q-40 64 -40 56 L-40 -32 Z
         M8 -34 A8 8 0 1 0 -8 -34 A8 8 0 1 0 8 -34 Z"/>
    <g transform="translate(0 20) rotate(-45)">
      <path fill="#4F46E5" d="M0 -26 C3 -9 9 -3 26 0 C9 3 3 9 0 26 C-3 9 -9 3 -26 0 C-9 -3 -3 -9 0 -26 Z"/>
    </g>
  </g>"""

DEFS = """<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#4F46E5"/><stop offset="1" stop-color="#06B6D4"/>
    </linearGradient>"""


def svg(size, inset, shadow):
    """size×size 畫布，徽章放在 inset 留白內；shadow=True 加 macOS 風格的淡陰影"""
    body = size - 2 * inset
    scale = body / 200
    filt = """<filter id="sh" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="14"/><feOffset dy="10"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.30"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>""" if shadow else ""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  <defs>{DEFS}{filt}</defs>
  <g{' filter="url(#sh)"' if shadow else ''} transform="translate({size / 2} {size / 2}) scale({scale}) translate(-120 -120)">{BADGE}
  </g>
</svg>
"""


def render(svg_text, px):
    with tempfile.TemporaryDirectory() as d:
        src, out = os.path.join(d, "icon.svg"), os.path.join(d, "icon.png")
        open(src, "w").write(svg_text)
        subprocess.run([INKSCAPE, src, "--export-type=png", f"--export-filename={out}", "-w", str(px), "-h", str(px)], check=True, capture_output=True)
        return Image.open(out).convert("RGBA")


def main():
    mac_svg, win_svg = svg(1024, 100, True), svg(256, 0, False)
    open(os.path.join(REPO, "logo", "app-icon-macos.svg"), "w").write(mac_svg)
    open(os.path.join(REPO, "logo", "app-icon.svg"), "w").write(win_svg)

    mac = render(mac_svg, 1024)
    d = os.path.join(APP, "macos/Runner/Assets.xcassets/AppIcon.appiconset")
    for px in (16, 32, 64, 128, 256, 512, 1024):
        (mac if px == 1024 else mac.resize((px, px), Image.LANCZOS)).save(os.path.join(d, f"app_icon_{px}.png"))

    # Windows：小尺寸也從大圖縮小（比直接畫小圖清楚），存成 16–256 的多尺寸 .ico
    win = render(win_svg, 256)
    win.save(os.path.join(APP, "windows/runner/resources/app_icon.ico"), sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print("icons: macOS app_icon_16…1024.png, Windows app_icon.ico (16–256), logo/app-icon*.svg")


if __name__ == "__main__":
    main()
