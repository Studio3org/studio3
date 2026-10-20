// Renders design boards from docs/new-ui/reference/ to PNGs, at each board's own frame size
// (its `$preview` width × height), for the board-vs-app pixel comparison
// (docs/new-ui/NEW_UI_EXECUTION_PLAN.md, section 0.4).
//
//   node tool/new_ui/render_boards.mjs                       # every screen board (not Note*)
//   node tool/new_ui/render_boards.mjs Main BuyPiece          # just these
//   node tool/new_ui/render_boards.mjs --scale 2 --out build/new_ui/boards
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
const outDir = resolve(root, opt('--out', join('build', 'new_ui', 'boards')));
const port = Number(opt('--port', '9334'));

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
  await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: scale, mobile: true });
  await send('Page.navigate', { url: pathToFileURL(file).href });
  await sleep(1500);
  // Wait for fonts so text is measured with the real glyphs.
  await send('Runtime.evaluate', { expression: 'document.fonts.ready.then(() => true)', awaitPromise: true });
  const res = await send('Runtime.evaluate', {
    returnByValue: true,
    expression: `(() => {
      const el = document.querySelector('[data-dc-script]');
      let p = {};
      try { p = JSON.parse(el?.dataset.props || '{}').$preview || {}; } catch (e) {}
      return JSON.stringify({ w: p.width || 390, h: p.height || document.documentElement.scrollHeight });
    })()`,
  });
  const { w, h } = JSON.parse(res.result.result.value);
  await send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: scale, mobile: true });
  await sleep(400);
  const shot = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
    clip: { x: 0, y: 0, width: w, height: h, scale: 1 },
  });
  const out = join(outDir, `${board}.png`);
  writeFileSync(out, Buffer.from(shot.result.data, 'base64'));
  console.log(`${board}: ${w}×${h} @${scale}x → ${out}`);
}

ws.close();
proc.kill();
await sleep(300);
try { rmSync(profile, { recursive: true, force: true }); } catch { /* Chrome may still hold files */ }
process.exitCode = failed ? 1 : 0;
