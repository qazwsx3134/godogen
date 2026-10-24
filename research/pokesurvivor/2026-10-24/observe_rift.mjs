// 實玩觀察 2：自然取得羈絆的完整流程（裂縫競技場 → 打倒傳說 → 5 s 結算 → 回原地 → 彈出羈絆選擇），
// 並量「固定配置下的持續輸出」：單招 vs 4 招羈絆組。
// 條件（報告裡照實寫）：本機 dev.html、所有非本機請求被擋；主角血量設 99999（量輸出，不量存活）；
// 局內時間設 105 s（第一次裂縫擲骰的最早時間）；遊戲速度 ×2（dt=1/30 s，等同 30 fps 用戶端）；
// 用 G.Rift.debugArena(type) 進場（等同走進裂縫、略過走路），並在呼叫瞬間把 Math.random 固定，使傳說可重現。
// 用法：先 `python3 -m http.server 8799 --bind 127.0.0.1 --directory upstream`，再 `node observe_rift.mjs [trial ...]`
// 輸出：screenshots/rift-*.png、generated/observe-rift.json（兩者皆被 .gitignore 排除）
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
const wait = ms => new Promise(r => setTimeout(r, ms));

const TRIALS = {
  // randomPick：debugArena 期間 Math.random 的固定值；rock 池＝[Regirock, Terrakion, Diancie]，0.5→Terrakion（近戰型），0.99→Diancie（遠程型）
  single: { kit: 'single', type: 'rock', randomPick: 0.5 },
  group4: { kit: 'group4', type: 'rock', randomPick: 0.5 },
  'single-ranged': { kit: 'single', type: 'rock', randomPick: 0.99 },
  'group4-ranged': { kit: 'group4', type: 'rock', randomPick: 0.99 },
};
const wanted = process.argv.slice(2).length ? process.argv.slice(2) : ['single', 'group4'];

const browser = await chromium.launch({
  executablePath: '/Users/peter/Library/Caches/ms-playwright/chromium-1243/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing',
  headless: true,
});

async function newPage(rec) {
  const ctx = await browser.newContext({ viewport: { width: 1100, height: 700 }, serviceWorkers: 'block' });
  await ctx.route('**/*', route => {
    const u = route.request().url();
    if (u.startsWith(BASE) || u.startsWith('data:') || u.startsWith('blob:')) return route.continue();
    rec.blocked.add(u.slice(0, 80));
    return route.abort();
  });
  const page = await ctx.newPage();
  page.on('pageerror', e => rec.errors.push('pageerror: ' + String(e).slice(0, 200)));
  page.on('console', m => { if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) rec.errors.push('console.error: ' + m.text().slice(0, 200)); });
  return { ctx, page };
}

async function boot(page) {
  await page.goto(BASE + 'dev.html?dev', { waitUntil: 'load' });
  await page.waitForFunction(() => window.G && G.Flow && G.DB && G.Game, null, { timeout: 30000 });
  await wait(2500);
  await page.evaluate(() => { const el = document.getElementById('tap-start'); if (el && !el.classList.contains('hidden')) el.click(); });
  await wait(400);
  await page.evaluate(() => {
    document.getElementById('btn-guest').click();
    const s = G.DB.save;
    if (!s.partner) { s.starter = 4; s.partner = 4; G.DB.grant(4, 'starter'); G.Flow.goMenu(); }
    G.Flow.play();
  });
  await wait(1200);
}

const snap = page => page.evaluate(() => {
  const a = G.Rift.arena, pl = G.Game.player;
  const boss = a ? G.EnemyMgr.get(a.bossId) : null;
  return {
    inArena: G.Rift.inArena, phase: a ? a.phase : null, at: a ? +a.t.toFixed(2) : null,
    bossHp: boss ? Math.round(boss.hp) : null, bossMax: boss ? Math.round(boss.maxHp) : null,
    dist: boss ? Math.round(Math.hypot(boss.x - pl.x, boss.y - pl.y)) : null, md: pl.moves.map(m => [m.id, Math.round(m.dealt || 0)]),
    dealt: Math.round(pl.dmgDealt), hp: Math.round(pl.hp), gt: +G.Game.st.time.toFixed(2), state: G.Game.state, bonds: pl.bonds, level: pl.level,
    slots: pl.slots.map(g => g.map(m => m.id)), bondOpen: G.UI.isOpen('scr-bond'), lvlOpen: G.UI.isOpen('scr-levelup'),
  };
});

