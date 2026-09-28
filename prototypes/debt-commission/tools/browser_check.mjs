import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';

// Browser acceptance: real canvas mouse/touch input against the Web export (?qa=1).
const require = createRequire(import.meta.url);
const smokeOnly = process.argv.includes('--smoke');
const phase2Only = process.argv.includes('--phase2');
const slotsOnly = process.argv.includes('--slots');
const phase3Only = process.argv.includes('--phase3');
const roundsOnly = process.argv.includes('--rounds');
const arg = (name, fallback) => {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : fallback;
};
const { chromium } = require(arg('--playwright', '@playwright/test'));
const url = new URL(arg('--url', 'http://127.0.0.1:5193/'));
url.searchParams.set('qa', '1');
if (phase3Only) url.searchParams.set('sample', 'phase3');
else if (roundsOnly) url.searchParams.set('sample', 'phase4_rounds');
else if (phase2Only || slotsOnly) url.searchParams.set('sample', 'phase2');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(root, 'test-results');
await fs.mkdir(output, { recursive: true });
await fs.writeFile(path.join(output, '.gdignore'), '');
const report = { url: url.toString(), started: new Date().toISOString(), runs: [] };
const browser = await chromium.launch({
  headless: true,
  executablePath: arg('--chromium', undefined),
  args: ['--enable-webgl', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});

const state = page => page.evaluate(() => window.__debtQA);
const key = value => `${value.screen}:${value.node_id}:${value.step_index}`;
const lineKey = value => `${value.node_id}:${value.step_index}`;
const center = rect => ({ x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 });
const stable = page => page.waitForFunction(() => {
  const value = window.__debtQA;
  return value && ['title', 'story', 'choice', 'end', 'result', 'investigate', 'boke_round', 'tsukkomi',
    'log', 'menu', 'save_slots', 'load_slots', 'slot_confirm', 'chapter_select', 'settings'].includes(value.screen);
}, null, { timeout: 30000 });
const waitFor = (page, predicate, arg, timeout = 15000) => page.waitForFunction(predicate, arg, { timeout });

function assertInside(rect, viewport, name) {
  assert.ok(rect && rect.width > 0 && rect.height > 0, `${name} needs a visible rectangle`);
  assert.ok(rect.x >= -1 && rect.y >= -1 && rect.x + rect.width <= viewport.width + 1
    && rect.y + rect.height <= viewport.height + 1,
    `${name} lies outside the viewport: ${JSON.stringify({ rect, viewport })}`);
}

// Logical Godot coordinates → CSS pixels on the canvas.
async function toPage(page, view, point) {
  const bounds = await page.locator('canvas').boundingBox();
  assert.ok(bounds, 'Godot canvas exists');
  return { x: bounds.x + point.x / view.width * bounds.width, y: bounds.y + point.y / view.height * bounds.height };
}

async function tapAt(page, view, point, touch) {
  const p = await toPage(page, view, point);
  if (touch) await page.touchscreen.tap(p.x, p.y);
  else await page.mouse.click(p.x, p.y);
  await page.waitForTimeout(150);
}

async function control(page, name, touch) {
  const current = await state(page);
  assert.ok(current.controls[name], `Control ${name} is available on ${current.screen}`);
  assertInside(current.controls[name], current.viewport, name);
  await tapAt(page, current.viewport, center(current.controls[name]), touch);
}

async function controlAny(page, names, touch, description = names.join('/')) {
  const current = await state(page);
  const name = names.find(candidate => current.controls[candidate]);
  assert.ok(name, `Control ${description} is available on ${current.screen}; found ${Object.keys(current.controls || {}).join(', ')}`);
  await control(page, name, touch);
  return name;
}

// Press at `from`, move to `to`, hold, release. Touch uses CDP touch events (Playwright has no touch drag).
async function gesture(page, view, from, to, holdMs, touch) {
  const a = await toPage(page, view, from);
  const b = await toPage(page, view, to);
  const steps = 8;
  if (touch) {
    const cdp = await page.context().newCDPSession(page);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: a.x, y: a.y }] });
    for (let i = 1; i <= steps; i++) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove',
        touchPoints: [{ x: a.x + (b.x - a.x) * i / steps, y: a.y + (b.y - a.y) * i / steps }] });
      await page.waitForTimeout(16);
    }
    await page.waitForTimeout(holdMs);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await cdp.detach();
  } else {
    await page.mouse.move(a.x, a.y);
    await page.mouse.down();
    for (let i = 1; i <= steps; i++) {
      await page.mouse.move(a.x + (b.x - a.x) * i / steps, a.y + (b.y - a.y) * i / steps);
      await page.waitForTimeout(16);
    }
    await page.waitForTimeout(holdMs);
    await page.mouse.up();
  }
  await page.waitForTimeout(200);
}

async function reveal(page, touch) {
  const before = await state(page);
  if (before.screen !== 'story' || before.text_complete) return false;
  await controlAny(page, ['dialogue', 'advance', 'next'], touch, 'dialogue reveal');
  const after = await state(page);
  assert.equal(key(after), key(before), 'First tap completes the current line without advancing');
  assert.equal(after.text_complete, true, 'First tap reveals all text');
  return true;
}

