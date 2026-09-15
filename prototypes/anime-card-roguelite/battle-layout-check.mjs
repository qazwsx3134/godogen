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
const touchContext = await browser.newContext({
  hasTouch: true,
  isMobile: true,
  viewport: { width: 390, height: 844 },
  reducedMotion: 'reduce',
});
const touchPage = await touchContext.newPage();
const errors = [];
const evidence = [];

function watchPage(targetPage) {
  targetPage.on('pageerror', error => errors.push(error.message));
  targetPage.on('console', message => {
    if (message.type() === 'error') errors.push(`console.error: ${message.text()}`);
  });
  targetPage.on('response', response => {
    if (response.status() >= 400 && !response.url().endsWith('/favicon.ico')) errors.push(`${response.status()} ${response.url()}`);
  });
}

watchPage(page);
watchPage(touchPage);

const TOUCH_TARGET_MIN = 44;
const MOBILE_READABLE_TEXT_MIN = 12;
const edgeBox = box => box && ({ ...box, right: box.x + box.width, bottom: box.y + box.height });

function assertInViewport(box, viewport, label) {
  const value = edgeBox(box);
  assert.ok(value && value.width > 0 && value.height > 0, `${label}: visible non-empty box required ${JSON.stringify(value)}`);
  assert.ok(value.x >= -1 && value.y >= -1 && value.right <= viewport.width + 1 && value.bottom <= viewport.height + 1,
    `${label}: box must stay in the viewport ${JSON.stringify({ box: value, viewport })}`);
}

function assertInside(innerBox, outerBox, label) {
  const inner = edgeBox(innerBox);
  const outer = edgeBox(outerBox);
  assert.ok(inner && outer, `${label}: both boxes are required`);
  assert.ok(inner.x >= outer.x - 1 && inner.y >= outer.y - 1 && inner.right <= outer.right + 1 && inner.bottom <= outer.bottom + 1,
    `${label}: content is clipped by its container ${JSON.stringify({ inner, outer })}`);
}

async function documentGeometry(targetPage) {
  return targetPage.evaluate(() => {
    const root = document.documentElement;
    const body = document.body;
    const view = document.querySelector('.view-root');
    const rect = element => {
      if (!element) return null;
      const box = element.getBoundingClientRect();
      return { x: box.x, y: box.y, width: box.width, height: box.height, right: box.right, bottom: box.bottom };
    };
    return {
      scrollX: window.scrollX,
      scrollY: window.scrollY,
      root: { scrollWidth: root.scrollWidth, scrollHeight: root.scrollHeight, clientWidth: root.clientWidth, clientHeight: root.clientHeight },
      body: { scrollWidth: body.scrollWidth, scrollHeight: body.scrollHeight, clientWidth: body.clientWidth, clientHeight: body.clientHeight },
      view: view ? { ...rect(view), scrollWidth: view.scrollWidth, scrollHeight: view.scrollHeight, clientWidth: view.clientWidth, clientHeight: view.clientHeight, scrollTop: view.scrollTop, scrollLeft: view.scrollLeft } : null,
      shell: rect(document.querySelector('.shell')),
    };
  });
}

async function assertNoDocumentScroll(targetPage, label) {
  const geometry = await documentGeometry(targetPage);
  const viewport = targetPage.viewportSize();
  assert.equal(geometry.scrollX, 0, `${label}: document x scroll must remain zero`);
  assert.equal(geometry.scrollY, 0, `${label}: document y scroll must remain zero`);
  assert.ok(geometry.root.scrollWidth <= viewport.width + 1, `${label}: document has horizontal overflow ${JSON.stringify(geometry)}`);
  assert.ok(geometry.root.scrollHeight <= viewport.height + 1, `${label}: document has vertical overflow ${JSON.stringify(geometry)}`);
  assert.ok(geometry.body.scrollWidth <= viewport.width + 1, `${label}: body has horizontal overflow ${JSON.stringify(geometry)}`);
  assert.ok(geometry.body.scrollHeight <= viewport.height + 1, `${label}: body has vertical overflow ${JSON.stringify(geometry)}`);
  return geometry;
}