async function handleBond(page, rec, label) {
  const step = async name => {
    const s = await page.evaluate(() => ({
      sub: document.getElementById('bond-sub').textContent,
      cards: [...document.querySelectorAll('#bond-cards .card .nm')].map(e => e.textContent.trim()),
      backHidden: document.getElementById('bond-back').classList.contains('hidden'),
    }));
    rec.bondUi.push({ name, ...s });
    await page.screenshot({ path: path.join(SHOTS, `rift-${label}-${name}.png`) });
    return s;
  };
  await wait(900);                       // 0.6 s 防誤觸鎖
  const s1 = await step('bond-step1');
  await page.keyboard.press('Digit1');
  await wait(700);
  const open = await page.evaluate(() => G.UI.isOpen('scr-bond'));
  if (open) {
    await step('bond-step2');
    await page.keyboard.press('Digit1');
    await wait(900);
  }
  rec.afterBond = await snap(page);
  await page.screenshot({ path: path.join(SHOTS, `rift-${label}-after-bond.png`) });
  return s1;
}

async function runTrial(label) {
  const cfg = TRIALS[label];
  const rec = { label, cfg, series: [], bondUi: [], errors: [], blocked: new Set(), notes: [] };
  const { ctx, page } = await newPage(rec);
  try {
    await boot(page);
    rec.setup = await page.evaluate(({ kit, type, randomPick }) => {
      const pl = G.Game.player;
      const baseHp = pl.maxHp;
      pl.maxHp = pl.hp = 99999;
      window.__hits = [];
      const oh = pl.hurt.bind(pl);
      pl.hurt = (amount, type = null, pure = false, cat = null) => {
        const b = pl.hp; oh(amount, type, pure, cat);
        const d = b - pl.hp;
        if (d > 0) window.__hits.push([+G.Game.st.time.toFixed(2), +d.toFixed(1), type]);
      };
      G.Game.debugTime(105);
      G.Game.debugSpeed(2);
      if (kit === 'group4') {
        for (const id of ['flamethrower', 'fire-spin', 'heat-wave']) pl.addMove(id);
        const by = id => pl.moves.find(m => m.id === id);
        pl.bonds = 3;
        const g = pl.fuse([by('ember'), by('flamethrower')]);          // 配對
        pl.fuse([by('fire-spin')], g);                                   // 加入
        pl.fuse([by('heat-wave')], g);                                   // 加入 → 4 招滿組
        for (const id of ['tackle', 'flame-wheel', 'will-o-wisp']) pl.addMove(id);   // 另 3 個單獨格
      }
      const orig = Math.random;
      Math.random = () => randomPick;
      try { G.Rift.debugArena(type); } finally { Math.random = orig; }
      const a = G.Rift.arena, boss = G.EnemyMgr.get(a.bossId);
      return {
        slots: pl.slots.map(g => g.map(m => m.id)), active: pl.active, bonds: pl.bonds,
        legend: boss && { name: boss.name, dex: boss.dex, hp: boss.hp, maxHp: boss.maxHp, behavior: boss.behavior, dmg: boss.dmg },
        arena: { type: a.type, phase: a.phase }, gt: G.Game.st.time,
        moveStats: pl.moves.map(m => ({ id: m.id, lvl: m.lvl, kind: m.kind, cd: m.cd, dmg: m.dmg })),
        atk: pl.atk, baseHp, reduction: pl.reduction,
      };
    }, cfg);
    await wait(500);

    const t0 = Date.now();
    let shotFight = false, bondDone = false, wonSeen = null, lvlPresses = 0;
    while (Date.now() - t0 < 220000) {
      await wait(1000);
      const s = await snap(page);
      rec.series.push(s);
      if (!shotFight && s.at > 25) { shotFight = true; await page.screenshot({ path: path.join(SHOTS, `rift-${label}-fight.png`) }); }
      if (s.phase === 'won' && !wonSeen) wonSeen = s;
      if (s.lvlOpen) { await page.keyboard.press('Digit1'); lvlPresses++; continue; }
      if (s.bondOpen && !bondDone) { bondDone = true; rec.bondFirstSeen = s; await handleBond(page, rec, label); break; }
      if (!s.inArena && s.phase === null && rec.series.length > 3) {
        // 離開競技場；若有羈絆但沒彈出（無解）就再等一下
        await wait(1500);
        const s2 = await snap(page);
        rec.afterArena = s2;
        if (s2.bondOpen && !bondDone) { bondDone = true; await handleBond(page, rec, label); }
        else await page.screenshot({ path: path.join(SHOTS, `rift-${label}-after-arena.png`) });
        break;
      }
    }
    rec.hits = await page.evaluate(() => window.__hits || []);
    rec.levelUpPresses = lvlPresses;
    rec.wonSeen = wonSeen;
    rec.final = await snap(page);
    // 結算：被打的紀錄（只算 pl.hurt；進場後的遊戲時間 gt0 = 105）
    {
      const fightStart = rec.setup ? rec.setup.gt : 105;
      const hs = rec.hits.filter(h => h[0] >= fightStart);
      let cum = 0, t88 = null;
      for (const h of hs) { cum += h[1]; if (t88 == null && cum >= (rec.setup ? rec.setup.baseHp : 88)) t88 = +(h[0] - fightStart).toFixed(1); }
      const types = {};
      for (const h of hs) types[h[2] || 'null'] = (types[h[2] || 'null'] || 0) + 1;
      rec.hitSummary = { count: hs.length, total: +cum.toFixed(1), firstHitAfter: hs.length ? +(hs[0][0] - fightStart).toFixed(1) : null,
                         secondsToLoseBaseHp: t88, byType: types, avgPerHit: hs.length ? +(cum / hs.length).toFixed(1) : null };
    }
    // 結算：輸出曲線
    const fight = rec.series.filter(s => s.phase === 'fight' && s.at != null);
    if (fight.length > 2) {
      const a = fight[0], b = fight[fight.length - 1];
      rec.summary = {
        fightSamples: fight.length, arenaTimeFirst: a.at, arenaTimeLast: b.at,
        dealtDelta: b.dealt - a.dealt,
        avgDps: +((b.dealt - a.dealt) / Math.max(0.1, b.at - a.at)).toFixed(1),
        bossHpFirst: a.bossHp, bossHpLast: b.bossHp, bossMax: a.bossMax,
        bossLostPct: a.bossMax ? +(100 * (a.bossHp - b.bossHp) / a.bossMax).toFixed(1) : null,
        distAvg: +(fight.filter(x => x.dist != null).reduce((t, x) => t + x.dist, 0) / Math.max(1, fight.filter(x => x.dist != null).length)).toFixed(0),
        distMin: Math.min(...fight.filter(x => x.dist != null).map(x => x.dist)), distMax: Math.max(...fight.filter(x => x.dist != null).map(x => x.dist)),
        moveDealt: Object.fromEntries(b.md), moveDealtShare: (() => { const tot = b.md.reduce((t, [, v]) => t + v, 0) || 1; return Object.fromEntries(b.md.map(([id, v]) => [id, +(100 * v / tot).toFixed(1)])); })(),
        hpDpsBoss: +((a.bossHp - b.bossHp) / Math.max(0.1, b.at - a.at)).toFixed(1),
        intakePerSec: +((a.hp - b.hp) / Math.max(0.1, b.at - a.at)).toFixed(1), hpLost: a.hp - b.hp,
        // 前 20 秒／後 20 秒各一段，看輸出是否穩定
        dps20: (() => {
          const early = fight.filter(s => s.at <= a.at + 20), last = fight.filter(s => s.at >= b.at - 20);
          const f = arr => arr.length > 1 ? +((arr[arr.length - 1].dealt - arr[0].dealt) / Math.max(0.1, arr[arr.length - 1].at - arr[0].at)).toFixed(1) : null;
          return { early: f(early), late: f(last) };
        })(),
      };
    }
  } catch (e) {
    rec.errors.push('script: ' + String(e).slice(0, 300));
    try { await page.screenshot({ path: path.join(SHOTS, `rift-${label}-error.png`) }); } catch (_) {}
  } finally {
    await ctx.close();
  }
  rec.blocked = [...rec.blocked];
  return rec;
}

