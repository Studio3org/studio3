"""Builds the "studio 3" wordmark as SVG logo files from the bundled Outfit font.

HandoffRules (Type): "Outfit is brand only: the wordmark and marketing. In the app, the
wordmark ships as a logo file." The boards set it as live text; this turns exactly that text
into outlines so the app ships a file, not a font-dependent string:

    python -I tool/new_ui/make_wordmark.py

Writes assets/brand/wordmark_{signin,header}_{black,white}.svg. Each SVG's box is the CSS
text box the boards use (line-height 1 → 1em tall; width = advances + letter-spacing after
every glyph, as Chrome lays it out), so drawing it at the board's font-size in px (e.g.
height 40 for the 40 px sign-in wordmark) puts every glyph where the board has it.
"""
import os

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
FONT = os.path.join(ROOT, 'assets', 'fonts', 'Outfit-VariableFont_wght.ttf')
OUT = os.path.join(ROOT, 'assets', 'brand')

TEXT = 'studio 3'
# (name, font-size px, letter-spacing px) exactly as on the boards.
VARIANTS = [
    ('signin', 40, -0.5),   # SignInFirst / SignInFirstDark
    ('header', 27, -0.4),   # Main (Home feed top bar)
]
COLORS = {'black': '#111111', 'white': '#FAFAF8'}

font = instantiateVariableFont(TTFont(FONT), {'wght': 700})
upem = font['head'].unitsPerEm
cmap = font.getBestCmap()
glyphs = font.getGlyphSet()
hmtx = font['hmtx']
asc, desc = font['hhea'].ascent, -font['hhea'].descent  # desc as a positive number

for name, size, spacing in VARIANTS:
    track = spacing / size * upem  # letter-spacing in font units
    # line-height: 1 → the box is 1em; half-leading is split evenly above and below.
    half_leading = (upem - (asc + desc)) / 2
    baseline = half_leading + asc  # from the top of the 1em box, in font units
    pen = SVGPathPen(glyphs)
    x = 0.0
    for ch in TEXT:
        gname = cmap[ord(ch)]
        # Font outlines are y-up; SVG is y-down with the baseline at `baseline`.
        glyphs[gname].draw(TransformPen(pen, (1, 0, 0, -1, x, baseline)))
        x += hmtx[gname][0] + track
    width = x
    path = pen.getCommands()
    for cname, color in COLORS.items():
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:.1f} {upem}">'
               f'<path fill="{color}" d="{path}"/></svg>\n')
        with open(os.path.join(OUT, f'wordmark_{name}_{cname}.svg'), 'w', encoding='utf-8') as f:
            f.write(svg)
    print(f'{name}: {size}px -> {width / upem * size:.2f} x {size} px')