async function next(page, touch, target = 'dialogue') {
  await waitFor(page, () => window.__debtQA?.text_complete, null, 10000);
  const before = await state(page);
  await controlAny(page, [target, 'dialogue', 'advance', 'next'], touch, 'dialogue advance');
  await waitFor(page, previous => {
    const value = window.__debtQA;
    return value && value.screen !== 'busy' && `${value.screen}:${value.node_id}:${value.step_index}` !== previous;
  }, key(before));
}

async function screenshot(page, name) {
  await page.screenshot({ path: path.join(output, `${name}.png`), fullPage: true });
}

function assertLayout(value, label) {
  const { viewport, game, dialog, quickbar, name_plate: namePlate, controls } = value;
  assertInside(game, viewport, `${label} game surface`);
  if (dialog?.width > 0 && dialog?.height > 0) assertInside(dialog, viewport, `${label} dialogue surface`);
  if (quickbar?.width > 0 && quickbar?.height > 0) assertInside(quickbar, viewport, `${label} reading toolbar`);
  if (namePlate?.width > 0 && namePlate?.height > 0) assertInside(namePlate, viewport, `${label} speaker mark`);
  for (const [name, rect] of Object.entries(controls || {})) {
    assertInside(rect, viewport, `${label} control ${name}`);
  }
}

function assertContained(rect, outer, label) {
  assert.ok(rect.x >= outer.x - 1 && rect.y >= outer.y - 1
    && rect.x + rect.width <= outer.x + outer.width + 1
    && rect.y + rect.height <= outer.y + outer.height + 1,
  `${label} is outside the unified bottom sheet: ${JSON.stringify({ rect, outer })}`);
}

async function openSaveSlots(page, touch) {
  await controlAny(page, ['menu', 'toolbar_menu', 'menu_open'], touch, 'single menu control');
  await waitFor(page, () => window.__debtQA?.screen === 'menu', null, 10000);
  await controlAny(page, ['menu_save', 'save'], touch, 'menu save action');
  await waitFor(page, () => window.__debtQA?.screen === 'save_slots', null, 10000);
  const current = await state(page);
  assert.equal(current.screen, 'save_slots', 'Save opens the manual slot picker');
  return current;
}

async function closeSaveSlots(page, touch) {
  let current = await state(page);
  if (['save_slots', 'load_slots', 'slot_confirm'].includes(current.screen)) {
    await controlAny(page, ['slot_close', 'close_slots', 'menu_close'], touch, 'slot picker close');
    current = await state(page);
  }
  if (current.screen === 'menu') {
    await controlAny(page, ['menu_close', 'menu_resume', 'resume'], touch, 'menu resume');
  }
}

async function activateSkip(page, touch) {
  let value = await state(page);
  if (value.controls.skip || value.controls.toolbar_skip) {
    await controlAny(page, ['skip', 'toolbar_skip'], touch, 'SKIP quick action');
    return;
  }
  await controlAny(page, ['menu', 'toolbar_menu', 'menu_open'], touch, 'single menu control');
  await waitFor(page, () => window.__debtQA?.screen === 'menu', null, 10000);
  await controlAny(page, ['menu_skip', 'skip'], touch, 'menu skip action');
  value = await state(page);
  if (value.screen === 'menu') {
    await controlAny(page, ['menu_close', 'menu_resume', 'resume', 'close_menu'], touch, 'menu close/resume');
  }
}

async function openPage(viewport, touch) {
  const context = await browser.newContext({ viewport, hasTouch: touch, isMobile: touch, deviceScaleFactor: 1 });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(message.text())) errors.push(message.text());
  });
  await page.goto(url.toString(), { waitUntil: 'load', timeout: 120000 });
  await waitFor(page, () => window.__debtQA?.screen === 'title', null, 120000);
  return { context, page, errors };
}

