import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import * as E from './engine.js';
import { getCard } from './data.js';
import { createProfile, STORAGE_KEY } from './profile.js';
import { freshCampaign, checkpoint, CAMPAIGN_KEY } from './campaign.js';

const require = createRequire(import.meta.url);
const arg = (name, fallback) => process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : fallback;
const playwright = arg('--playwright');
assert.ok(playwright, 'Pass --playwright /path/to/@playwright/test');
const { chromium } = require(playwright);
const url = arg('--url', 'http://127.0.0.1:5182');
const out = resolve(arg('--out', '/tmp/rift-battle-layout'));
await mkdir(out, { recursive: true });
const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ reducedMotion: 'reduce' });
const page = await context.newPage();
const errors = [];
const evidence = [];
page.on('pageerror', error => errors.push(error.message));
page.on('response', response => {
  if (response.status() >= 400 && !response.url().endsWith('/favicon.ico')) errors.push(`${response.status()} ${response.url()}`);
});

function fixture(enemyCount, boss, fullHand = false) {
  const profile = createProfile();
  let run;
  for (let n = 0; n < 100; n++) {
    run = E.createRun({ deck: profile.deck, characterId: profile.characterId, seed: `layout-${n}` });
    E.visitNode(run, run.map[0].find(node => node.kind === 'battle').id);
    if (run.hand.some(c => getCard(c.cardId).target === 'enemy' && getCard(c.cardId).effects.some(e => e.op === 'damage'))
      && run.hand.some(c => getCard(c.cardId).target !== 'enemy' && getCard(c.cardId).effects.some(e => e.op === 'block'))) break;
  }
  run.player.hp = 52;
  run.player.block = 12;
  run.player.strength = 3;
  run.player.charge = 2;
  run.resonance = 3;
  const template = run.enemies[0];
  run.enemies = Array.from({ length: enemyCount }, (_, i) => ({
    ...structuredClone(template), id: `layout-enemy-${i}`, name: boss ? '首領 · 版面驗證' : `敵人 ${i + 1}`,
    maxHp: boss ? 240 : 120, hp: boss ? 190 : 95 - i * 12,
    block: i === 1 ? 0 : 9 + i, poison: i === 2 ? 3 : 0,
    intent: { kind: 'attack', label: '突擊', hits: 2, amount: 5 },
  }));
  if (boss) {
    // Art selection reads the current node kind. This fixture uses a real map boss node.
    run.currentNode = run.map.flat().find(node => node.kind === 'boss');
  }
  if (fullHand) while (run.hand.length < 10 && run.draw.length) run.hand.push(run.draw.pop());
  E.assertInvariants(run);
  return { profile, campaign: checkpoint(freshCampaign(), run, 'layout-fixture', profile) };
}

async function installFixture(options = {}) {
  const value = fixture(options.enemies || 2, options.boss || false, options.fullHand || false);
  await page.goto(url);
  await page.evaluate(({ value, profileKey, campaignKey }) => {
    localStorage.clear();
    localStorage.setItem(profileKey, JSON.stringify(value.profile));
    localStorage.setItem(campaignKey, JSON.stringify(value.campaign));
  }, { value, profileKey: STORAGE_KEY, campaignKey: CAMPAIGN_KEY });
  await page.reload();
  await page.locator('[data-menu="play"]').click();
  await page.locator('[data-menu="continue"]').click();
  await page.locator('[data-battle-stage]').waitFor();
  await page.evaluate(async () => {
    await document.fonts.ready;
    const { BATTLE_ASSETS } = await import('./battle-art.js');
    const sources = Object.values(BATTLE_ASSETS).flatMap(value => typeof value === 'string' ? [value] : Object.values(value));
    await Promise.all(sources.map(src => new Promise((resolveImage, reject) => {
      const image = new Image(); image.onload = resolveImage; image.onerror = () => reject(new Error(src)); image.src = src;
    })));
  });
  return value.campaign.run;
}

const savedRun = () => page.evaluate(key => JSON.parse(localStorage.getItem(key)).run, CAMPAIGN_KEY);

