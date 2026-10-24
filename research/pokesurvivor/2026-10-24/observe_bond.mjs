// 實玩觀察：在本機伺服器（只放行 127.0.0.1，線上服務一律擋掉）開 dev.html，
// 以訪客身分起一局，直接塞招式與羈絆，擷取羈絆選擇畫面、2×2 招式格，並量測同組招式的施放間隔。
// 用法：先 `python3 -m http.server 8799 --bind 127.0.0.1 --directory upstream`，再 `node observe_bond.mjs`
// 輸出：screenshots/bond-*.png、generated/observe-bond.json（兩個資料夾都被 .gitignore 排除）
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('/Users/peter/.npm/_npx/e41f203b7505f1fb/node_modules/playwright-core');
const HERE = path.dirname(fileURLToPath(import.meta.url));
const SHOTS = path.join(HERE, 'screenshots');
const GEN = path.join(HERE, 'generated');
fs.mkdirSync(SHOTS, { recursive: true });
fs.mkdirSync(GEN, { recursive: true });
const BASE = 'http://127.0.0.1:8799/';
const log = { notes: [], errors: [], blocked: [] };
const wait = ms => new Promise(r => setTimeout(r, ms));

const browser = await chromium.launch({
  executablePath: '/Users/peter/Library/Caches/ms-playwright/chromium-1243/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing',
  headless: true,
});
const ctx = await browser.newContext({ viewport: { width: 1100, height: 700 }, serviceWorkers: 'block' });
await ctx.route('**/*', route => {
  const u = route.request().url();
  if (u.startsWith(BASE) || u.startsWith('data:') || u.startsWith('blob:')) return route.continue();
  log.blocked.push(u.slice(0, 100));
  return route.abort();
});
const page = await ctx.newPage();
page.on('pageerror', e => log.errors.push('pageerror: ' + String(e).slice(0, 200)));
page.on('console', m => { if (m.type() === 'error') log.errors.push('console.error: ' + m.text().slice(0, 200)); });