// Opening-line interaction: background tap, hide UI, backlog, the single menu entry, and AUTO.
async function phase1Gestures(page, touch, route, checks) {
  let value = await state(page);
  assertLayout(value, route);
  assert.ok(value.name_plate.width > 0 || value.speaker === 'narrator', 'Name plate shows for character lines');
  await screenshot(page, `${route}-dialogue`);
  checks.push('dialogue, reading toolbar, speaker and controls remain inside the viewport');

  await waitFor(page, () => window.__debtQA?.text_complete);
  let before = await state(page);
  await control(page, 'stage', touch);
  await waitFor(page, previous => { const v = window.__debtQA; return v.screen === 'story' && `${v.node_id}:${v.step_index}` !== previous; }, lineKey(before));
  checks.push('tapping the background (not the box) also advances');

  before = await state(page);
  const stage = center(before.controls.stage);
  await gesture(page, before.viewport, stage, stage, 700, touch);
  value = await state(page);
  assert.equal(value.ui_hidden, true, 'Long-press hides all UI');
  assert.equal(key(value), key(before), 'Long-press does not advance');
  await screenshot(page, `${route}-ui-hidden`);
  await tapAt(page, value.viewport, stage, touch);
  value = await state(page);
  assert.equal(value.ui_hidden, false, 'Tap restores the UI');
  assert.equal(key(value), key(before), 'The restoring tap does not advance');
  checks.push('long-press hides UI; the restoring tap does not advance');

  await gesture(page, value.viewport, { x: stage.x, y: stage.y + 320 }, stage, 60, touch);
  value = await state(page);
  assert.equal(value.screen, 'log', 'Swipe up opens the backlog');
  await screenshot(page, `${route}-log`);
  await control(page, 'log_close', touch);
  assert.equal(key(await state(page)), key(before), 'Closing the log returns to the same line');
  checks.push('swipe up opens the backlog; closing keeps the line');

  value = await state(page);
  const menuName = await controlAny(page, ['menu', 'toolbar_menu', 'menu_open'], touch, 'single menu control');
  value = await state(page);
  assert.equal(value.screen, 'menu', 'The reading toolbar opens the menu');
  assert.equal(lineKey(value), lineKey(before), 'Opening the menu does not advance');
  assert.ok(value.controls.menu_close || value.controls.menu_resume || value.controls.resume,
    'The menu exposes a reachable close/resume target');
  await page.waitForTimeout(300);
  await screenshot(page, `${route}-menu`);
  await controlAny(page, ['menu_close', 'menu_resume', 'resume', 'close_menu'], touch, 'menu close/resume');
  value = await state(page);
  assert.equal(key(value), key(before), 'Closing the menu returns to the same line');
  checks.push(`single menu target (${menuName}) opens and closes without advancing`);

  await controlAny(page, ['auto', 'toolbar_auto'], touch, 'AUTO quick action');
  await waitFor(page, previous => { const v = window.__debtQA; return `${v.node_id}:${v.step_index}` !== previous; }, lineKey(before), 12000);
  await controlAny(page, ['auto', 'toolbar_auto'], touch, 'AUTO quick action');
  assert.equal((await state(page)).auto, false, 'AUTO toggles off');
  checks.push('AUTO advances by itself and toggles off');
}