async function inspectElement(targetPage, locator, label, { viewport = targetPage.viewportSize(), hitTest = true } = {}) {
  await locator.waitFor({ state: 'visible' });
  const box = await locator.boundingBox();
  assertInViewport(box, viewport, label);
  const clipping = await locator.evaluate(element => {
    const rect = element.getBoundingClientRect();
    const clip = { left: 0, top: 0, right: window.innerWidth, bottom: window.innerHeight };
    const clips = [];
    for (let parent = element.parentElement; parent; parent = parent.parentElement) {
      const style = getComputedStyle(parent);
      const clipsX = ['hidden', 'clip', 'scroll', 'auto'].includes(style.overflowX);
      const clipsY = ['hidden', 'clip', 'scroll', 'auto'].includes(style.overflowY);
      if (!clipsX && !clipsY) continue;
      const parentRect = parent.getBoundingClientRect();
      clips.push({ tag: parent.tagName, id: parent.id || '', className: parent.className || '', overflowX: style.overflowX, overflowY: style.overflowY, rect: { x: parentRect.x, y: parentRect.y, right: parentRect.right, bottom: parentRect.bottom } });
      if (clipsX) { clip.left = Math.max(clip.left, parentRect.left); clip.right = Math.min(clip.right, parentRect.right); }
      if (clipsY) { clip.top = Math.max(clip.top, parentRect.top); clip.bottom = Math.min(clip.bottom, parentRect.bottom); }
    }
    return {
      rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height, right: rect.right, bottom: rect.bottom },
      clip,
      clips,
      fullyInsideClip: rect.left >= clip.left - 1 && rect.top >= clip.top - 1 && rect.right <= clip.right + 1 && rect.bottom <= clip.bottom + 1,
    };
  });
  assert.ok(clipping.fullyInsideClip, `${label}: actual content is clipped by an overflow ancestor ${JSON.stringify(clipping)}`);
  if (hitTest) {
    const point = { x: box.x + box.width / 2, y: box.y + box.height / 2 };
    const hit = await locator.evaluate((element, point) => {
      const node = document.elementFromPoint(point.x, point.y);
      return {
        contained: Boolean(node && (node === element || element.contains(node))),
        node: node ? { tag: node.tagName, id: node.id || '', className: node.className || '' } : null,
      };
    }, point);
    assert.ok(hit.contained, `${label}: center is occluded or pointer-intercepted ${JSON.stringify({ point, hit })}`);
  }
  return { box: edgeBox(box), clipping };
}

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

async function installFixture(targetPage = page, options = {}) {
  const value = fixture(options.enemies || 2, options.boss || false, options.fullHand || false);
  await targetPage.goto(url);
  await targetPage.evaluate(({ value, profileKey, campaignKey }) => {
    localStorage.clear();
    localStorage.setItem(profileKey, JSON.stringify(value.profile));
    localStorage.setItem(campaignKey, JSON.stringify(value.campaign));
  }, { value, profileKey: STORAGE_KEY, campaignKey: CAMPAIGN_KEY });
  await targetPage.reload();
  await targetPage.locator('[data-menu="play"]').click();
  await targetPage.locator('[data-menu="continue"]').click();
  await targetPage.locator('[data-battle-stage]').waitFor();
  await targetPage.evaluate(async () => {
    await document.fonts.ready;
    const { BATTLE_ASSETS } = await import('./battle-art.js');
    const sources = Object.values(BATTLE_ASSETS).flatMap(value => typeof value === 'string' ? [value] : Object.values(value));
    await Promise.all(sources.map(src => new Promise((resolveImage, reject) => {
      const image = new Image(); image.onload = resolveImage; image.onerror = () => reject(new Error(src)); image.src = src;
    })));
  });
  return value.campaign.run;
}

const savedRun = (targetPage = page) => targetPage.evaluate(key => JSON.parse(localStorage.getItem(key)).run, CAMPAIGN_KEY);

const PRIMARY_TOUCH_SELECTORS = ['#end', '[data-battle-overlay]', '[data-play]', '[data-enemy]', '[data-pile]', '#empower', '[data-potion]'];

async function assertTargetSizes(targetPage, label, selectors) {
  const metrics = [];
  for (const selector of selectors) {
    const locator = targetPage.locator(selector);
    const count = await locator.count();
    assert.ok(count > 0, `${label}: expected touch target ${selector}`);
    const boxes = await locator.evaluateAll(nodes => nodes.map(element => {
      const box = element.getBoundingClientRect();
      return { width: box.width, height: box.height, x: box.x, y: box.y, disabled: element.disabled === true };
    }));
    for (const box of boxes) {
      assert.ok(box.width >= TOUCH_TARGET_MIN && box.height >= TOUCH_TARGET_MIN,
        `${label}: ${selector} target is smaller than ${TOUCH_TARGET_MIN}px ${JSON.stringify(box)}`);
    }
    metrics.push({ selector, count, boxes });
  }
  return metrics;
}

async function assertMobileReadability(targetPage, label) {
  const requirements = [
    ['hero HP text', '[data-hero-actor] .combatant-hp-value'],
    ['hero block text', '[data-hero-actor] .combatant-block'],
    ['enemy HP text', '[data-enemy] .combatant-hp-value'],
    ['enemy block text', '[data-enemy] .combatant-block'],
    ['enemy intent text', '[data-enemy] .enemy-intent-bubble'],
    ['card effect text', '[data-play] .desc'],
  ];
  const metrics = [];
  for (const [name, selector] of requirements) {
    const locator = targetPage.locator(selector);
    const count = await locator.count();
    assert.ok(count > 0, `${label}: ${name} is missing`);
    const sizes = await locator.evaluateAll(nodes => nodes.map(element => ({
      fontSize: Number.parseFloat(getComputedStyle(element).fontSize),
      lineHeight: getComputedStyle(element).lineHeight,
      text: element.textContent?.trim() || '',
    })));
    for (const size of sizes) {
      assert.ok(size.fontSize >= MOBILE_READABLE_TEXT_MIN,
        `${label}: ${name} must be at least ${MOBILE_READABLE_TEXT_MIN}px ${JSON.stringify(size)}`);
    }
    metrics.push({ name, selector, count, sizes });
  }
  return metrics;
}

