// Finds the parts of each design board that are not the screen's own layout, for the layout
// comparison in section 19.1 (docs/new-ui/NEW_UI_EXECUTION_PLAN.md): the placeholder art (flat
// colour blocks standing in for photos, thumbnails and avatars) and, on a sheet, the page drawn
// behind it. Writes build/new_ui/masks/<Board>.json: {"w", "h", "rects": [[x, y, w, h], ...]} in
// CSS pixels. `compare.py --mask` leaves those areas out of both images.
//
//   node tool/new_ui/board_masks.mjs                       # every screen board (not Note*)
//   node tool/new_ui/board_masks.mjs Main BuyPiece          # just these
//
// Needs Google Chrome (or set CHROME_PATH). No npm packages: talks to Chrome over the
// DevTools protocol with Node's built-in fetch and WebSocket (Node 22+).

import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, writeFileSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { tmpdir } from 'node:os';

const root = resolve(import.meta.dirname, '..', '..');
const refDir = join(root, 'docs', 'new-ui', 'reference');

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(name);
  if (i === -1) return fallback;
  const value = args[i + 1];
  args.splice(i, 2);
  return value;
};
const scale = Number(opt('--scale', '2'));
const outDir = resolve(root, opt('--out', join('build', 'new_ui', 'masks')));
const port = Number(opt('--port', '9335'));

const boards = args.length
  ? args
  : readdirSync(refDir)
      .filter((f) => f.endsWith('.dc.html') && !f.startsWith('Note'))
      .map((f) => f.replace(/\.dc\.html$/, ''));

const chromeCandidates = [
  process.env.CHROME_PATH,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
].filter(Boolean);
const chrome = chromeCandidates.find((p) => existsSync(p));
if (!chrome) throw new Error('Chrome not found — set CHROME_PATH.');

mkdirSync(outDir, { recursive: true });
const profile = join(tmpdir(), `studio3-board-render-${process.pid}`);
const proc = spawn(chrome, [
  '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
  `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, 'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let target;
for (let i = 0; i < 60 && !target; i++) {
  await sleep(250);
  try {
    target = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).find((t) => t.type === 'page');
  } catch { /* Chrome still starting */ }
}
if (!target) throw new Error('Could not connect to Chrome.');

const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r));
let id = 0;
const pending = new Map();
ws.addEventListener('message', (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
});
const send = (method, params = {}) =>
  new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });

await send('Page.enable');
await send('Runtime.enable');

let failed = 0;
for (const board of boards) {
  const file = join(refDir, `${board}.dc.html`);
  if (!existsSync(file)) { console.log(`skip ${board}: no such board`); failed++; continue; }
  await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
  await send('Page.navigate', { url: pathToFileURL(file).href });
  await sleep(1200);
  await send('Runtime.evaluate', { expression: 'document.fonts.ready.then(() => true)', awaitPromise: true });
  const size = await send('Runtime.evaluate', {
    returnByValue: true,
    expression: `(() => {
      const el = document.querySelector('[data-dc-script]');
      let p = {};
      try { p = JSON.parse(el?.dataset.props || '{}').$preview || {}; } catch (e) {}
      return JSON.stringify({ w: p.width || 390, h: p.height || document.documentElement.scrollHeight });
    })()`,
  });
  const { w, h } = JSON.parse(size.result.result.value);
  await send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: true });
  await sleep(300);
  const res = await send('Runtime.evaluate', {
    returnByValue: true,
    expression: `(() => {
      // UI colours: greys, the page and card colours, Ink, and the status accents.
      const ui = new Set(['2e8b57', '1e6b3c', 'e7f2ea', 'b3261e', 'fceceb', 'f2665c', '4caf7a']);
      const rgb = (s) => (s.includes('(') ? s.slice(s.indexOf('(') + 1, s.indexOf(')')).split(',').map((v) => parseFloat(v)) : null);
      const hex = (c) => c.slice(0, 3).map((v) => Math.round(v).toString(16).padStart(2, '0')).join('');
      const isArt = (style) => {
        if (style.backgroundImage && style.backgroundImage !== 'none' && !/gradient/.test(style.backgroundImage)) return true;
        const c = rgb(style.backgroundColor);
        if (!c || (c.length > 3 && c[3] < 0.95)) return false;
        const grey = Math.max(c[0], c[1], c[2]) - Math.min(c[0], c[1], c[2]) <= 12;
        return !grey && !ui.has(hex(c));
      };
      const rects = [];
      const frame = document.querySelector('x-dc > div') || document.body;
      const top = frame.getBoundingClientRect();
      const all = [...frame.querySelectorAll('*')];
      // A sheet over the page: a full-frame dark scrim. Everything before it in the page is the
      // page behind the sheet, which is masked as a whole below.
      const scrimAt = all.findLastIndex((el) => {
        const r = el.getBoundingClientRect();
        const c = rgb(getComputedStyle(el).backgroundColor);
        return c && c.length > 3 && c[3] >= 0.2 && c[3] < 0.95 && Math.max(c[0], c[1], c[2]) < 40 &&
          r.width >= top.width - 1 && r.height >= top.height - 1;
      });
      for (const el of scrimAt >= 0 ? all.slice(scrimAt + 1) : all) {
        const r = el.getBoundingClientRect();
        if (r.width < 14 || r.height < 14) continue;
        const style = getComputedStyle(el);
        if (el.tagName === 'IMG' || (isArt(style) && !el.textContent.trim())) {
          rects.push([r.left - top.left, r.top - top.top, r.width, r.height]);
        }
      }
      // The sheet: the first page-coloured, full-width block after the scrim.
      let behind = null;
      if (scrimAt >= 0) {
        const after = all.slice(scrimAt + 1).filter((el) => {
          const r = el.getBoundingClientRect();
          const c = rgb(getComputedStyle(el).backgroundColor);
          return c && (c.length === 3 || c[3] >= 0.95) && Math.min(c[0], c[1], c[2]) > 230 &&
            r.width >= top.width - 1 && r.top - top.top > 20;
        });
        if (after.length) behind = Math.min(...after.map((el) => el.getBoundingClientRect().top - top.top));
      }
      if (behind != null) rects.push([0, 0, top.width, behind]);
      return JSON.stringify({ rects, behind });
    })()`,
  });
  const found = JSON.parse(res.result.result.value);
  const out = join(outDir, `${board}.json`);
  writeFileSync(out, JSON.stringify({ w, h, ...found }));
  console.log(`${board}: ${found.rects.length} masked areas${found.behind != null ? `, page behind the sheet down to ${Math.round(found.behind)}` : ''}`);
}

ws.close();
proc.kill();
await sleep(300);
try { rmSync(profile, { recursive: true, force: true }); } catch { /* Chrome may still hold files */ }
process.exitCode = failed ? 1 : 0;