async function playRoute(route, viewport, touch) {
  const { context, page, errors } = await openPage(viewport, touch);
  const result = { route, viewport, touch, nodes: [], lines: 0, checks: [], errors };
  report.runs.push(result);
  console.log(`Starting route ${route} at ${viewport.width}×${viewport.height}`);
  await screenshot(page, `${route}-title`);
  await control(page, 'begin', touch);
  await stable(page);
  if (await reveal(page, touch)) result.checks.push('first tap reveals the opening line without advancing');
  await phase1Gestures(page, touch, route, result.checks);

  let selected = false;
  let resumed = false;
  let otoseAppeared = false;
  let finished = false;
  for (let step = 0; step < 160; step++) {
    await stable(page);
    const current = await state(page);
    if (!result.nodes.includes(current.node_id)) result.nodes.push(current.node_id);
    otoseAppeared ||= current.sprites.otose?.visible === true;
    if (current.screen === 'story') {
      result.lines++;
      if (current.node_id === 'debt_ask_salary' && !resumed) {
        await waitFor(page, () => window.__debtQA?.text_complete);
        const checkpoint = await state(page);
        await page.waitForTimeout(1400); // Let the browser flush Godot user:// to IndexedDB.
        await page.reload({ waitUntil: 'load', timeout: 120000 });
        await waitFor(page, () => window.__debtQA?.screen === 'title', null, 120000);
        await control(page, 'continue', touch);
        await stable(page);
        await waitFor(page, () => window.__debtQA?.text_complete);
        const restored = await state(page);
        assert.equal(key(restored), key(checkpoint), 'Continue restores the same reading point');
        assert.equal(restored.text, checkpoint.text, 'Continue preserves the current line');
        assert.deepEqual(restored.flags, checkpoint.flags, 'Continue preserves branch flags');
        assert.deepEqual(restored.sprites, checkpoint.sprites, 'Continue restores sprite visibility and expressions');
        result.checks.push('reload + continue preserves line, flags and sprites');
        resumed = true;
      }
      await next(page, touch);
    } else if (current.screen === 'choice') {
      assert.equal(selected, false, 'Only one deliberate choice is required');
      assert.equal(current.choices.length, 2, 'Both approved options are visible');
      current.choices.forEach(choice => assertInside(choice.rect, current.viewport, choice.label));
      await page.waitForTimeout(400);
      await screenshot(page, `${route}-choice`);
      const waiting = await state(page);
      assert.equal(key(waiting), key(current), 'Choice waits for the player');
      waiting.choices.forEach(choice => assertInside(choice.rect, waiting.viewport, `${route} choice ${choice.id}`));
      result.checks.push('choice buttons remain visible while waiting for a deliberate selection');

      if (waiting.controls.log) {
        await control(page, 'log', touch);
      } else {
        // The choice sheet carries only 目錄, as in the HTML reference; the backlog is 目錄 → 對話紀錄.
        await controlAny(page, ['menu', 'toolbar_menu', 'menu_open'], touch, 'choice sheet menu');
        await waitFor(page, () => window.__debtQA?.screen === 'menu', null, 10000);
        await control(page, 'menu_log', touch);
      }
      await page.waitForTimeout(500);
      const logOpen = await state(page);
      assert.equal(logOpen.screen, 'log');
      assert.ok(logOpen.log_scroll.max > 0, 'Backlog is longer than one screen at the choice');
      const logPoint = { x: logOpen.game.x + logOpen.game.width / 2, y: logOpen.game.y + logOpen.game.height * 0.4 };
      if (touch) {
        await gesture(page, logOpen.viewport, logPoint, { x: logPoint.x, y: logPoint.y + logOpen.game.height * 0.3 }, 60, true);
      } else {
        const p = await toPage(page, logOpen.viewport, logPoint);
        await page.mouse.move(p.x, p.y);
        await page.mouse.wheel(0, -600);
      }
      await page.waitForTimeout(400);
      const scrolled = await state(page);
      assert.ok(scrolled.log_scroll.value < logOpen.log_scroll.value - 20,
        `Backlog scrolls by ${touch ? 'touch drag' : 'mouse wheel'} (${logOpen.log_scroll.value} → ${scrolled.log_scroll.value})`);
      await screenshot(page, `${route}-log-scrolled`);
      await control(page, 'log_close', touch);
      assert.equal(key(await state(page)), key(current), 'Closing the backlog keeps the choice');
      result.checks.push(`backlog at the choice scrolls by ${touch ? 'touch drag' : 'mouse wheel'}`);
      if (route === 'B') {
        for (const size of [{ width: 360, height: 800 }, { width: 320, height: 568 }]) {
          await page.setViewportSize(size);
          await page.waitForTimeout(500);
          const resized = await state(page);
          resized.choices.forEach(choice => assertInside(choice.rect, resized.viewport, choice.label));
          assertLayout(resized, `${size.width}×${size.height}`);
          await screenshot(page, `B-choice-${size.width}x${size.height}`);
        }
        await page.setViewportSize(viewport);
        await page.waitForTimeout(400);
        result.checks.push('choice buttons and dialogue surfaces fit 360×800 and 320×568');
      }
      const ready = await state(page);
      const chosen = ready.choices[route === 'A' ? 0 : 1];
      result.selection = chosen;
      await tapAt(page, ready.viewport, center(chosen.rect), touch);
      await stable(page);
      assert.equal((await state(page)).flags.question_method, route === 'A' ? 'hear_first' : 'ledger_first');
      selected = true;
    } else if (current.screen === 'end') {
      assert.equal(current.flags.repayment_promised, true, 'Gintoki promised repayment');
      await screenshot(page, `${route}-end`);
      finished = true;
      break;
    } else {
      throw new Error(`Unexpected stable screen: ${current.screen}`);
    }
  }
  assert.ok(finished && selected && resumed, 'Route finished through a choice and reload');
  assert.ok(otoseAppeared, 'Otose enters during the scene');
  const expected = route === 'A' ? 'debt_recall_hearing' : 'debt_recall_ledger';
  const other = route === 'A' ? 'debt_recall_ledger' : 'debt_recall_hearing';
  assert.ok(result.nodes.includes(expected), 'The selected questioning method gets its callback');
  assert.ok(!result.nodes.includes(other), 'The other branch is not shown');
  result.checks.push('correct callback and complete ending');

  await control(page, 'restart', touch);
  await stable(page);
  const restarted = await state(page);
  assert.equal(restarted.node_id, 'debt_intro');
  assert.equal(restarted.flags.question_method, 'unset');
  await activateSkip(page, touch);
  await waitFor(page, () => window.__debtQA?.screen === 'choice', null, 30000);
  assert.equal((await state(page)).skip, false, 'SKIP stops at the choice');
  result.checks.push('restart resets flags; SKIP fast-forwards and stops at the choice');
  assert.deepEqual(errors, [], 'No browser or Godot runtime errors');
  console.log(`PASS route ${route}: ${result.lines} lines, ${result.checks.length} check groups`);
  await context.close();
}

async function touchSmoke() {
  const { context, page, errors } = await openPage({ width: 390, height: 844 }, true);
  await control(page, 'begin', true);
  await stable(page);
  const before = await state(page);
  assert.equal(before.text_complete, false, 'Opening line is still typing');
  await control(page, 'dialogue', true);
  const revealed = await state(page);
  assert.equal(key(revealed), key(before), 'Touch reveals without advancing twice');
  await control(page, 'dialogue', true);
  await stable(page);
  assert.notEqual(key(await state(page)), key(before), 'Next touch advances');
  const checks = [];
  await phase1Gestures(page, true, 'smoke', checks);
  await screenshot(page, 'smoke-mobile');
  const normalUrl = new URL(url);
  normalUrl.searchParams.delete('qa');
  await page.goto(normalUrl.toString(), { waitUntil: 'networkidle', timeout: 120000 });
  assert.equal(await page.evaluate(() => typeof window.__debtQA), 'undefined', 'Normal play has no QA bridge');
  assert.deepEqual(errors, []);
  report.runs.push({ route: 'touch-smoke', checks: ['touch reveal/advance once each', ...checks, 'normal URL'], errors });
  console.log('PASS: touch smoke (reveal/advance, gestures, menu toolbar, normal URL)');
  await context.close();
}

