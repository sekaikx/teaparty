#!/usr/bin/env python3
"""Builds the game's UI icons (assets/icons/ui/*.svg) from the glyphs in assets/icons/src.

Every icon is the same badge: a round candy disc in the icon's colour (a soft top-to-bottom
gradient, an ink outline, a gloss highlight) with a white glyph and a soft ink drop shadow, so
the whole set reads as one family. Glyphs: Phosphor Icons (fill weight, MIT, see
assets/icons/src/LICENSE-phosphor.txt) plus our own teapot-fill.svg drawn to match.

    python3 tools/make_icons.py
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "icons", "src")
OUT = os.path.join(ROOT, "assets", "icons", "ui")
INK = "#1d1128"

# name: (glyph file, badge colour, glyph scale)
ICONS = {
    "poison": ("skull-fill", "#58b83a", 0.56),
    "antidote": ("shield-plus-fill", "#2f9fe0", 0.56),
    "sugar": ("cube-fill", "#ff7fae", 0.54),
    "plain": ("leaf-fill", "#c9853f", 0.56),
    "swap": ("arrows-left-right-fill", "#8f63ff", 0.58),
    "sniff": ("wind-fill", "#23b58a", 0.58),
    "watch": ("eye-fill", "#3f7fff", 0.6),
    "toast": ("champagne-fill", "#f2a019", 0.56),
    "back": ("question-mark-fill", "#6d4f93", 0.52),
    "spike": ("syringe-fill", "#8a3aa6", 0.54),
    "pot": ("teapot-fill", "#ff7059", 0.58),
    "cup": ("coffee-fill", "#e0883f", 0.56),
    "ghost": ("ghost-fill", "#8aa6ff", 0.58),
    "arrow": ("arrow-fat-right-fill", "#ffb400", 0.56),
    "night": ("moon-stars-fill", "#3b4a9a", 0.56),
    "inspect": ("detective-fill", "#c4861c", 0.6),
    "protect": ("first-aid-fill", "#e0455f", 0.54),
}


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(h, other, t):
    a, b = hex_to_rgb(h), hex_to_rgb(other)
    return "#%02x%02x%02x" % tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def glyph(name):
    """The glyph's inner SVG, its viewBox size, and whether it is stroked (Tabler) or filled."""
    with open(os.path.join(SRC, name + ".svg")) as f:
        svg = f.read()
    box = float(re.search(r'viewBox="0 0 ([\d.]+)', svg).group(1))
    body = svg[svg.index(">", svg.index("<svg")) + 1:svg.rindex("</svg>")]
    body = re.sub(r'<path stroke="none" d="M0 0h24v24H0z" fill="none"\s*/>', "", body)
    return body.strip(), box, "stroke=\"currentColor\"" in svg


def badge(name, glyph_name, colour, scale):
    body, box, stroked = glyph(glyph_name)
    size = 256.0 * scale
    k = size / box
    off = (256.0 - size) / 2.0
    top, bottom = mix(colour, "#ffffff", 0.28), mix(colour, INK, 0.22)
    if stroked:
        paint = 'fill="none" stroke="%s" stroke-width="%.2f" stroke-linecap="round" stroke-linejoin="round"'
        g_white = paint % ("#ffffff", 2.3)
        g_shadow = paint % (INK, 2.3)
    else:
        g_white = 'fill="#ffffff" color="#ffffff"'
        g_shadow = 'fill="%s" color="%s"' % (INK, INK)
    t = "translate(%.2f %.2f) scale(%.4f)" % (off, off, k)
    ts = "translate(%.2f %.2f) scale(%.4f)" % (off, off + 7, k)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{top}"/>
      <stop offset="1" stop-color="{bottom}"/>
    </linearGradient>
  </defs>
  <circle cx="128" cy="134" r="112" fill="{INK}" opacity="0.35"/>
  <circle cx="128" cy="126" r="112" fill="url(#g)" stroke="{INK}" stroke-width="11"/>
  <path d="M52 104 A80 80 0 0 1 204 104 A96 70 0 0 0 52 104 Z" fill="#ffffff" opacity="0.28"/>
  <g transform="{ts}" {g_shadow} opacity="0.35">{body}</g>
  <g transform="{t}" {g_white}>{body}</g>
</svg>
'''


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (g, colour, scale) in ICONS.items():
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(badge(name, g, colour, scale))
        print("icon", name)


if __name__ == "__main__":
    main()