async function inspect(label, run) {
  await page.mouse.move(0, 0);
  await page.screenshot({ path: `${out}/${label}.png`, fullPage: true });
  assert.equal(await page.locator('[data-enemy]').count(), run.enemies.length);
  const hero = page.locator('[data-hero-actor]');
  const subjects = [{ locator: hero, art: '.actor-art-wrap', state: run.player }, ...run.enemies.map(enemy => ({
    locator: page.locator(`[data-enemy="${enemy.id}"]`), art: '.enemy-art-wrap', state: enemy,
  }))];
  const boxes = [];
  for (const { locator, art, state } of subjects) {
    const hp = locator.locator('.combatant-hp');
    const block = locator.locator('.combatant-block');
    await hp.waitFor({ state: 'visible' });
    await block.waitFor({ state: 'visible' });
    const progress = locator.locator('[role="progressbar"]');
    assert.equal(Number(await progress.getAttribute('aria-valuenow')), state.hp);
    assert.equal(Number(await progress.getAttribute('aria-valuemax')), state.maxHp);
    assert.match((await hp.innerText()).replace(/\s/g, ''), new RegExp(`${state.hp}/${state.maxHp}`));
    assert.match(await block.innerText(), new RegExp(`\\b${state.block}\\b`));
    const hpBox = await hp.boundingBox();
    const barBox = await progress.boundingBox();
    const artBox = await locator.locator(art).boundingBox();
    assert.ok(hpBox.width >= 50 && hpBox.height > 0, `${label}: health bar has readable size`);
    assert.ok(barBox.width >= 32 && barBox.height >= 4, `${label}: health fill is a visible bar, not only a number ${JSON.stringify(barBox)}`);
    assert.ok(Math.abs(hpBox.x + hpBox.width / 2 - artBox.x - artBox.width / 2) < Math.max(artBox.width, 120), `${label}: health belongs next to its actor ${JSON.stringify({ hpBox, artBox })}`);
    assert.ok(hpBox.y >= artBox.y && hpBox.y - (artBox.y + artBox.height) < 110, `${label}: health stays near the actor feet`);
    boxes.push({ hp: hpBox, art: artBox });
  }
  for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++) {
    const a = boxes[i].hp, b = boxes[j].hp;
    assert.ok(a.x + a.width <= b.x + 1 || b.x + b.width <= a.x + 1 || a.y + a.height <= b.y + 1 || b.y + b.height <= a.y + 1, `${label}: separate health bars do not overlap`);
  }
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), `${label}: no whole-page horizontal overflow`);
  assert.ok(await page.locator('#end').isVisible(), `${label}: End Turn present`);
  const endTurn = await page.locator('#end').boundingBox();
  const viewport = page.viewportSize();
  if (viewport.width >= 1024 && viewport.height >= 650) {
    assert.ok(endTurn.y >= 0 && endTurn.y + endTurn.height <= viewport.height + 1, `${label}: desktop End Turn is in initial viewport`);
    assert.ok(boxes.every(({ hp }) => hp.y >= 0 && hp.y + hp.height <= viewport.height), `${label}: actor health stays in viewport`);
  }
  evidence.push({ label, viewport, enemies: run.enemies.length, boxes, endTurn, documentHeight: await page.evaluate(() => document.documentElement.scrollHeight) });
}

try {
  for (const item of [
    { label: 'desktop-two', width: 1440, height: 900, enemies: 2 },
    { label: 'desktop-three', width: 1440, height: 900, enemies: 3 },
    { label: 'laptop-boss', width: 1366, height: 768, enemies: 1, boss: true },
    { label: 'desktop-ten-cards', width: 1440, height: 900, enemies: 2, fullHand: true },
    { label: 'phone-portrait', width: 390, height: 844, enemies: 2 },
    { label: 'phone-landscape', width: 844, height: 390, enemies: 2 },
  ]) {
    await page.setViewportSize({ width: item.width, height: item.height });
    await inspect(item.label, await installFixture(item));
  }

  await page.setViewportSize({ width: 1440, height: 900 });
  let before = await installFixture({ enemies: 2 });
  for (const pile of ['draw', 'deck', 'discard', 'exile']) {
    await page.locator(`[data-pile="${pile}"]`).click();
    await page.locator('#modal').waitFor({ state: 'visible' });
    await page.keyboard.press('Escape');
    await page.locator('#modal').waitFor({ state: 'hidden' });
  }
  const defense = before.hand.find(c => getCard(c.cardId).target !== 'enemy' && getCard(c.cardId).effects.some(e => e.op === 'block'));
  await page.locator(`[data-play="${defense.uid}"]`).click();
  let after = await savedRun();
  assert.ok(after.player.block > before.player.block, 'defense updates block');
  assert.match(await page.locator('[data-hero-actor] .combatant-block').innerText(), new RegExp(`\\b${after.player.block}\\b`));
  before = after;
  const attack = before.hand.find(c => getCard(c.cardId).target === 'enemy' && getCard(c.cardId).cost <= before.energy && getCard(c.cardId).effects.some(e => e.op === 'damage'));
  assert.ok(attack, 'fixture contains affordable targeted attack');
  assert.equal(await page.locator('#empower').isDisabled(), false, 'existing resonance action remains available');
  await page.locator('#empower').click();
  await page.locator(`[data-play="${attack.uid}"]`).click();
  await page.locator(`[data-enemy="${before.enemies[0].id}"]`).click();
  after = await savedRun();
  assert.ok(after.enemies[0].hp + after.enemies[0].block < before.enemies[0].hp + before.enemies[0].block, 'targeted damage updates selected enemy');
  assert.equal(after.metrics.empowered, before.metrics.empowered + 1, 'existing empowerment still resolves');
  const potion = after.potions.find(item => item.potionId === 'venom_flask');
  assert.ok(potion, 'fixture has a targeted consumable');
  const potionTarget = after.enemies[1];
  await page.locator(`[data-potion="${potion.uid}"]`).click();
  await page.locator(`[data-enemy="${potionTarget.id}"]`).click();
  after = await savedRun();
  assert.ok(after.enemies[1].poison > potionTarget.poison, 'consumable still targets its enemy');
  assert.ok(!after.potions.some(item => item.uid === potion.uid), 'consumable removed once');
  await page.locator('#end').click();
  after = await savedRun();
  assert.equal(after.turn, before.turn + 1, 'End Turn advances battle');
  await inspect('desktop-after-turn', after);
  await page.reload();
  await page.locator('[data-menu="play"]').click();
  await page.locator('[data-menu="continue"]').click();
  assert.deepEqual(await savedRun(), after, 'reload continues identical battle state');
  assert.deepEqual(errors, [], 'no browser or asset errors');
  await writeFile(`${out}/evidence.json`, JSON.stringify({ passed: true, evidence, checks: ['actor-local HP/block', 'non-overlapping health bars', '1-3 enemies and boss', '10-card hand', 'desktop and mobile', 'pile dialogs and Escape', 'targeted attack', 'block updates', 'resonance empowerment', 'targeted consumable', 'end turn', 'reload continuation'] }, null, 2));
  console.log(JSON.stringify({ passed: true, screenshots: out, scenarios: evidence.map(item => item.label) }));
} finally { await browser.close(); }