async function phase2Route(route, touch) {
  const { context, page, errors } = await openPage(touch ? { width: 390, height: 844 } : { width: 1280, height: 900 }, touch);
  const result = { route: `phase2-${route}`, checks: [], errors };
  report.runs.push(result);
  await control(page, 'begin', touch);
  await stable(page);
  let current = await state(page);
  assert.equal(current.background, 'yorozuya_living_room', 'JSON selects the opening background');
  assert.equal(current.sprites.shinpachi.visible, true, 'JSON shows Shinpachi');
  assert.equal(current.sprites.shinpachi.expression, 'neutral', 'Omitted expression uses catalog default');
  assertLayout(current, `phase2-${route}`);
  result.checks.push('JSON background, character, expression, and mobile layout');

  let selected = false;
  let resumed = false;
  let finished = false;
  for (let step = 0; step < 20; step++) {
    await stable(page);
    current = await state(page);
    if (current.screen === 'story') {
      if (selected && !resumed) {
        await waitFor(page, () => window.__debtQA?.text_complete, null, 10000);
        const saved = await state(page);
        assert.equal(saved.background, route === 'inspect' ? 'yorozuya_kitchen' : 'yorozuya_living_room');
        await page.waitForTimeout(1400);
        await page.reload({ waitUntil: 'load', timeout: 120000 });
        await waitFor(page, () => window.__debtQA?.screen === 'title', null, 120000);
        await control(page, 'continue', touch);
        await stable(page);
        const restored = await state(page);
        assert.equal(key(restored), key(saved), 'Continue restores the same Phase 2 line');
        assert.equal(restored.background, saved.background, 'Continue restores JSON background');
        assert.deepEqual(restored.items, saved.items, 'Continue restores materials once');
        assert.deepEqual(restored.sprites, saved.sprites, 'Continue restores characters and positions');
        resumed = true;
        result.checks.push('reload and Continue restore line, background, characters, and materials');
      }
      await waitFor(page, () => window.__debtQA?.text_complete, null, 10000);
      await next(page, touch);
    } else if (current.screen === 'choice') {
      assert.equal(selected, false, 'Sample has one choice');
      assert.equal(current.flags.test_started, true, 'flag command ran');
      assert.deepEqual(current.items, ['milk_bottle'], 'item command ran once');
      assert.equal(current.sprites.gintoki.position, 'right', 'JSON overrides Gintoki position');
      assert.deepEqual(current.choices.map(choice => choice.id), ['inspect_milk', 'skip_test'], 'required and open options are visible');
      const selectedId = route === 'inspect' ? 'inspect_milk' : 'skip_test';
      const chosen = current.choices.find(choice => choice.id === selectedId);
      await tapAt(page, current.viewport, center(chosen.rect), touch);
      await stable(page);
      selected = true;
      result.checks.push('owned item opens the required branch; flag and inventory are visible in QA');
    } else if (current.screen === 'end') {
      assert.equal(current.flags.route, route, 'selected branch writes the expected flag');
      assert.equal(current.background, route === 'inspect' ? 'yorozuya_kitchen' : 'yorozuya_living_room');
      if (route === 'inspect') assert.equal(current.sprites.kagura.expression, 'smile', 'JSON sets Kagura expression');
      assert.equal(current.items.filter(item => item === 'milk_bottle').length, 1, 'item never duplicates');
      await screenshot(page, `phase2-${route}-end`);
      finished = true;
      break;
    } else {
      throw new Error(`Unexpected Phase 2 screen: ${current.screen}`);
    }
  }
  assert.ok(selected && resumed && finished, 'Phase 2 route completes through a choice and reload');
  assert.deepEqual(errors, [], 'No browser or Godot runtime errors');
  console.log(`PASS phase2 ${route}: ${result.checks.length} check groups`);
  await context.close();
}