async function inspectCardSurface(targetPage, locator, label) {
  const inspected = await inspectElement(targetPage, locator, label);
  const content = await locator.evaluate(element => {
    const rect = element.getBoundingClientRect();
    const textRects = [...element.querySelectorAll('strong, .desc, .card-status')].map(node => {
      const box = node.getBoundingClientRect();
      return { selector: node.className || node.tagName, x: box.x, y: box.y, width: box.width, height: box.height, right: box.right, bottom: box.bottom, text: node.textContent?.trim() || '' };
    });
    return {
      scrollWidth: element.scrollWidth,
      scrollHeight: element.scrollHeight,
      clientWidth: element.clientWidth,
      clientHeight: element.clientHeight,
      textRects,
      cardRect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height, right: rect.right, bottom: rect.bottom },
    };
  });
  assert.ok(content.scrollWidth <= content.clientWidth + 1, `${label}: card content has hidden horizontal overflow ${JSON.stringify(content)}`);
  assert.ok(content.scrollHeight <= content.clientHeight + 1, `${label}: card content is clipped by overflow:hidden ${JSON.stringify(content)}`);
  for (const textBox of content.textRects) assertInside(textBox, content.cardRect, `${label}: ${textBox.selector} text`);
  return { ...inspected, content };
}

async function focusCardWithKeyboard(targetPage, uid) {
  const firstNavigationControl = targetPage.locator('[data-battle-overlay]').first();
  await firstNavigationControl.focus();
  let found = false;
  for (let index = 0; index < 100; index++) {
    found = await targetPage.evaluate(value => document.activeElement?.dataset?.play === value, uid);
    if (found) break;
    await targetPage.keyboard.press('Tab');
  }
  assert.ok(found, `keyboard focus should reach card ${uid}`);
}

async function checkCardPreview(targetPage, run, label = 'desktop-ten-cards') {
  const cards = targetPage.locator('[data-play]');
  assert.equal(await cards.count(), run.hand.length, `${label}: every hand card has a playable control`);
  const affordable = run.hand.find(instance => {
    const item = getCard(instance.cardId, instance.upgraded || 0);
    return item && item.cost <= run.energy;
  });
  assert.ok(affordable, `${label}: fixture contains an affordable card for hover/focus checks`);
  const card = targetPage.locator(`[data-play="${affordable.uid}"]`);
  const initial = await savedRun(targetPage);

  for (const [name, candidate] of [['first', cards.first()], ['last', cards.last()]]) {
    await candidate.scrollIntoViewIfNeeded();
    await inspectCardSurface(targetPage, candidate, `${label}: ${name} card is fully reachable`);
  }

  await card.scrollIntoViewIfNeeded();
  const normal = await card.evaluate(element => {
    const rect = element.getBoundingClientRect();
    return { rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }, transform: getComputedStyle(element).transform };
  });
  await card.hover();
  const hovered = await card.evaluate(element => {
    const rect = element.getBoundingClientRect();
    return { rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }, transform: getComputedStyle(element).transform };
  });
  assert.notEqual(hovered.transform, 'none', `${label}: hover must transform the card`);
  assert.ok(hovered.rect.width > normal.rect.width + 1 && hovered.rect.height > normal.rect.height + 1,
    `${label}: hover must visibly scale the card ${JSON.stringify({ normal, hovered })}`);
  assert.ok(hovered.rect.y < normal.rect.y - 1, `${label}: hover must lift the card ${JSON.stringify({ normal, hovered })}`);
  await inspectCardSurface(targetPage, card, `${label}: hovered card`);
  await targetPage.screenshot({ path: `${out}/${label}-card-hover.png` });
  assert.deepEqual(await savedRun(targetPage), initial, `${label}: hover preview must not mutate the run`);

  await targetPage.mouse.move(1, 1);
  await focusCardWithKeyboard(targetPage, affordable.uid);
  const focused = await card.evaluate(element => {
    const rect = element.getBoundingClientRect();
    return { rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }, transform: getComputedStyle(element).transform };
  });
  assert.notEqual(focused.transform, 'none', `${label}: keyboard focus must transform the card`);
  assert.ok(focused.rect.width > normal.rect.width + 1 && focused.rect.height > normal.rect.height + 1,
    `${label}: focus must visibly scale the card ${JSON.stringify({ normal, focused })}`);
  assert.ok(focused.rect.y < normal.rect.y - 1, `${label}: focus must lift the card ${JSON.stringify({ normal, focused })}`);
  await inspectCardSurface(targetPage, card, `${label}: focused card`);
  await targetPage.screenshot({ path: `${out}/${label}-card-focus.png` });
  await card.click({ trial: true });
  assert.deepEqual(await savedRun(targetPage), initial, `${label}: hover/focus/actionability checks must not mutate the run`);

  const enemy = targetPage.locator('[data-enemy]').first();
  await inspectElement(targetPage, enemy, `${label}: enemy remains pointer reachable after card preview`);
  const geometry = await assertNoDocumentScroll(targetPage, `${label}: card preview`);
  evidence.push({ label: `${label}-card-preview`, initial, normal, hovered, focused, document: geometry });
}

