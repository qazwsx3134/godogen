// Opens the web build as a landscape phone (844x390, touch) in headless Chromium: taps the title to start, taps
// the right half (slash) and left half (jump) for a while, saves screenshots, and fails on page errors.
//   python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web &      (note the PID, kill it afterwards)
//   node tools/web_landscape.mjs --playwright <dir>/node_modules/playwright-core --url http://127.0.0.1:8765/index.html --out <dir>
// (godot-kit's web_probe.mjs only knows portrait phones.)
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const arg = (n, d) => { const i = process.argv.indexOf(n); return i >= 0 ? process.argv[i + 1] : d; };
const require = createRequire(import.meta.url);
const { chromium } = require(arg('--playwright'));
const out = arg('--out', '/tmp/web_landscape');
fs.mkdirSync(out, { recursive: true });
const base = path.join(os.homedir(), '.cache/ms-playwright');
const dir = fs.readdirSync(base).filter(d => /^chromium-\d+$/.test(d)).sort().pop();
const browser = await chromium.launch({ executablePath: path.join(base, dir, 'chrome-linux64/chrome'),
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'] });
const page = await browser.newPage({ viewport: { width: 844, height: 390 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
const problems = [];
page.on('console', m => { if (m.type() === 'error') problems.push('console: ' + m.text()); });
page.on('pageerror', e => problems.push('pageerror: ' + e.message));
page.on('requestfailed', r => problems.push('request failed: ' + r.url()));
await page.goto(arg('--url'));
await page.waitForTimeout(9000);
await page.screenshot({ path: path.join(out, '1-title.png') });
await page.touchscreen.tap(422, 195);
await page.waitForTimeout(2500);
await page.screenshot({ path: path.join(out, '2-start.png') });
for (let i = 0; i < 40; i++) {               // ~12 s of play: mostly slashes, a jump now and then
  await page.touchscreen.tap(i % 5 === 4 ? 150 : 700, 300);
  await page.waitForTimeout(300);
}
await page.screenshot({ path: path.join(out, '3-play.png') });
const info = await page.evaluate(() => ({ canvas: [document.querySelector('canvas')?.width, document.querySelector('canvas')?.height],
  touch: navigator.maxTouchPoints }));
console.log(JSON.stringify({ info, problems }, null, 1));
await browser.close();
process.exit(problems.length ? 1 : 0);