async function slotsRoute() {
  const { context, page, errors } = await openPage({ width: 390, height: 844 }, true);
  const result = { route: 'manual-slots-touch', checks: [], errors };
  report.runs.push(result);
  await control(page, 'begin', true);
  await stable(page);
  const opening = await state(page);
  assert.equal(opening.screen, 'story');
  let value = await openSaveSlots(page, true);
  assert.equal(value.slot_page, 0);
  assert.deepEqual(value.slots.map(slot => slot.index), [1, 2, 3, 4, 5, 6]);
  assert.ok(value.slots.every(slot => !slot.occupied));
  await screenshot(page, 'save-slots-empty-phone');
  await control(page, 'slot_1', true);
  await closeSaveSlots(page, true);
  await stable(page);
  assert.equal(lineKey(await state(page)), lineKey(opening), 'saving slot 1 keeps the reading point');
  result.checks.push('S opens six touch-sized slots; slot 1 saves without advancing');

  await activateSkip(page, true);
  await waitFor(page, () => window.__debtQA?.screen === 'choice', null, 30000);
  const choice = await state(page);
  assert.deepEqual(choice.items, ['milk_bottle']);
  await openSaveSlots(page, true);
  await control(page, 'slot_2', true);
  await closeSaveSlots(page, true);
  await stable(page);
  assert.equal((await state(page)).screen, 'choice');
  await controlAny(page, ['menu', 'toolbar_menu', 'menu_open'], true, 'single menu control');
  await control(page, 'menu_load', true);
  value = await state(page);
  assert.equal(value.screen, 'load_slots');
  assert.deepEqual(value.slots.slice(0, 2).map(slot => slot.occupied), [true, true]);
  assert.ok(value.controls.slot_auto, 'autosave is separately loadable');
  await screenshot(page, 'load-slots-two-saves-phone');
  await control(page, 'slot_1', true);
  await stable(page);
  value = await state(page);
  assert.equal(lineKey(value), lineKey(opening), 'selected slot 1 restores its line');
  assert.deepEqual(value.items, opening.items, 'selected slot 1 restores earlier inventory');
  result.checks.push('two manual slots preserve different progress; Load selects the requested slot');

  await controlAny(page, ['menu', 'toolbar_menu', 'menu_open'], true, 'single menu control');
  await control(page, 'menu_title', true);
  await waitFor(page, () => window.__debtQA?.screen === 'title');
  await control(page, 'title_load', true);
  value = await state(page);
  assert.equal(value.screen, 'load_slots');
  await control(page, 'slot_next', true);
  value = await state(page);
  assert.equal(value.slot_page, 1);
  assert.deepEqual(value.slots.map(slot => slot.index), [7, 8, 9, 10, 11, 12]);
  await control(page, 'slot_next', true);
  value = await state(page);
  assert.equal(value.slot_page, 2);
  assert.deepEqual(value.slots.map(slot => slot.index), [13, 14, 15, 16, 17, 18]);
  await control(page, 'slot_prev', true);
  await control(page, 'slot_prev', true);
  await control(page, 'slot_2', true);
  await stable(page);
  value = await state(page);
  assert.equal(lineKey(value), lineKey(choice), 'title Load restores selected slot 2');
  assert.deepEqual(value.items, choice.items);
  result.checks.push('title Load navigates all 18 slots and restores slot 2');

  await page.reload({ waitUntil: 'load', timeout: 120000 });
  await waitFor(page, () => window.__debtQA?.screen === 'title', null, 120000);
  await control(page, 'title_load', true);
  value = await state(page);
  assert.deepEqual(value.slots.slice(0, 2).map(slot => slot.occupied), [true, true]);
  assert.ok(value.slots[0].chapter && value.slots[0].saved_at, 'slot metadata survives browser restart');
  await control(page, 'slot_1', true);
  await stable(page);
  assert.equal(lineKey(await state(page)), lineKey(opening));
  result.checks.push('manual slots and metadata survive reload; no runtime errors');
  assert.deepEqual(errors, []);
  console.log(`PASS save slots: ${result.checks.length} check groups`);
  await context.close();
}