async function inspect(label, run) {
  await page.mouse.move(0, 0);
  await page.screenshot({ path: `${out}/${label}.png` });
  const viewport = page.viewportSize();
  const document = await assertNoDocumentScroll(page, label);
  assert.equal(await page.locator('[data-enemy]').count(), run.enemies.length);
  const hero = page.locator('[data-hero-actor]');
  const subjects = [{ locator: hero, art: '.actor-art-wrap', state: run.player }, ...run.enemies.map(enemy => ({
    locator: page.locator(`[data-enemy="${enemy.id}"]`), art: '.enemy-art-wrap', state: enemy,
  }))];
  const boxes = [];
  const actorControls = [];
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
    const hpInspection = await inspectElement(page, hp, `${label}: ${state.name || 'hero'} HP`);
    const blockInspection = await inspectElement(page, block, `${label}: ${state.name || 'hero'} block`);
    const hpBox = await hp.boundingBox();
    const barBox = await progress.boundingBox();
    const artBox = await locator.locator(art).boundingBox();
    assert.ok(hpBox.width >= 50 && hpBox.height > 0, `${label}: health bar has readable size`);
    assert.ok(barBox.width >= 32 && barBox.height >= 4, `${label}: health fill is a visible bar, not only a number ${JSON.stringify(barBox)}`);
    assert.ok(Math.abs(hpBox.x + hpBox.width / 2 - artBox.x - artBox.width / 2) < Math.max(artBox.width, 120), `${label}: health belongs next to its actor ${JSON.stringify({ hpBox, artBox })}`);
    assert.ok(hpBox.y >= artBox.y && hpBox.y - (artBox.y + artBox.height) < 110, `${label}: health stays near the actor feet`);
    boxes.push({ hp: edgeBox(hpBox), block: edgeBox(await block.boundingBox()), art: edgeBox(artBox) });
    actorControls.push({ hp: hpInspection, block: blockInspection });
  }
  for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++) {
    const a = boxes[i].hp, b = boxes[j].hp;
    assert.ok(a.x + a.width <= b.x + 1 || b.x + b.width <= a.x + 1 || a.y + a.height <= b.y + 1 || b.y + b.height <= a.y + 1, `${label}: separate health bars do not overlap`);
  }
  const enemies = [];
  for (const enemy of run.enemies) enemies.push(await inspectElement(page, page.locator(`[data-enemy="${enemy.id}"]`), `${label}: ${enemy.name} target`));
  const endTurn = await inspectElement(page, page.locator('#end'), `${label}: End Turn`);
  const energy = await inspectElement(page, page.locator('[aria-label="目前能量"]'), `${label}: energy`);
  const handPanel = await inspectElement(page, page.locator('#hand-section'), `${label}: hand panel`, { hitTest: false });
  const touchTargets = viewport.width <= 844 ? await assertTargetSizes(page, label, PRIMARY_TOUCH_SELECTORS) : [];
  const readable = viewport.width <= 844 ? await assertMobileReadability(page, label) : [];
  evidence.push({ label, viewport, enemyCount: run.enemies.length, boxes, actorControls, enemyTargets: enemies, endTurn, energy, handPanel, document, touchTargets, readable });
}

async function assertShellFocus(targetPage, label, screen, contentSelector) {
  await targetPage.waitForFunction(() => document.activeElement && document.activeElement !== document.body);
  const viewport = targetPage.viewportSize();
  const frame = await documentGeometry(targetPage);
  assert.equal(await targetPage.locator('#app').getAttribute('data-screen'), screen, `${label}: expected screen`);
  assert.ok(frame.view, `${label}: view-root is present`);
  assertInViewport(frame.shell, viewport, `${label}: shell`);
  assertInViewport(frame.view, viewport, `${label}: view-root`);
  assert.equal(frame.view.scrollTop, 0, `${label}: initial view-root focus must not start after an internal scroll`);
  assert.ok(frame.view.scrollWidth <= frame.view.clientWidth + 1, `${label}: view-root has horizontal overflow ${JSON.stringify(frame.view)}`);
  const focused = targetPage.locator(':focus');
  await inspectElement(targetPage, focused, `${label}: initial focus`);
  const content = targetPage.locator(contentSelector).first();
  await content.waitFor({ state: 'visible' });
  const contentBox = await content.boundingBox();
  assert.ok(contentBox && contentBox.x >= frame.view.x - 1 && contentBox.x + contentBox.width <= frame.view.right + 1,
    `${label}: view content is outside the shell column ${JSON.stringify({ content: edgeBox(contentBox), view: frame.view })}`);
  return { frame, focus: await focused.evaluate(element => ({ id: element.id || '', tag: element.tagName, menu: element.dataset.menu || '', tab: element.dataset.tab || '', build: element.dataset.build || '' })) };
}

