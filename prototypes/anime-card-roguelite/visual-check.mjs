import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { createProfile, applyCharacter, grantCard, setLoadout, STORAGE_KEY } from './profile.js';
import * as E from './engine.js';
import { CAMPAIGN_KEY } from './campaign.js';
import { CHARACTERS, getCard } from './data.js';
const require = createRequire(import.meta.url);
const arg = name => process.argv[process.argv.indexOf(name) + 1];
const { chromium } = require(arg('--playwright'));
const url = process.argv.includes('--url') ? arg('--url') : 'http://127.0.0.1:5178';
const out = '/tmp/rift-visual-browser-v2';
await mkdir(out, { recursive: true });
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
const errors = [];
page.on('pageerror', e => errors.push(e.message));
page.on('response', r => { if (r.status() >= 400) errors.push(`${r.status()} ${r.url()}`); });
try {
  for (const [cardId, selector] of [['sarcastic_counter', '.counter-cameo'], ['kame_wave', '.widebeam-fx']]) {
    const profile = createProfile();
    applyCharacter(profile, 'silver_ronin');
    grantCard(profile, cardId);
    const deck = [...profile.deck]; deck[0] = cardId;
    assert.equal(setLoadout(profile, deck, []).ok, true);
    let seed, run, node;
    for (let n = 0; n < 100; n++) {
      seed = `visual-${cardId}-${n}`;
      run = E.createRun({ deck, seed, characterId: 'silver_ronin' });
      node = run.map[0].find(n => n.kind === 'battle');
      E.visitNode(run, node.id);
      if (run.hand.some(c => c.cardId === cardId)) break;
    }
    await page.goto(url);
    await page.evaluate(({ key, profile }) => localStorage.setItem(key, JSON.stringify(profile)), { key: STORAGE_KEY, profile });
    await page.evaluate(key=>{localStorage.removeItem(key);localStorage.removeItem(key+'.bak');},CAMPAIGN_KEY);
    await page.reload();
    await page.locator('[data-menu="play"]').click();await page.locator('[data-menu="new"]').click();await page.locator('[data-menu="choose-character"]').click();
    await page.locator('#seed').fill(seed);
    await page.locator('#start').click();
    await page.locator(`[data-node="${node.id}"]`).click();
    await page.evaluate(async () => {
      const { BATTLE_ASSETS } = await import('./battle-art.js');
      const paths = Object.values(BATTLE_ASSETS).flatMap(v => typeof v === 'string' ? [v] : Object.values(v));
      await Promise.all(paths.map(src => new Promise((resolve, reject) => {
        const img = new Image(); img.onload = () => img.naturalWidth ? resolve() : reject(new Error(src)); img.onerror = () => reject(new Error(src)); img.src = src;
      })));
    });
    const hero = await page.locator('.actor-art-wrap').boundingBox();
    const enemy = await page.locator('.enemy-art-wrap').first().boundingBox();
    assert.ok(hero.x + hero.width < enemy.x, 'actors face across a horizontal stage');
    assert.ok(Math.abs(hero.width - hero.height) < 1, 'hero preserves sprite aspect ratio');
    assert.ok(Math.abs(enemy.width - enemy.height) < 1, 'enemy preserves sprite aspect ratio');
    await page.mouse.move(0, 0);
    await page.screenshot({ path: `${out}/battle.png`, fullPage: true });
    const instance = run.hand.find(c => c.cardId === cardId);
    await page.locator(`[data-play="${instance.uid}"]`).click();
    await page.locator(selector).waitFor({ state: 'attached' });
    assert.ok((await page.locator(selector).boundingBox()).width > 0);
    await page.waitForTimeout(140);
    await page.screenshot({ path: `${out}/${cardId}.png`, fullPage: true });
    await page.waitForTimeout(950);
    assert.equal(await page.locator(selector).count(), 0, 'transient animation cleans up');
  }
  for (const character of CHARACTERS) {
    const profile = createProfile(); applyCharacter(profile, character.id);
    let run, seed, node, instance;
    for (let n = 0; n < 100; n++) {
      seed = `motion-${character.id}-${n}`;
      run = E.createRun({deck:profile.deck, seed, characterId:character.id});
      node = run.map[0].find(n => n.kind === 'battle'); E.visitNode(run,node.id);
      instance = run.hand.find(c => getCard(c.cardId).effects.some(e => e.op === 'damage') && getCard(c.cardId).cost <= 3);
      if (instance && run.enemies.some(e => e.intent.kind === 'attack')) break;
    }
    await page.goto(url);
    await page.evaluate(({key,profile}) => localStorage.setItem(key,JSON.stringify(profile)),{key:STORAGE_KEY,profile});
    await page.evaluate(key=>{localStorage.removeItem(key);localStorage.removeItem(key+'.bak');},CAMPAIGN_KEY);
    await page.reload();
    await page.locator('[data-menu="play"]').click();await page.locator('[data-menu="new"]').click();await page.locator('[data-menu="choose-character"]').click();
    await page.screenshot({path:`${out}/home-${character.id}.png`,fullPage:true});
    await page.locator('#seed').fill(seed); await page.locator('#start').click();
    await page.locator(`[data-node="${node.id}"]`).click();
    await page.mouse.move(0,0);
    const stageBounds = await page.locator('[data-battle-stage]').boundingBox();
    for (const label of await page.locator('.actor-stats, .battle-stage .enemy-stats').all()) {
      const bounds = await label.boundingBox();
      assert.ok(bounds.y + bounds.height <= stageBounds.y + stageBounds.height, 'battle status stays inside stage');
    }
    const handBounds = await page.locator('.hand-scroll').boundingBox();
    assert.ok(handBounds.y + handBounds.height <= 900, 'desktop hand fits viewport');
    await page.screenshot({path:`${out}/stage-${character.id}.png`,fullPage:true});
    const def = getCard(instance.cardId);
    await page.locator(`[data-play="${instance.uid}"]`).click();
    if(def.target==='enemy') await page.locator('[data-enemy]').first().click();
    const sprite = page.locator('.actor-art-wrap .hero-sprite');
    await page.locator('[data-action="attack"]').waitFor({state:'attached'});
    assert.match(await sprite.getAttribute('style'),new RegExp(`hero-${character.id}-attack`));
    await page.waitForTimeout(310);
    await page.screenshot({path:`${out}/attack-${character.id}.png`,fullPage:true});
    await page.waitForTimeout(650);
    assert.equal(await sprite.getAttribute('data-action'),null);
    await page.locator('#end').click();
    await page.locator('[data-action="hurt"]').waitFor({state:'attached'});
    assert.match(await sprite.getAttribute('style'),new RegExp(`hero-${character.id}-hurt`));
    await page.waitForTimeout(220);
    await page.screenshot({path:`${out}/hurt-${character.id}.png`,fullPage:true});
    await page.waitForTimeout(650);
    assert.equal(await sprite.getAttribute('data-action'),null);
  }
  for (const [width, height] of [[390, 844], [844, 390]]) {
    await page.setViewportSize({ width, height });
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'no page overflow');
    await page.screenshot({ path: `${out}/battle-${width}.png`, fullPage: true });
  }
  await page.emulateMedia({ reducedMotion: 'reduce' });
  assert.equal(await page.locator('.actor-art-wrap .hero-sprite').evaluate(el => getComputedStyle(el).animationName), 'none');
  assert.deepEqual(errors, []);
  console.log(JSON.stringify({ passed: true, checks: ['runtime images decode', 'square sprites', 'horizontal stage', 'real cameo card', 'real beam card', 'three heroes attack and hurt sheets', 'effect cleanup', 'mobile portrait and landscape', 'reduced motion'], screenshots: out }));
} finally { await browser.close(); }