async function phase3Route() {
  const { context, page, errors } = await openPage({ width: 390, height: 844 }, true);
  const result = { route: 'phase3-touch', checks: [], errors };
  report.runs.push(result);
  await control(page, 'begin', true);
  await stable(page);
  await activateSkip(page, true);
  await waitFor(page, () => window.__debtQA?.screen === 'investigate', null, 30000);
  let value = await state(page);
  assert.equal(value.node_id, 'phase3_open');
  assert.equal(value.phase3.hotspots.length, 1);
  assert.equal(value.phase3.hotspots[0].checked, false);
  assert.ok(!value.controls.investigate_continue, 'investigation stays gated until inspection');
  await screenshot(page, 'phase3-investigate-phone');
  // The wastebasket lies low and to the left in the picture: fold the reading box, then drag
  // the picture until the spot is in reach.
  await control(page, 'investigate_collapse', true);
  await waitFor(page, () => window.__debtQA?.phase3?.investigate_collapsed === true, null, 10000);
  value = await state(page);
  let spot = value.phase3.hotspots[0];
  const from = { x: value.viewport.width / 2, y: value.viewport.height * 0.35 };
  const shift = value.game.x + value.game.width / 2 - (spot.screen_rect.x + spot.screen_rect.width / 2);
  await gesture(page, value.viewport, from, { x: from.x + shift, y: from.y }, 50, true);
  await page.waitForTimeout(300);
  value = await state(page);
  spot = value.phase3.hotspots[0];
  assert.equal(spot.checked, false, 'a drag searches nothing');
  assertInside(spot.rect, value.viewport, 'investigation spot after dragging the picture');
  result.checks.push('touch investigation folds the box, drags the picture and gates continuation');

  await tapAt(page, value.viewport, center(spot.rect), true);
  await waitFor(page, () => window.__debtQA?.phase3?.hotspots?.[0]?.checked, null, 10000);
  value = await state(page);
  assert.deepEqual(value.items, ['milk_bottle']);
  assert.ok(value.controls.investigate_continue, 'the last clue brings back the box with Continue');
  await openSaveSlots(page, true);
  await control(page, 'slot_1', true);
  await closeSaveSlots(page, true);
  await stable(page);
  assert.equal((await state(page)).screen, 'investigate');
  await control(page, 'investigate_continue', true);
  await waitFor(page, () => window.__debtQA?.screen === 'boke_round', null, 10000);
  value = await state(page);
  assert.equal(value.phase3.boke_line_index, 0);
  assert.equal(value.phase3.gameplay.glasses, 5);
  assert.equal(value.sprites.gintoki.visible, true, 'Gintoki is visible while speaking');
  assert.equal(value.sprites.gintoki.position, 'right');
  assertInside(value.controls.boke_tsukkomi, value.viewport, 'Tsukkomi action');
  result.checks.push('hotspot grants one clue, manual slot saves it, and boke round starts');

  // Reading and listening belong to the statement screen; the choice timer starts later.
  await page.waitForTimeout(8500);
  value = await state(page);
  assert.equal(value.screen, 'boke_round', 'reading for longer than eight seconds does not fail');
  assert.equal(value.phase3.gameplay.glasses, 5);
  await control(page, 'boke_next', true);
  value = await state(page);
  assert.equal(value.phase3.boke_line_index, 1);
  await control(page, 'boke_listen', true);
  value = await state(page);
  assert.equal(value.phase3.boke_listened, true);
  assert.match(value.text, /自動幫忙喝牛奶/);
  await screenshot(page, 'phase3-boke-phone');
  result.checks.push('statement navigation and Listen work without an active countdown');

  await control(page, 'boke_tsukkomi', true);
  await waitFor(page, () => window.__debtQA?.screen === 'tsukkomi', null, 10000);
  value = await state(page);
  assert.equal(value.choices.length, 4);
  assert.ok(value.phase3.timer_remaining > 0 && value.phase3.timer_remaining <= 8);
  assert.ok(value.choices.some(choice => choice.id === 'point_to_bottle'));
  value.choices.forEach(choice => {
    assertInside(choice.rect, value.viewport, `390×844 ${choice.id}`);
    assertContained(choice.rect, value.choice_sheet?.width ? value.choice_sheet : value.dialog, `390×844 ${choice.id}`);
  });
  await screenshot(page, 'phase3-tsukkomi-phone');
  await page.setViewportSize({ width: 320, height: 568 });
  await page.waitForTimeout(250);
  const narrow = await state(page);
  narrow.choices.forEach(choice => {
    assertInside(choice.rect, narrow.viewport, `320×568 ${choice.id}`);
    assertContained(choice.rect, narrow.choice_sheet?.width ? narrow.choice_sheet : narrow.dialog, `320×568 ${choice.id}`);
  });
  await screenshot(page, 'phase3-tsukkomi-320x568');
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(250);
  value = await state(page);
  const beforePause = value.phase3.timer_remaining;
  await controlAny(page, ['menu', 'toolbar_menu', 'menu_open'], true, 'single menu control');
  await page.waitForTimeout(1200);
  value = await state(page);
  assert.equal(value.screen, 'menu');
  assert.ok(Math.abs(value.phase3.timer_remaining - beforePause) < 0.7, 'menu pauses the choice timer');
  await controlAny(page, ['menu_close', 'menu_resume', 'resume'], true, 'menu close/resume');
  result.checks.push('Tsukkomi opens four clue-filtered choices inside the unified bottom sheet; the eight-second timer pauses in menu and options fit 320×568');

  await openSaveSlots(page, true);
  await control(page, 'slot_2', true);
  await closeSaveSlots(page, true);
  await stable(page);
  await page.reload({ waitUntil: 'load', timeout: 120000 });
  await waitFor(page, () => window.__debtQA?.screen === 'title', null, 120000);
  await control(page, 'title_load', true);
  await control(page, 'slot_2', true);
  await waitFor(page, () => window.__debtQA?.screen === 'tsukkomi', null, 10000);
  value = await state(page);
  assert.deepEqual(value.items, ['milk_bottle']);
  assert.equal(value.phase3.boke_line_index, 1);
  assert.equal(value.phase3.boke_listened, true);
  assert.ok(value.phase3.timer_remaining > 0);
  result.checks.push('manual slot restores selected line, Listen state, clue, and remaining countdown after reload');

  const perfect = value.choices.find(choice => choice.id === 'point_to_bottle');
  assert.ok(perfect, 'clue-gated perfect comeback remains selectable after loading');
  await tapAt(page, value.viewport, center(perfect.rect), true);
  await waitFor(page, () => window.__debtQA?.node_id === 'perfect', null, 10000);
  value = await state(page);
  assert.equal(value.phase3.last_result, 'perfect');
  assert.equal(value.phase3.gameplay.power, 30);
  assert.equal(value.phase3.gameplay.glasses, 5);
  await waitFor(page, () => window.__debtQA?.text_complete, null, 10000);
  await screenshot(page, 'phase3-perfect-phone');
  result.checks.push('perfect result adds power once and keeps glasses intact');
  assert.deepEqual(errors, [], 'no browser or Godot runtime errors');
  console.log(`PASS phase3 touch: ${result.checks.length} check groups`);
  await context.close();
}