try {
  await page.goto(BASE + 'dev.html?dev', { waitUntil: 'load' });
  await page.waitForFunction(() => window.G && G.Flow && G.DB, null, { timeout: 30000 });
  await wait(2500);
  // 「點一下開始」：瀏覽器不讓網頁出聲時才會出現
  await page.evaluate(() => { const el = document.getElementById('tap-start'); if (el && !el.classList.contains('hidden')) el.click(); });
  await wait(500);
  await page.screenshot({ path: path.join(SHOTS, 'bond-00-login.png') });

  // 訪客 → 直接指定夥伴（小火龍，等同個性測驗後按「就是它」）→ 開一局
  const started = await page.evaluate(() => {
    document.getElementById('btn-guest').click();
    const s = G.DB.save;
    if (!s.partner) { s.starter = 4; s.partner = 4; G.DB.grant(4, 'starter'); G.Flow.goMenu(); }
    G.Flow.play();
    const pl = G.Game.player;
    return { state: G.Game.state, mon: pl && pl.mon.name, moves: pl && pl.moves.map(m => m.id) };
  });
  log.notes.push({ started });
  await wait(1500);

  // 方便觀察：不死、塞三個招式（共 4 格）與兩個羈絆
  const setup = await page.evaluate(() => {
    const pl = G.Game.player;
    pl.maxHp = pl.hp = 9999;
    for (const id of ['flamethrower', 'fire-spin', 'heat-wave']) pl.addMove(id);
    pl.bonds = 2;
    return { slots: pl.slots.map(g => g.map(m => m.id)), active: pl.active, bonds: pl.bonds, maxMoves: pl.maxMoves };
  });
  log.notes.push({ setup });
  await wait(900);
  const bond1 = await page.evaluate(() => ({ open: G.UI.isOpen('scr-bond'), state: G.Game.state, sub: document.getElementById('bond-sub').textContent,
    cards: [...document.querySelectorAll('#bond-cards .card .nm')].map(e => e.textContent.trim()) }));
  log.notes.push({ bond1 });
  await page.screenshot({ path: path.join(SHOTS, 'bond-01-pair-step1.png') });

  await page.keyboard.press('Digit1');            // 第一步：選第一招
  await wait(400);
  const bond1b = await page.evaluate(() => ({ sub: document.getElementById('bond-sub').textContent,
    cards: [...document.querySelectorAll('#bond-cards .card .ds')].map(e => e.textContent.trim()),
    backHidden: document.getElementById('bond-back').classList.contains('hidden') }));
  log.notes.push({ bond1b });
  await page.screenshot({ path: path.join(SHOTS, 'bond-02-pair-step2.png') });

  await page.keyboard.press('Digit1');            // 第二步：選配對的招
  await wait(900);
  const afterPair = await page.evaluate(() => { const pl = G.Game.player; return { slots: pl.slots.map(g => g.map(m => m.id)), active: pl.active, bonds: pl.bonds, state: G.Game.state, bondOpen: G.UI.isOpen('scr-bond') }; });
  log.notes.push({ afterPair });
  await page.screenshot({ path: path.join(SHOTS, 'bond-03-after-pair.png') });

  // 第二個羈絆：應進入 add 模式（只能加進已有的組）
  await wait(900);
  const bond2 = await page.evaluate(() => ({ open: G.UI.isOpen('scr-bond'), sub: document.getElementById('bond-sub').textContent,
    cards: [...document.querySelectorAll('#bond-cards .card .nm')].map(e => e.textContent.trim()) }));
  log.notes.push({ bond2 });
  await page.screenshot({ path: path.join(SHOTS, 'bond-04-add-mode.png') });
  await page.keyboard.press('Digit1');
  await wait(900);
  const afterAdd = await page.evaluate(() => { const pl = G.Game.player; return { slots: pl.slots.map(g => g.map(m => m.id)), active: pl.active, bonds: pl.bonds, state: G.Game.state }; });
  log.notes.push({ afterAdd });
  await page.screenshot({ path: path.join(SHOTS, 'bond-05-group-hud.png') });

  // 量測：同組每招各自的施放間隔（包住 cast；用遊戲時間 G.Game.st.time）
  await page.evaluate(() => {
    const pl = G.Game.player;
    window.__casts = [];
    const orig = pl.cast.bind(pl);
    pl.cast = m => { window.__casts.push({ id: m.id, t: G.Game.st.time, wall: performance.now(), cd: m.cd, cdMul: pl.cdMul }); return orig(m); };
    window.__cdMul = pl.cdMul;
  });
  await wait(45000);
  const casts = await page.evaluate(() => ({ casts: window.__casts, time: G.Game.st.time, enemies: G.EnemyMgr.all().length, hp: G.Game.player.hp }));
  log.notes.push({ castCount: casts.casts.length, gameTime: casts.time, enemies: casts.enemies });
  const byId = {};
  for (const c of casts.casts) (byId[c.id] = byId[c.id] || []).push(c);
  log.intervals = {};
  for (const [id, arr] of Object.entries(byId)) {
    const dts = arr.slice(1).map((c, i) => +(c.t - arr[i].t).toFixed(3));
    log.intervals[id] = { n: arr.length, cdTimesMul: arr[0].cd * arr[0].cdMul, minDt: Math.min(...dts), medDt: dts.sort((a, b) => a - b)[Math.floor(dts.length / 2)] };
  }
  await page.screenshot({ path: path.join(SHOTS, 'bond-06-in-combat.png') });
} catch (e) {
  log.errors.push('script: ' + String(e).slice(0, 300));
  try { await page.screenshot({ path: path.join(SHOTS, 'bond-error.png') }); } catch (_) {}
} finally {
  fs.writeFileSync(path.join(GEN, 'observe-bond.json'), JSON.stringify(log, null, 1));
  await browser.close();
}
console.log(JSON.stringify(log, null, 1));