async function checkNavigationFocus(targetPage) {
  await targetPage.setViewportSize({ width: 390, height: 844 });
  await targetPage.goto(url);
  await targetPage.evaluate(() => { localStorage.clear(); sessionStorage.clear(); });
  await targetPage.reload();
  await targetPage.locator('[data-menu=play]').waitFor();
  const states = [];
  states.push(await assertShellFocus(targetPage, 'title navigation', 'title', '[data-menu=play]'));

  await targetPage.locator('[data-menu=play]').click();
  await targetPage.locator('[data-menu=new]').waitFor();
  states.push(await assertShellFocus(targetPage, 'play navigation', 'play', '[data-menu=new]'));

  await targetPage.locator('[data-menu=new]').click();
  await targetPage.locator('[data-menu=choose-character]').waitFor();
  states.push(await assertShellFocus(targetPage, 'setup navigation', 'setup', '[data-menu=choose-character]'));

  await targetPage.locator('[data-menu=choose-character]').click();
  await targetPage.locator('[data-character]').first().waitFor();
  states.push(await assertShellFocus(targetPage, 'home navigation', 'home', '[data-character]'));

  await targetPage.locator('[data-tab=collection]').first().click();
  await targetPage.locator('[data-card-id]').first().waitFor();
  states.push(await assertShellFocus(targetPage, 'collection navigation', 'collection', '[data-card-id]'));

  await targetPage.screenshot({ path: `${out}/navigation-collection.png` });
  const document = await assertNoDocumentScroll(targetPage, 'navigation smoke');
  evidence.push({ label: 'navigation-focus-smoke', states, document });
}

async function inspectDialog(targetPage, rootSelector, panelSelector, contentSelector, label, screenshotPath) {
  const viewport = targetPage.viewportSize();
  const root = targetPage.locator(rootSelector);
  await root.waitFor({ state: 'visible' });
  const panel = root.locator(panelSelector);
  const panelInspection = await inspectElement(targetPage, panel, `${label}: panel`);
  const content = root.locator(contentSelector);
  await content.waitFor({ state: 'visible' });
  const contentMetrics = await content.evaluate(element => ({
    scrollWidth: element.scrollWidth,
    clientWidth: element.clientWidth,
    scrollHeight: element.scrollHeight,
    clientHeight: element.clientHeight,
  }));
  assert.ok(contentMetrics.scrollWidth <= contentMetrics.clientWidth + 1,
    `${label}: content has hidden horizontal overflow ${JSON.stringify(contentMetrics)}`);
  const panelMetrics = await panel.evaluate(element => ({
    scrollWidth: element.scrollWidth,
    clientWidth: element.clientWidth,
    scrollHeight: element.scrollHeight,
    clientHeight: element.clientHeight,
    scrollTop: element.scrollTop,
  }));
  assert.ok(panelMetrics.scrollWidth <= panelMetrics.clientWidth + 1,
    `${label}: panel has hidden horizontal overflow ${JSON.stringify(panelMetrics)}`);
  if (screenshotPath) await targetPage.screenshot({ path: screenshotPath });

  const lastReadable = root.locator('.battle-overlay-content li, .battle-overlay-content p, .battle-overlay-content button, .battle-overlay-content summary, .battle-overlay-content h3, .tutorial-section p, .tutorial-section button').last();
  if (await lastReadable.count()) {
    await lastReadable.scrollIntoViewIfNeeded();
    const lastBox = await lastReadable.boundingBox();
    const panelBox = await panel.boundingBox();
    assertInside(lastBox, panelBox, `${label}: last readable content`);
  }
  const atBottom = await panel.evaluate(element => {
    element.scrollTop = element.scrollHeight;
    return { scrollTop: element.scrollTop, clientHeight: element.clientHeight, scrollHeight: element.scrollHeight };
  });
  assert.ok(atBottom.scrollTop + atBottom.clientHeight >= atBottom.scrollHeight - 1,
    `${label}: scrollable dialog content must be reachable ${JSON.stringify(atBottom)}`);
  const document = await assertNoDocumentScroll(targetPage, label);
  return { viewport, panel: panelInspection, content: contentMetrics, panelMetrics, atBottom, document };
}

async function waitDialogClosed(targetPage, selector) {
  const dialog = targetPage.locator(selector);
  if (!(await dialog.count())) return;
  assert.equal(await dialog.isVisible(), false, `${selector} should be closed`);
}