// Round v2 by touch in the rounds sample: the censor bar while reading, material options, the
// super once the gauge is full, and a real tap on the QTE (at once, so it is early).
async function roundsRoute() {
  const { context, page, errors } = await openPage({ width: 390, height: 844 }, true);
  const result = { route: 'rounds-touch', checks: [], errors };
  report.runs.push(result);
  // stable() does not know the QTE screen, and the ring times out on its own, so wait for either.
  const readTo = async screen => {
    for (let step = 0; step < 80; step++) {
      await page.waitForFunction(target => [target, 'story', 'choice', 'end', 'boke_round', 'tsukkomi']
        .includes(window.__debtQA?.screen), screen, { timeout: 30000 });
      const value = await state(page);
      if (value.screen === screen) return value;
      if (value.screen === 'story') await next(page, true);
      else await page.waitForTimeout(150);
    }
    throw new Error(`Did not reach ${screen}`);
  };
  const goToLine = async target => {
    for (let step = 0; step < 6; step++) {
      const value = await state(page);
      if (value.phase3.boke_line_index === target) return;
      await control(page, value.phase3.boke_line_index < target ? 'boke_next' : 'boke_previous', true);
    }
    throw new Error(`Could not browse to line ${target + 1}`);
  };
  const choose = async id => {
    const value = await state(page);
    const option = value.choices.find(choice => choice.id === id);
    assert.ok(option, `option ${id} is offered`);
    assertInside(option.rect, value.viewport, `option ${id}`);
    await tapAt(page, value.viewport, center(option.rect), true);
  };

  await control(page, 'begin', true);
  let value = await readTo('boke_round');
  assert.equal(value.phase3.round.mode, 'testimony');
  await page.setViewportSize({ width: 320, height: 568 });
  await page.waitForTimeout(500);
  value = await state(page);
  assertInside(value.dialog, value.viewport, '320×568 dialogue box');
  for (const name of ['boke_next', 'boke_listen', 'boke_tsukkomi']) {
    assert.ok(value.controls[name], `320×568 keeps ${name} tappable`);
    assertInside(value.controls[name], value.viewport, `320×568 ${name}`);
  }
  await screenshot(page, 'rounds-reading-320x568');
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(500);
  result.checks.push('the round bar fits a 320×568 phone');
  await goToLine(2);
  value = await state(page);
  assert.ok(value.phase3.round.censor && value.controls.censor, 'line 3 offers its censor bar while reading');
  assertInside(value.controls.censor, value.viewport, 'censor bar');
  await screenshot(page, 'rounds-censor-phone');
  await control(page, 'censor', true);
  value = await readTo('boke_round');
  assert.ok(value.phase3.round.caught.includes('l3'), 'tapping the censor bar catches line 3');
  result.checks.push('the censor bar is a touch target and catches its line without a timer');

  for (const line of [1, 3]) {
    await goToLine(line);
    await control(page, 'boke_tsukkomi', true);
    await waitFor(page, () => window.__debtQA?.screen === 'tsukkomi', null, 10000);
    await choose('a');
    await readTo(line === 1 ? 'boke_round' : 'tsukkomi');
  }
  value = await state(page);
  assert.equal(value.phase3.round.mode, 'combo');
  assert.ok(!value.controls.super, 'no super before the gauge is full');
  result.checks.push('material options catch lines 2 and 4; the combo round opens by itself');

  await choose('a');
  value = await readTo('tsukkomi');
  assert.ok(value.phase3.round.super_available && value.controls.super, 'the full gauge lights the super');
  assertInside(value.controls.super, value.viewport, 'super');
  await screenshot(page, 'rounds-super-phone');
  await control(page, 'super', true);
  value = await readTo('qte');
  assert.ok(value.phase3.round.qte_active && value.controls.qte, 'the QTE line shows its ring');
  await screenshot(page, 'rounds-qte-phone');
  const glasses = value.phase3.gameplay.glasses;
  await tapAt(page, value.viewport, center(value.controls.qte), true);
  await waitFor(page, () => window.__debtQA?.node_id === 'r2_qte_early', null, 10000);
  value = await state(page);
  assert.equal(value.phase3.gameplay.glasses, glasses - 1, 'an early tap is a fail');
  assert.equal(value.step_index, 0, 'the tap that answered the QTE does not also advance the reaction');
  result.checks.push('the super fires by touch; a real tap on the QTE is judged (early) and not reused');
  assert.deepEqual(errors, [], 'no browser or Godot runtime errors');
  console.log(`PASS rounds touch: ${result.checks.length} check groups`);
  await context.close();
}

try {
  if (smokeOnly) {
    await touchSmoke();
  } else if (slotsOnly) {
    await slotsRoute();
  } else if (phase3Only) {
    await phase3Route();
  } else if (roundsOnly) {
    await roundsRoute();
  } else if (phase2Only) {
    await phase2Route('inspect', true);
    await phase2Route('skip', false);
  } else {
    await playRoute('A', { width: 1280, height: 900 }, false);
    await playRoute('B', { width: 390, height: 844 }, true);
  }
  report.passed = true;
} catch (error) {
  report.passed = false;
  report.failure = error.stack;
  for (const context of browser.contexts()) {
    for (const page of context.pages()) {
      try { await screenshot(page, 'failure'); report.failureState = await state(page); } catch {}
    }
  }
  process.exitCode = 1;
  console.error(error.stack);
} finally {
  report.finished = new Date().toISOString();
  const reportName = smokeOnly ? 'smoke-report.json' : slotsOnly ? 'slots-report.json'
    : phase3Only ? 'phase3-report.json' : roundsOnly ? 'rounds-report.json' : phase2Only ? 'phase2-report.json' : 'browser-report.json';
  await fs.writeFile(path.join(output, reportName), `${JSON.stringify(report, null, 2)}\n`);
  await browser.close();
  console.log(`Evidence: ${output}`);
}