let out = {};
try { out = JSON.parse(fs.readFileSync(path.join(GEN, 'observe-rift.json'), 'utf8')); } catch (_) {}
try {
  for (const label of wanted) {
    if (!TRIALS[label]) { console.error('unknown trial', label); continue; }
    console.error('running', label);
    out[label] = await runTrial(label);
    fs.writeFileSync(path.join(GEN, 'observe-rift.json'), JSON.stringify(out, null, 1));   // 每跑完一個就存，避免中途中斷全丟
  }
} finally {
  await browser.close();
}
const brief = Object.fromEntries(Object.entries(out).filter(([k]) => wanted.includes(k)).map(([k, v]) => [k, { setup: v.setup && { slots: v.setup.slots, legend: v.setup.legend, atk: v.setup.atk, baseHp: v.setup.baseHp, reduction: v.setup.reduction }, summary: v.summary, hitSummary: v.hitSummary, wonSeen: v.wonSeen && { at: v.wonSeen.at, gt: v.wonSeen.gt }, bondUi: v.bondUi, afterBond: v.afterBond && { slots: v.afterBond.slots, bonds: v.afterBond.bonds, state: v.afterBond.state }, afterArena: v.afterArena && { bonds: v.afterArena.bonds, bondOpen: v.afterArena.bondOpen, slots: v.afterArena.slots }, levelUpPresses: v.levelUpPresses, errors: v.errors }]));
console.log(JSON.stringify(brief, null, 1));