async function checkBattleOverlays(targetPage, run) {
  const expected = { menu: '戰鬥選單', log: '即時戰報', build: '構築與遺物', rules: '戰鬥規則' };
  const contentSelectors = { menu: '.overlay-menu-actions', log: '.overlay-log', build: '.build-summary', rules: '.overlay-rules' };
  const checks = [];
  for (const name of Object.keys(expected)) {
    const trigger = targetPage.locator(`[data-battle-overlay=${name}]`);
    await trigger.focus();
    await trigger.click();
    const overlay = targetPage.locator('#battle-overlay');
    await overlay.waitFor({ state: 'visible' });
    assert.equal(await overlay.getAttribute('role'), 'dialog', `${name}: overlay role`);
    assert.equal(await overlay.getAttribute('aria-modal'), 'true', `${name}: overlay must be modal`);
    assert.equal(await overlay.locator('#battle-overlay-title').innerText(), expected[name], `${name}: dialog title`);
    assert.ok((await overlay.locator(contentSelectors[name]).innerText()).trim(), `${name}: dialog content is present`);
    const root = targetPage.locator('[data-battle-root]');
    assert.ok(await root.getAttribute('inert') !== null, `${name}: battle root must be inert while overlay is open`);
    assert.equal(await root.getAttribute('aria-hidden'), 'true', `${name}: battle root must be hidden from assistive focus`);
    const underlying = targetPage.locator('#end');
    const underlyingBox = await underlying.boundingBox();
    const blocked = await targetPage.evaluate(({ x, y }) => {
      const target = document.querySelector('#end');
      const node = document.elementFromPoint(x, y);
      return { blocked: Boolean(target && node && !(node === target || target.contains(node))), hit: node ? { id: node.id || '', tag: node.tagName, className: node.className || '' } : null };
    }, { x: underlyingBox.x + underlyingBox.width / 2, y: underlyingBox.y + underlyingBox.height / 2 });
    assert.ok(blocked.blocked, `${name}: overlay must block click-through to End Turn ${JSON.stringify(blocked)}`);
    const before = await savedRun(targetPage);
    await targetPage.mouse.click(2, 2);
    assert.equal(await overlay.isVisible(), true, `${name}: backdrop click must not dismiss the overlay`);
    assert.deepEqual(await savedRun(targetPage), before, `${name}: background click must not mutate battle state`);
    const dialog = await inspectDialog(targetPage, '#battle-overlay', '.battle-overlay-panel', '.battle-overlay-content', `battle overlay ${name}`, `${out}/overlay-landscape-${name}.png`);
    await targetPage.keyboard.press('Escape');
    await waitDialogClosed(targetPage, '#battle-overlay');
    assert.equal(await targetPage.evaluate(() => document.activeElement?.dataset?.battleOverlay), name,
      `${name}: Escape must restore focus to its opener`);
    assert.deepEqual(await savedRun(targetPage), run, `${name}: close must preserve battle state`);
    checks.push({ name, dialog });
  }
  evidence.push({ label: 'battle-overlays', checks });
}

async function checkTutorialPreserved(targetPage, run) {
  const menuTrigger = targetPage.locator('[data-battle-overlay=menu]');
  await menuTrigger.focus();
  await menuTrigger.click();
  await targetPage.locator('#battle-overlay [data-tutorial-open]').click();
  const before = await savedRun(targetPage);
  await targetPage.locator('#tutorial-modal').waitFor({ state: 'visible' });
  assert.equal(await targetPage.evaluate(() => document.activeElement?.id), 'tutorial-close', 'tutorial opens on its close control');
  assert.match(await targetPage.locator('#tutorial-title').innerText(), /接力/);
  await targetPage.locator('[data-tutorial-step="3"]').click();
  assert.match(await targetPage.locator('[data-tutorial=relay-state]').innerText(), /3\/3/);
  await targetPage.locator('[data-tutorial-tab=charge]').click();
  assert.ok(await targetPage.locator('[data-tutorial=charge-panel]').isVisible(), 'tutorial charge panel remains available');
  const dialog = await inspectDialog(targetPage, '#tutorial-modal', '.panel', '.tutorial-section', 'tutorial landscape', `${out}/tutorial-landscape.png`);
  await targetPage.keyboard.press('Escape');
  await targetPage.locator('#tutorial-modal').waitFor({ state: 'hidden' });
  assert.equal(await targetPage.evaluate(() => document.activeElement?.dataset?.battleOverlay), 'menu', 'tutorial Escape restores the battle menu opener');
  assert.equal(await targetPage.locator('#battle-overlay').count(), 0, 'tutorial closes the battle overlay before returning');
  assert.deepEqual(await savedRun(targetPage), before, 'tutorial interactions must not mutate the battle');
  evidence.push({ label: 'tutorial-preserved', dialog, run: before });
}

