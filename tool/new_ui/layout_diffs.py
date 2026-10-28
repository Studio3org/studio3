"""Layout diff for every board that has a golden (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, 19.1).

    node tool/new_ui/render_boards.mjs      # board images
    node tool/new_ui/board_masks.mjs        # art and page-behind-the-sheet masks
    python -I tool/new_ui/layout_diffs.py [--tracker]

For each test/new_ui/goldens/<Board>.png with a board image of the same name, runs compare.py
twice: the whole frame, and layout only (--mask). Writes build/new_ui/layout_diffs.csv and prints
a summary. With --tracker, the "Pixel diff %" column of docs/new-ui/TRACKER.csv becomes
"layout X% (frame Y%)" for those boards.
"""
import csv
import io
import json
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
GOLDENS = os.path.join(ROOT, 'test', 'new_ui', 'goldens')
BOARDS = os.path.join(ROOT, 'build', 'new_ui', 'boards')
MASKS = os.path.join(ROOT, 'build', 'new_ui', 'masks')
COMPARE = os.path.join(ROOT, 'tool', 'new_ui', 'compare.py')
TRACKER = os.path.join(ROOT, 'docs', 'new-ui', 'TRACKER.csv')


def run(board, golden, mask=None):
    cmd = [sys.executable, '-I', COMPARE, board, golden, '--shift', '1',
           '--out', os.path.join(ROOT, 'build', 'new_ui', 'compare', 'layout' if mask else 'frame',
                                 os.path.splitext(os.path.basename(golden))[0])]
    if mask:
        cmd += ['--mask', mask]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout.strip().splitlines()
    return json.loads(out[-1]) if out else None


rows = []
for name in sorted(os.listdir(GOLDENS)):
    board_name = os.path.splitext(name)[0]
    board = os.path.join(BOARDS, name)
    mask = os.path.join(MASKS, board_name + '.json')
    if not os.path.exists(board) or not os.path.exists(mask):
        continue
    frame = run(board, os.path.join(GOLDENS, name))
    layout = run(board, os.path.join(GOLDENS, name), mask)
    if not frame or not layout:
        continue
    rows.append({
        'board': board_name,
        'frame_pct': frame['different_pct'],
        'layout_pct': layout['different_pct'],
        'masked_pct': layout.get('masked_pct', 0),
        'geometry_pass': layout['geometry']['pass'],
        'max_offset_px': layout['geometry'].get('max_offset_px'),
        'bands': f"{layout['geometry']['bands']['board']}/{layout['geometry']['bands']['app']}",
        'size_match': layout['size']['match'],
    })

os.makedirs(os.path.join(ROOT, 'build', 'new_ui'), exist_ok=True)
with open(os.path.join(ROOT, 'build', 'new_ui', 'layout_diffs.csv'), 'w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()) if rows else ['board'])
    w.writeheader()
    w.writerows(rows)

under = [r for r in rows if r['layout_pct'] < 2]
print(json.dumps({
    'boards': len(rows),
    'layout_under_2': len(under),
    'frame_under_2': len([r for r in rows if r['frame_pct'] < 2]),
    'over': sorted(((r['board'], r['layout_pct'], r['bands']) for r in rows if r['layout_pct'] >= 2),
                   key=lambda x: -x[1]),
}))

if '--tracker' in sys.argv:
    text = open(TRACKER, encoding='utf-8', newline='').read()
    lines = text.split('\n')
    by_board = {r['board']: r for r in rows}
    for i, line in enumerate(lines):
        if not line.strip():
            continue
        end = '\r' if line.endswith('\r') else ''
        parts = next(csv.reader(io.StringIO(line.rstrip('\r'))))
        if len(parts) != 11 or parts[0] not in by_board:
            continue
        r = by_board[parts[0]]
        parts[7] = f"layout {r['layout_pct']}% (frame {r['frame_pct']}%)"
        buf = io.StringIO()
        csv.writer(buf, lineterminator='').writerow(parts)
        lines[i] = buf.getvalue() + end
    open(TRACKER, 'w', encoding='utf-8', newline='').write('\n'.join(lines))
    print('tracker updated')
