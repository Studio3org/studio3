"""Board-vs-app pixel comparison (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 0.4).

    python -I tool/new_ui/compare.py BOARD.png APP.png [--out DIR] [--threshold 2.0] [--tolerance 32]

Writes into DIR (default build/new_ui/compare/<APP name>):
  diff.png         the board faded, with every differing pixel in red
  overlay.png      board and app blended 50/50 (what the reviewer checks by eye)
  side_by_side.png board | app
and prints one JSON line: {"board", "app", "size", "different_pct", "threshold", "pass"}.

A pixel "differs" when any channel is off by more than --tolerance (0–255), which absorbs
font anti-aliasing differences between Chrome and Flutter but not a wrong color, size or
position. Images of different sizes fail (the frame itself is wrong); the overlapping area is
still diffed so the images show where.
"""
import argparse
import json
import os
import sys

from PIL import Image, ImageChops

parser = argparse.ArgumentParser()
parser.add_argument('board')
parser.add_argument('app')
parser.add_argument('--out')
parser.add_argument('--threshold', type=float, default=2.0, help='max %% of differing pixels to pass')
parser.add_argument('--tolerance', type=int, default=32, help='per-channel difference ignored (0-255)')
a = parser.parse_args()

board = Image.open(a.board).convert('RGB')
app = Image.open(a.app).convert('RGB')
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
pct = 100.0 * (different + (0 if same_size else total - w * h)) / total

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

result = {
    'board': a.board,
    'app': a.app,
    'size': {'board': list(board.size), 'app': list(app.size), 'match': same_size},
    'different_pct': round(pct, 2),
    'threshold': a.threshold,
    'pass': same_size and pct <= a.threshold,
    'out': out,
}
print(json.dumps(result))
sys.exit(0 if result['pass'] else 1)