async function checkPiles(targetPage, run) {
  const checks = [];
  for (const pile of ['draw', 'deck', 'discard', 'exile']) {
    const trigger = targetPage.locator(`[data-pile=${pile}]`).first();
    await trigger.focus();
    await trigger.click();
    const modal = targetPage.locator('#modal');
    await modal.waitFor({ state: 'visible' });
    assert.equal(await modal.getAttribute('aria-hidden'), 'false', `${pile}: pile modal is exposed`);
    assert.ok((await modal.locator('#pile-title').innerText()).trim(), `${pile}: pile title is present`);
    const panel = modal.locator('.panel');
    const panelInspection = await inspectElement(targetPage, panel, `${pile}: pile panel`);
    await targetPage.keyboard.press('Escape');
    await modal.waitFor({ state: 'hidden' });
    assert.equal(await targetPage.evaluate(() => document.activeElement?.dataset?.pile), pile, `${pile}: Escape restores pile focus`);
    assert.deepEqual(await savedRun(targetPage), run, `${pile}: pile inspection preserves battle state`);
    checks.push({ pile, panel: panelInspection });
  }
  evidence.push({ label: 'pile-dialogs', checks });
}

async function checkTouchInteractions(targetPage) {
  const viewport = targetPage.viewportSize();
  const orientation = viewport.width > viewport.height ? 'landscape' : 'portrait';
  const run = await installFixture(targetPage, { enemies: 2 });
  const initial = await savedRun(targetPage);
  const affordable = instance => {
    const item = getCard(instance.cardId, instance.upgraded || 0);
    return item && item.cost <= run.energy;
  };
  const preview = run.hand.find(affordable);
  assert.ok(preview, 'touch fixture contains an affordable preview card');
  const previewCard = targetPage.locator(`[data-play=${preview.uid}]`);
  await previewCard.scrollIntoViewIfNeeded();
  await previewCard.tap();
  await targetPage.locator('#cancel-card').waitFor({ state: 'visible' });
  assert.deepEqual(await savedRun(targetPage), initial, 'first touch card tap previews without spending resources');
  await assertTargetSizes(targetPage, 'touch selection cancel', ['#cancel-card']);
  await targetPage.setViewportSize(orientation === 'portrait' ? { width: 844, height: 390 } : { width: 390, height: 844 });
  await inspectElement(targetPage, targetPage.locator('#cancel-card'), 'rotated touch cancel');
  for (const hp of await targetPage.locator('.combatant-hp').all()) await inspectElement(targetPage, hp, 'rotated actor HP');
  assert.deepEqual(await savedRun(targetPage), initial, 'rotation preserves the selected card and battle resources');
  await targetPage.setViewportSize(viewport);
  await targetPage.screenshot({ path: `${out}/touch-preview-${orientation}.png` });
  await targetPage.locator('#cancel-card').tap();
  await targetPage.locator('#cancel-card').waitFor({ state: 'hidden' });
  assert.deepEqual(await savedRun(targetPage), initial, 'cancel-card cancels touch preview without spending resources');

  const targeted = run.hand.find(instance => {
    const item = getCard(instance.cardId, instance.upgraded || 0);
    return item && item.target === 'enemy' && item.cost <= run.energy && item.effects.some(effect => effect.op === 'damage');
  });
  assert.ok(targeted, 'touch fixture contains an affordable targeted damage card');
  const targetCard = targetPage.locator(`[data-play=${targeted.uid}]`);
  const targetedBefore = await savedRun(targetPage);
  await targetCard.tap();
  await targetPage.locator('#cancel-card').waitFor({ state: 'visible' });
  assert.equal(await targetPage.locator('#confirm-card').count(), 0, 'targeted touch card waits for an enemy instead of a confirm button');
  const target = targetedBefore.enemies.find(enemy => enemy.hp > 0);
  const targetBefore = targetedBefore.enemies.find(enemy => enemy.id === target.id);
  await targetPage.locator(`[data-enemy=${target.id}]`).tap();
  await targetPage.locator('#cancel-card').waitFor({ state: 'hidden' });
  const targetedAfter = await savedRun(targetPage);
  assert.equal(targetedAfter.metrics.cardsPlayed, targetedBefore.metrics.cardsPlayed + 1, 'targeted touch tap casts exactly once');
  assert.equal(targetedAfter.energy, targetedBefore.energy - getCard(targeted.cardId, targeted.upgraded || 0).cost, 'targeted touch tap spends energy once');
  const targetAfter = targetedAfter.enemies.find(enemy => enemy.id === target.id);
  assert.ok(targetAfter.hp + targetAfter.block < targetBefore.hp + targetBefore.block, 'targeted touch tap damages the selected enemy');

  const nonTargetRun = await installFixture(targetPage, { enemies: 2 });
  const nonTarget = nonTargetRun.hand.find(instance => {
    const item = getCard(instance.cardId, instance.upgraded || 0);
    return item && item.target !== 'enemy' && item.target !== 'all' && item.cost <= nonTargetRun.energy && item.effects.some(effect => effect.op === 'block');
  });
  assert.ok(nonTarget, 'touch fixture contains an affordable non-targeted block card');
  const nonTargetBefore = await savedRun(targetPage);
  await targetPage.locator(`[data-play=${nonTarget.uid}]`).tap();
  await targetPage.locator('#confirm-card').waitFor({ state: 'visible' });
  assert.deepEqual(await savedRun(targetPage), nonTargetBefore, 'non-targeted touch card tap only previews');
  await assertTargetSizes(targetPage, 'touch selection confirm', ['#cancel-card', '#confirm-card']);
  await targetPage.screenshot({ path: `${out}/touch-confirm-${orientation}.png` });
  await targetPage.locator('#confirm-card').tap();
  await targetPage.locator('#confirm-card').waitFor({ state: 'hidden' });
  const nonTargetAfter = await savedRun(targetPage);
  assert.equal(nonTargetAfter.metrics.cardsPlayed, nonTargetBefore.metrics.cardsPlayed + 1, 'non-targeted confirm casts exactly once');
  assert.equal(nonTargetAfter.energy, nonTargetBefore.energy - getCard(nonTarget.cardId, nonTarget.upgraded || 0).cost, 'non-targeted confirm spends energy once');
  assert.ok(nonTargetAfter.player.block > nonTargetBefore.player.block, 'non-targeted confirm applies the card effect');
  const document = await assertNoDocumentScroll(targetPage, 'touch interaction');
  evidence.push({ label: `touch-interactions-${orientation}`, initial, targetedBefore, targetedAfter, nonTargetBefore, nonTargetAfter, document });
}

