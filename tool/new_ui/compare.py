"""Board-vs-app pixel comparison (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 0.4).

    python -I tool/new_ui/compare.py BOARD.png APP.png [--out DIR] [--threshold 2.0] [--tolerance 32] [--shift 1]
        [--mask build/new_ui/masks/BOARD.json]

Writes into DIR (default build/new_ui/compare/<APP name>):
  diff.png         the board faded, with every differing pixel in red
  overlay.png      board and app blended 50/50 (what the reviewer checks by eye)
  side_by_side.png board | app
and prints one JSON line: {"board", "app", "size", "different_pct", "threshold", "pass"}.

A pixel "differs" when any channel is off by more than --tolerance (0–255), which absorbs
font anti-aliasing differences between Chrome and Flutter but not a wrong color, size or
position. Images of different sizes fail (the frame itself is wrong); the overlapping area is
still diffed so the images show where.

--shift N (device pixels, default 0) also forgives a pixel that matches the other image within
N pixels of the same spot, like pixelmatch's anti-aliasing check. Chrome snaps text and borders
to whole device pixels and Flutter does not, so thin grey glyphs can differ by half a point
without anything being misplaced. With --shift, pass/fail uses the forgiving number and the
strict one is still printed as "different_pct_strict"; at 2x, --shift 1 is half a point, so a
real offset of a point or more still fails.

The percentage alone is too coarse for position: on a sparse screen a whole layout 2 points too
low changes only ~1.5 % of pixels. So every run also checks geometry: it finds each horizontal
band of content (a text line, a rule, a button) in both images, pairs them in order, and fails
when any band's top, bottom, left or right edge is more than --geometry device pixels off, or
when the number of bands differs. The worst offsets are printed under "geometry". Pass needs
both checks.

The default, 3 device pixels (1.5 points at 2x), is the floor Flutter can reach: it rounds every
text line's height to a whole pixel (Chrome keeps 23.2 or 22.5), so blocks drift up to half a
point per line, and glyph tops anti-alias a pixel differently. A 2-point misplacement still
fails.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageChops

parser = argparse.ArgumentParser()
parser.add_argument('board')
parser.add_argument('app')
parser.add_argument('--out')
parser.add_argument('--threshold', type=float, default=2.0, help='max %% of differing pixels to pass')
parser.add_argument('--tolerance', type=int, default=32, help='per-channel difference ignored (0-255)')
parser.add_argument('--shift', type=int, default=0, help='forgive matches within N device pixels')
parser.add_argument('--geometry', type=int, default=3, help='max band edge offset, device pixels')
parser.add_argument('--mask', help='JSON from board_masks.mjs: areas left out of both images (art, the page behind a sheet)')
a = parser.parse_args()

board = Image.open(a.board).convert('RGB')
app = Image.open(a.app).convert('RGB')
masked_pct = 0.0
if a.mask:
    # Layout only (section 19.1): the board's placeholder art and the page it draws behind a
    # sheet are filled with the same flat grey in both images, so they count as matching and
    # carry no bands.
    from PIL import ImageDraw
    spec = json.load(open(a.mask, encoding='utf-8'))
    k = board.width / spec['w']
    cover = Image.new('L', board.size, 0)
    draw = ImageDraw.Draw(cover)
    for x, y, rw, rh in spec['rects']:
        draw.rectangle([x * k, y * k, (x + rw) * k - 1, (y + rh) * k - 1], fill=255)
    masked_pct = 100.0 * cover.histogram()[255] / (board.width * board.height)
    flat = Image.new('RGB', board.size, (128, 128, 128))
    board = Image.composite(flat, board, cover)
    if app.size == board.size:
        app = Image.composite(flat, app, cover)
same_size = board.size == app.size
w, h = min(board.width, app.width), min(board.height, app.height)
b, p = board.crop((0, 0, w, h)), app.crop((0, 0, w, h))

delta = ImageChops.difference(b, p)
# A pixel differs if its largest channel difference exceeds the tolerance.
mask = delta.convert('RGB').split()
mask = ImageChops.lighter(ImageChops.lighter(mask[0], mask[1]), mask[2])
mask = mask.point(lambda v: 255 if v > a.tolerance else 0)
different = mask.histogram()[255]  # mask is 0 or 255 only
total = board.width * board.height if same_size else max(board.width * board.height, app.width * app.height)
missing = 0 if same_size else total - w * h
strict_pct = 100.0 * (different + missing) / total
pct = strict_pct

if a.shift > 0:
    bn = np.asarray(b, dtype=np.int16)
    pn = np.asarray(p, dtype=np.int16)
    n = a.shift
    padded = np.pad(pn, ((n, n), (n, n), (0, 0)), mode='edge')
    best = np.full(bn.shape[:2], 255, dtype=np.int16)
    for dy in range(-n, n + 1):
        for dx in range(-n, n + 1):
            moved = padded[n + dy:n + dy + h, n + dx:n + dx + w]
            best = np.minimum(best, np.abs(bn - moved).max(axis=2))
    forgiving = best > a.tolerance
    mask = Image.fromarray((forgiving * 255).astype(np.uint8))
    pct = 100.0 * (int(forgiving.sum()) + missing) / total

out = a.out or os.path.join('build', 'new_ui', 'compare', os.path.splitext(os.path.basename(a.app))[0])
os.makedirs(out, exist_ok=True)

faded = Image.blend(b, Image.new('RGB', b.size, 'white'), 0.7)
red = Image.new('RGB', b.size, (230, 30, 30))
Image.composite(red, faded, mask).save(os.path.join(out, 'diff.png'))
Image.blend(b, p, 0.5).save(os.path.join(out, 'overlay.png'))
side = Image.new('RGB', (board.width + app.width + 16, max(board.height, app.height)), 'white')
side.paste(board, (0, 0))
side.paste(app, (board.width + 16, 0))
side.save(os.path.join(out, 'side_by_side.png'))


def bands(img):
    """(top, bottom, left, right) of each run of rows holding content, i.e. pixels more than
    24 off the image's most common (background) color."""
    arr = np.asarray(img, dtype=np.int16)
    colors, counts = np.unique(arr.reshape(-1, 3), axis=0, return_counts=True)
    bg = colors[counts.argmax()]
    ink = np.abs(arr - bg).max(axis=2) > 24
    rows = ink.any(axis=1)
    out, start = [], None
    for y, on in enumerate(list(rows) + [False]):
        if on and start is None:
            start = y
        elif not on and start is not None:
            cols = np.flatnonzero(ink[start:y].any(axis=0))
            out.append((start, y, int(cols[0]), int(cols[-1]) + 1))
            start = None
    return out


bb, pb = bands(b), bands(p)
geometry = {'bands': {'board': len(bb), 'app': len(pb)}, 'tolerance_px': a.geometry}
if len(bb) == len(pb):
    offsets = [max(abs(x - y) for x, y in zip(m, n)) for m, n in zip(bb, pb)]
    worst = int(np.argmax(offsets)) if offsets else 0
    geometry['max_offset_px'] = max(offsets, default=0)
    if offsets:
        geometry['worst_band'] = {'board': list(bb[worst]), 'app': list(pb[worst])}
    geometry['pass'] = geometry['max_offset_px'] <= a.geometry
else:
    geometry['pass'] = False

result = {
    'board': a.board,
    'app': a.app,
    'size': {'board': list(board.size), 'app': list(app.size), 'match': same_size},
    'different_pct': round(pct, 2),
    **({'masked_pct': round(masked_pct, 1)} if a.mask else {}),
    **({'different_pct_strict': round(strict_pct, 2), 'shift': a.shift} if a.shift > 0 else {}),
    'threshold': a.threshold,
    'geometry': geometry,
    'pass': same_size and pct <= a.threshold and geometry['pass'],
    'out': out,
}
print(json.dumps(result))
sys.exit(0 if result['pass'] else 1)