try {
  await checkNavigationFocus(page);
  const layoutFailures = [];
  for (const item of [
    { label: 'desktop-two', width: 1440, height: 900, enemies: 2 },
    { label: 'desktop-three', width: 1440, height: 900, enemies: 3 },
    { label: 'laptop-boss', width: 1366, height: 768, enemies: 1, boss: true },
    { label: 'desktop-ten-cards', width: 1440, height: 900, enemies: 2, fullHand: true },
    { label: 'phone-portrait', width: 390, height: 844, enemies: 2 },
    { label: 'phone-landscape', width: 844, height: 390, enemies: 2 },
    { label: 'phone-portrait-three', width: 390, height: 844, enemies: 3 },
    { label: 'phone-landscape-three', width: 844, height: 390, enemies: 3 },
  ]) {
    await page.setViewportSize({ width: item.width, height: item.height });
    const scenarioRun = await installFixture(page, item);
    try {
      await inspect(item.label, scenarioRun);
      if (item.fullHand) await checkCardPreview(page, scenarioRun, item.label);
    } catch (error) {
      await page.screenshot({ path: `${out}/${item.label}-failure.png` });
      layoutFailures.push(error);
    }
  }

  if (layoutFailures.length) throw new AggregateError(layoutFailures, layoutFailures.map(error => error.message).join('\n'));

  await page.setViewportSize({ width: 844, height: 390 });
  const overlayRun = await installFixture(page, { enemies: 2 });
  await assertTargetSizes(page, 'landscape battle controls', PRIMARY_TOUCH_SELECTORS);
  await checkBattleOverlays(page, overlayRun);
  await checkTutorialPreserved(page, overlayRun);

  await page.setViewportSize({ width: 1440, height: 900 });
  let before = await installFixture(page, { enemies: 2 });
  await checkPiles(page, before);
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
  await checkTouchInteractions(touchPage);
  await touchPage.setViewportSize({ width: 844, height: 390 });
  await checkTouchInteractions(touchPage);
  assert.deepEqual(errors, [], 'no browser or asset errors');
  await writeFile(`${out}/evidence.json`, JSON.stringify({ passed: true, evidence, checks: ['viewport-only screenshots', 'no document x/y scroll', 'actor-local HP/block and intent geometry', 'no overflow:hidden clipping or pointer occlusion', '1-3 enemies and boss', '10-card hand', 'desktop and mobile', 'mobile readable text and 44px touch targets', 'title/setup/home/collection focus smoke', 'pile dialogs and Escape', 'battle overlays and inert click blocking', 'tutorial preservation', 'hover/focus preview without mutation', 'touch cancel/targeted/confirm exactly once', 'targeted attack', 'block updates', 'resonance empowerment', 'targeted consumable', 'end turn', 'reload continuation'] }, null, 2));
  console.log(JSON.stringify({ passed: true, screenshots: out, scenarios: evidence.map(item => item.label) }));
} catch (error) {
  const failureScreenshots = [];
  for (const [name, targetPage] of [['desktop', page], ['touch', touchPage]]) {
    try {
      const path = `${out}/failure-${name}.png`;
      await targetPage.screenshot({ path });
      failureScreenshots.push(path);
    } catch (_) {}
  }
  await writeFile(`${out}/evidence.json`, JSON.stringify({ passed: false, error: error?.stack || String(error), failureScreenshots, evidence, errors }, null, 2));
  throw error;
} finally { await browser.close(); }
