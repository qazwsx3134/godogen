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
const investigateOnly = process.argv.includes('--investigate');
const comedyOnly = process.argv.includes('--comedy');
const choicesOnly = process.argv.includes('--choices');
const ep00Only = process.argv.includes('--ep00');
const arg = (name, fallback) => {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : fallback;
};
const { chromium } = require(arg('--playwright', '@playwright/test'));
const url = new URL(arg('--url', 'http://127.0.0.1:5193/'));
url.searchParams.set('qa', '1');
if (phase3Only) url.searchParams.set('sample', 'phase3');
else if (roundsOnly) url.searchParams.set('sample', 'phase4_rounds');
else if (investigateOnly) url.searchParams.set('sample', 'phase4');
else if (comedyOnly) url.searchParams.set('sample', 'comedy');
else if (choicesOnly) url.searchParams.set('sample', 'choices');
else if (ep00Only) url.searchParams.set('sample', 'ep00');
else if (phase2Only || slotsOnly) url.searchParams.set('sample', 'phase2');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(root, 'test-results');
const docs = path.join(root, 'docs');
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

async function screenshot(page, name, dir = output) {
  await page.screenshot({ path: path.join(dir, `${name}.png`), fullPage: true });
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
  await page.waitForTimeout(1500);  // the browser's file system flushes to IndexedDB in the background; a reload right after the save can lose it
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

// Round v2 by touch in the rounds sample: the censor bar while reading, material options,
// Elisabeth's placard (tapped while reading, then glowing beside the timed sheet on a 320×568
// phone without being covered), the super once the gauge is full, and a real tap on the QTE (at
// once, so it is early).
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
    await readTo('boke_round');
  }
  value = await state(page);
  assert.equal(value.node_id, 'k_round', 'Kagura\'s testimony follows');
  assert.ok(value.sprites.elisabeth.visible && value.placard.holder_visible, 'Elisabeth came on stage without a line');
  assert.equal(value.placard.text, '', 'line 1: the placard is blank');
  assert.ok(!value.controls.placard, 'a blank placard is not a control');
  result.checks.push('material options catch lines 2 and 4; Kagura\'s round opens with Elisabeth and a blank placard');

  // Line 2 while reading: the placard reads 犯人是神樂 and a touch on it catches the line.
  await goToLine(1);
  value = await state(page);
  assert.equal(value.placard.text, '犯人是神樂');
  assert.ok(value.phase3.round.placard && value.controls.placard, 'line 2 offers the placard while reading');
  assertInside(value.controls.placard, value.viewport, 'placard');
  const atLeast48 = async (rect, label) => {
    const bounds = await page.locator('canvas').boundingBox();
    const perCss = value.viewport.width / bounds.width;  // logical Godot px per CSS px
    assert.ok(rect.width >= 48 * perCss - 1 && rect.height >= 48 * perCss - 1,
      `${label} is at least 48 CSS px each way: ${JSON.stringify({ rect, perCss })}`);
  };
  await atLeast48(value.controls.placard, 'the placard');
  assert.ok(value.controls.placard.y + value.controls.placard.height <= value.dialog.y + 1, 'the reading box leaves the placard uncovered');
  await screenshot(page, 'rounds-placard-reading-phone');

  // On a 320×568 phone the timed sheet opens beside the glowing placard without covering it.
  await page.setViewportSize({ width: 320, height: 568 });
  await page.waitForTimeout(500);
  await control(page, 'boke_tsukkomi', true);
  value = await waitFor(page, () => window.__debtQA?.screen === 'tsukkomi' && window.__debtQA?.placard?.glowing, null, 10000)
    .then(() => state(page));
  assert.ok(value.controls.placard, `the glowing placard stays tappable next to the sheet: ${Object.keys(value.controls).join(', ')}`);
  assertInside(value.controls.placard, value.viewport, '320×568 placard');
  await atLeast48(value.controls.placard, 'the 320×568 placard');
  assert.ok(value.controls.placard.y + value.controls.placard.height <= value.choice_sheet.y + 1,
    `the options sheet does not cover the placard: ${JSON.stringify({ placard: value.controls.placard, sheet: value.choice_sheet })}`);
  value.choices.forEach(choice => assertInside(choice.rect, value.viewport, `320×568 ${choice.id}`));
  await screenshot(page, 'rounds-placard-sheet-320x568');
  await tapAt(page, value.viewport, center(value.controls.placard), true);
  await waitFor(page, () => window.__debtQA?.node_id === 'k_l2_placard', null, 10000);
  value = await readTo('boke_round');
  assert.ok(value.phase3.round.caught.includes('l2'), 'the placard catches line 2');
  assert.equal(value.placard.text, '我只是路過', 'the scene flipped the placard');
  assert.ok(!value.placard.glowing && !value.controls.placard, 'an answered placard is no longer a control');
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(500);
  result.checks.push('the placard is a ≥48 CSS px touch target while reading and beside the uncovered timed sheet at 320×568');

  for (const line of [0, 2]) {
    await goToLine(line);
    await control(page, 'boke_tsukkomi', true);
    await waitFor(page, () => window.__debtQA?.screen === 'tsukkomi', null, 10000);
    await choose('a');
    await readTo(line === 0 ? 'boke_round' : 'tsukkomi');
  }
  value = await state(page);
  assert.equal(value.phase3.round.mode, 'combo');
  assert.ok(!value.sprites.elisabeth.visible, 'Elisabeth leaves before the combo');
  result.checks.push('Kagura\'s round is caught by touch; the combo round opens by itself');

  assert.ok(value.phase3.round.super_available && value.controls.super, 'two perfect testimonies fill the gauge: the super is lit at once');
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

// The Phase 4 search by touch: 對話 and 移動 topics in the reading box (≥48 CSS px, inside a
// 320×568 phone), a topic scene that comes back to the search without its topic, the kitchen with
// its own picture and fridge (whose scene has Gintoki answer from off stage), and the way home.
async function investigateRoute() {
  const { context, page, errors } = await openPage({ width: 390, height: 844 }, true);
  const result = { route: 'investigate-touch', checks: [], errors };
  report.runs.push(result);
  const atLeast48 = async (rect, label) => {
    const bounds = await page.locator('canvas').boundingBox();
    const perCss = (await state(page)).viewport.width / bounds.width;
    assert.ok(rect.width >= 48 * perCss - 1 && rect.height >= 48 * perCss - 1, `${label} is at least 48 CSS px: ${JSON.stringify(rect)}`);
  };
  const readToSearch = async () => {
    for (let step = 0; step < 40; step++) {
      await page.waitForFunction(() => ['story', 'investigate'].includes(window.__debtQA?.screen), null, { timeout: 30000 });
      const value = await state(page);
      if (value.screen === 'investigate') return value;
      await next(page, true);
    }
    throw new Error('Did not come back to the search');
  };
  await control(page, 'begin', true);
  await stable(page);
  await activateSkip(page, true);
  await waitFor(page, () => window.__debtQA?.screen === 'investigate', null, 30000);
  let value = await state(page);
  assert.equal(value.node_id, 'search');
  assert.deepEqual(value.phase3.investigation.talk, ['gintoki_bedtime', 'kagura_dinner'], 'two topics before the footprints');
  assert.deepEqual(value.phase3.investigation.moves, ['kitchen']);
  const topics = ['talk_gintoki_bedtime', 'talk_kagura_dinner', 'move_kitchen'];
  for (const name of topics) {
    assert.ok(value.controls[name], `${name} is offered`);
    assertInside(value.controls[name], value.viewport, name);
    await atLeast48(value.controls[name], name);
    assertContained(value.controls[name], value.dialog, name);
  }
  await screenshot(page, 'investigate-topics-phone');
  await page.setViewportSize({ width: 320, height: 568 });
  await page.waitForTimeout(500);
  value = await state(page);
  for (const name of [...topics, 'investigate_continue']) {
    if (name === 'investigate_continue' && !value.controls[name]) continue;
    assert.ok(value.controls[name], `320×568 keeps ${name}`);
    assertInside(value.controls[name], value.viewport, `320×568 ${name}`);
    await atLeast48(value.controls[name], `320×568 ${name}`);
  }
  await screenshot(page, 'investigate-topics-320x568');
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(500);
  result.checks.push('talk and move topics are ≥48 CSS px touch targets inside the reading box on 390×844 and 320×568');

  await control(page, 'talk_kagura_dinner', true);
  await waitFor(page, () => window.__debtQA?.screen === 'story', null, 10000);
  value = await state(page);
  assert.equal(value.speaker, 'kagura', 'the topic plays Kagura\'s answer');
  value = await readToSearch();
  assert.deepEqual(value.phase3.investigation.talk, ['gintoki_bedtime'], 'a played topic is gone');
  assert.ok(!value.controls.talk_kagura_dinner && !value.sprites.kagura.visible, 'back in the search with the stage cleared');
  result.checks.push('a talk topic plays once by touch and the search comes back');

  await control(page, 'move_kitchen', true);
  await waitFor(page, () => window.__debtQA?.background === 'yorozuya_kitchen' && window.__debtQA?.screen === 'investigate', null, 10000);
  value = await state(page);
  assert.equal(value.phase3.investigation.place, 'kitchen');
  assert.deepEqual(value.phase3.hotspots.map(spot => spot.id), ['fridge']);
  assert.ok(value.controls.move_home, 'the kitchen offers the way back');
  await screenshot(page, 'investigate-kitchen-phone');
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
  assert.ok(spot.rect?.width > 0, `the fridge is within reach after dragging: ${JSON.stringify(spot)}`);
  await tapAt(page, value.viewport, center(spot.rect), true);
  for (let step = 0; step < 10; step++) {
    await page.waitForFunction(() => ['story', 'investigate'].includes(window.__debtQA?.screen), null, { timeout: 10000 });
    value = await state(page);
    if (value.speaker === 'gintoki') break;
    await next(page, true);
  }
  assert.equal(value.speaker, 'gintoki', 'Gintoki answers about the pudding');
  assert.equal(value.sprites.gintoki.visible, false, 'he speaks from off stage');
  assert.ok(value.name_plate.width > 0, 'his name still shows');
  await screenshot(page, 'investigate-offscreen-phone');
  value = await readToSearch();
  assert.equal(value.phase3.investigation.place, 'home', 'the searched-out kitchen sends the player home');
  assert.equal(value.background, 'yorozuya_living_room');
  assert.deepEqual(value.items, [], 'the fridge grants no material');
  result.checks.push('moving to the kitchen shows its own picture and spot; its scene has an off-stage line and returns home');
  assert.deepEqual(errors, [], 'no browser or Godot runtime errors');
  console.log(`PASS investigate touch: ${result.checks.length} check groups`);
  await context.close();
}


// The manga overlay (?sample=comedy): every preset plays over the reading screen, a tap on one only ends
// it (the line after it shows whole and is not advanced), and the overlay never survives a reload.
// Run at 390×844 and 320×568; the screenshots go to docs/.
async function comedyRoute(viewport, tag) {
  const { context, page, errors } = await openPage(viewport, true);
  const result = { route: `comedy-${tag}`, viewport, touch: true, checks: [], errors };
  report.runs.push(result);
  const story = JSON.parse(await fs.readFile(path.join(root, 'data', 'comedy_story.json'), 'utf8'));
  const comedies = [];
  for (const [nodeId, node] of Object.entries(story.nodes)) {
    node.steps.forEach((step, index) => {
      if (step.op === 'comedy') comedies.push({ node: nodeId, index, preset: step.preset, next: node.steps[index + 1] });
    });
  }
  const impacts = comedies.filter(entry => entry.preset === 'tsukkomi_impact');
  assert.ok(impacts.length >= 2 && comedies.some(entry => entry.preset === 'small_reaction')
    && comedies.some(entry => entry.preset === 'full_manga_panel'), 'the sample holds every preset, and the impact twice');
  assert.equal(impacts[0].next.op, 'say', 'an ordinary line follows the impact at once');

  const overlay = value => value.comedy?.active === true;
  // Taps through ordinary lines until the given preset starts playing; resolves with that state.
  const readToComedy = async preset => {
    for (let step = 0; step < 40; step++) {
      await waitFor(page, () => window.__debtQA && (window.__debtQA.comedy?.active || window.__debtQA.screen === 'story'), null, 30000);
      let value = await state(page);
      if (overlay(value)) {
        if (value.comedy.preset === preset) return value;
        await waitFor(page, () => !window.__debtQA.comedy?.active, null, 8000);  // another preset: let it pass
        continue;
      }
      await waitFor(page, () => window.__debtQA?.text_complete || window.__debtQA?.comedy?.active, null, 10000);
      value = await state(page);
      if (overlay(value)) continue;
      const before = lineKey(value);
      await controlAny(page, ['dialogue', 'advance', 'next'], true, 'dialogue advance');
      await waitFor(page, previous => {
        const v = window.__debtQA;
        return v && (v.comedy?.active || (v.screen === 'story' && `${v.node_id}:${v.step_index}` !== previous));
      }, before, 10000);
    }
    throw new Error(`Never reached the ${preset} preset`);
  };
  const finishOverlay = async () => {
    await waitFor(page, () => window.__debtQA && !window.__debtQA.comedy?.active, null, 8000);
    await waitFor(page, () => window.__debtQA?.screen === 'story' || window.__debtQA?.screen === 'end', null, 8000);
  };

  await control(page, 'begin', true);
  await stable(page);

  // 1. tsukkomi_impact: in play the layer is on screen and the story waits; it ends by itself.
  let value = await readToComedy('tsukkomi_impact');
  assert.equal(value.comedy.preset, 'tsukkomi_impact');
  assert.equal(value.screen, 'busy', 'the story waits while the overlay plays');
  const waiting = lineKey(value);
  await page.waitForTimeout(450);
  value = await state(page);
  assert.ok(overlay(value), 'the impact is still playing 0.45 s in');
  assert.ok(value.comedy.burst && value.comedy.text, 'the balloon and its line are on screen');
  const inside = (rect, outer, label) => assert.ok(rect.x >= outer.x - 1 && rect.y >= outer.y - 1
    && rect.x + rect.width <= outer.x + outer.width + 1 && rect.y + rect.height <= outer.y + outer.height + 1,
  `${label} lies outside the game area: ${JSON.stringify({ rect, outer })}`);
  inside(value.comedy.burst, value.game, 'the balloon');
  inside(value.comedy.text, value.comedy.burst, 'the big line (in the balloon)');
  inside(value.comedy.text, value.game, 'the big line');
  assert.equal(value.comedy.text_fits, true, 'the whole line fits its box (not clipped)');
  await screenshot(page, `preview-comedy-impact-${tag}`, docs);
  assert.equal(lineKey(await state(page)), waiting, 'the story did not move while the overlay played');
  await finishOverlay();
  value = await state(page);
  assert.equal(`${value.node_id}:${value.step_index}`, `${impacts[0].node}:${impacts[0].index + 1}`, 'the line after the impact shows');
  assert.equal(value.comedy.active, false);
  await waitFor(page, () => window.__debtQA?.text_complete, null, 10000);
  value = await state(page);
  assert.equal(value.text, impacts[0].next.text, 'the line after the impact is complete');
  result.checks.push(`tsukkomi_impact plays over the reading screen (comedy.active), the story waits, then the next line shows whole (${tag})`);

  // 2. small_reaction: the reading box stays, and the line before it is already on screen.
  value = await readToComedy('small_reaction');
  assert.ok(value.dialog?.width > 0, 'small_reaction leaves the reading box in place');
  await page.waitForTimeout(250);
  if (tag === 'phone') await screenshot(page, 'preview-comedy-small-phone', docs);
  await finishOverlay();
  result.checks.push('small_reaction plays without covering the reading box');

  // 3. full_manga_panel plays to its end.
  value = await readToComedy('full_manga_panel');
  await page.waitForTimeout(500);
  await screenshot(page, `comedy-full-panel-${tag}`);
  await finishOverlay();
  result.checks.push('full_manga_panel plays to its end');

  // 4. A tap during the second impact only ends it: the next line shows whole and is current.
  value = await readToComedy('tsukkomi_impact');
  const target = impacts[1];
  assert.equal(`${value.node_id}:${value.step_index}`, `${target.node}:${target.index}`, 'the second impact is the one playing');
  await page.waitForTimeout(350);
  value = await state(page);
  assert.ok(overlay(value), 'still playing before the tap');
  assert.ok(value.controls.stage, 'the stage target is reachable during the overlay');
  const tappedAt = Date.now();
  await tapAt(page, value.viewport, center(value.controls.stage), true);
  await waitFor(page, () => !window.__debtQA.comedy?.active, null, 4000);
  const took = Date.now() - tappedAt;
  await waitFor(page, () => window.__debtQA?.screen === 'story', null, 8000);
  await page.waitForTimeout(500);
  value = await state(page);
  assert.equal(`${value.node_id}:${value.step_index}`, `${target.node}:${target.index + 1}`, 'the tap did not also advance: the next line is current');
  assert.equal(value.full_text, target.next.text, 'the next line, not the one after it');
  await waitFor(page, () => window.__debtQA?.text_complete, null, 10000);
  value = await state(page);
  assert.equal(value.text, target.next.text, 'the next line appears whole');
  assert.equal(`${value.node_id}:${value.step_index}`, `${target.node}:${target.index + 1}`, 'and is still current after it finished typing');
  result.checks.push(`a tap during tsukkomi_impact fast-forwards it (gone ${took} ms after the tap, browser clock) and shows the next line whole without advancing`);

  // 5. The story still ends normally and nothing is left over.
  await controlAny(page, ['dialogue', 'advance', 'next'], true, 'dialogue advance');
  await waitFor(page, () => window.__debtQA?.screen === 'end' || window.__debtQA?.screen === 'story', null, 8000);
  value = await state(page);
  assert.equal(value.comedy.active, false);
  assert.deepEqual(errors, [], 'no browser or Godot runtime errors');
  console.log(`PASS comedy ${tag}: ${result.checks.length} check groups`);
  await context.close();
}

// The two kinds of choice (?sample=choices): a POV choice (the edition's sheet, a tone marker on each row), then
// the director's choice (a sheet of its own: heading, footnote, cards). Real touch taps throughout.
// Run at 390×844 and 320×568; the screenshots go to docs/.
async function choicesRoute(viewport, tag) {
  const { context, page, errors } = await openPage(viewport, true);
  const result = { route: `choices-${tag}`, viewport, touch: true, checks: [], errors };
  report.runs.push(result);
  const story = JSON.parse(await fs.readFile(path.join(root, 'data', 'choices_story.json'), 'utf8'));
  const povStep = story.nodes.choices_open.steps.find(step => step.op === 'choice');
  const directorStep = story.nodes.choices_director.steps.find(step => step.op === 'choice');
  assert.equal(povStep.options.map(option => option.tone).join(), 'loud,calm,tired', 'the sample\'s POV choice has one of each tone');
  assert.equal(directorStep.perspective, 'director');
  const inside = (rect, outer, label) => assert.ok(rect.x >= outer.x - 1 && rect.y >= outer.y - 1
    && rect.x + rect.width <= outer.x + outer.width + 1 && rect.y + rect.height <= outer.y + outer.height + 1,
  `${label} lies outside the game area: ${JSON.stringify({ rect, outer })}`);
  const onChoice = async perspective => {
    await waitFor(page, expected => window.__debtQA?.screen === 'choice' && window.__debtQA.choice?.perspective === expected,
      perspective, 30000);
    return state(page);
  };
  // Taps through ordinary lines until a choice shows.
  const readToChoice = async perspective => {
    for (let step = 0; step < 40; step++) {
      await waitFor(page, () => window.__debtQA && ['story', 'choice'].includes(window.__debtQA.screen), null, 30000);
      let value = await state(page);
      if (value.screen === 'choice' && value.choice.perspective === perspective) return value;
      await waitFor(page, () => window.__debtQA?.text_complete || window.__debtQA?.screen === 'choice', null, 10000);
      value = await state(page);
      if (value.screen === 'choice') continue;
      const before = lineKey(value);
      await controlAny(page, ['dialogue', 'advance', 'next'], true, 'dialogue advance');
      await waitFor(page, previous => {
        const v = window.__debtQA;
        return v && v.screen !== 'busy' && `${v.node_id}:${v.step_index}` !== previous;
      }, before, 10000);
    }
    throw new Error(`Never reached the ${perspective} choice`);
  };
  const tapRow = async (value, index) => {
    assert.ok(value.choices[index], `row ${index} is on screen and tappable`);
    assertInside(value.choices[index].rect, value.viewport, `row ${index}`);
    await tapAt(page, value.viewport, center(value.choices[index].rect), true);
  };

  await control(page, 'begin', true);
  await stable(page);

  // 1. The POV choice: Shinpachi's thought in the edition's own sheet, each row with its tone marker.
  let value = await readToChoice('pov');
  await page.waitForTimeout(300);
  value = await state(page);
  assert.deepEqual(value.choice, { perspective: 'pov', pov: 'shinpachi', note: '', sheet: value.ui_style, tones: ['loud', 'calm', 'tired'] },
    'the POV choice: Shinpachi\'s, in the edition\'s sheet, with the three tones');
  assert.equal(value.speaker, 'shinpachi');
  assert.equal(value.sprites.shinpachi.focused, true, 'Shinpachi is in focus');
  assert.equal(value.choices.length, 3);
  for (const [index, row] of value.choices.entries()) {
    assert.equal(row.label, povStep.options[index].label);
    assert.ok(row.rect.height / (value.game.width / viewport.width) >= 48 - 0.1, `row ${index} is at least 48 CSS px tall`);
    inside(row.rect, value.game, `row ${index}`);
  }
  assert.ok(value.choice_sheet.width > 0);
  inside(value.choice_sheet, value.game, 'the POV sheet');
  await screenshot(page, tag === 'phone' ? 'preview-choice-pov-phone' : 'choices-pov-narrow', tag === 'phone' ? docs : output);
  result.checks.push(`the POV choice shows Shinpachi's thought in the ${value.ui_style} sheet with tones loud, calm, tired; every row is at least 48 CSS px (${tag})`);

  // 2. The loud row, tapped: it leads to its own reaction and sets its flag.
  await tapRow(value, 0);
  await waitFor(page, () => window.__debtQA?.screen === 'story' && window.__debtQA.flags?.reply === 'loud', null, 15000);
  value = await state(page);
  const loud = povStep.options[0];
  assert.equal(value.node_id, loud.next, 'the loud row goes to its own reaction');
  await waitFor(page, () => window.__debtQA?.text_complete, null, 10000);
  value = await state(page);
  const reaction = story.nodes[loud.next].steps.find(step => step.op === 'say');
  assert.equal(value.text, reaction.text, 'and Gintoki answers with the loud reaction');
  assert.equal(value.flags.reply, 'loud');
  result.checks.push(`tapping the "loud" row goes to ${loud.next}, shows its reaction line and sets reply=loud (${tag})`);

  // 3. The director's choice: the director's sheet, the footnote, cards; nobody changes on stage.
  const stageBefore = (await readToChoice('director')).sprites;
  value = await state(page);
  assert.equal(value.screen === 'busy' || value.screen === 'choice', true);
  await waitFor(page, () => window.__debtQA?.screen === 'choice', null, 5000);  // busy until the sheet has sprung in
  value = await state(page);
  assert.deepEqual(value.choice, { perspective: 'director', pov: '', note: directorStep.note, sheet: 'director', tones: ['', '', ''] },
    'the director\'s choice: its own sheet with the footnote and no tones');
  assert.equal(value.speaker, '', 'nobody is speaking');
  assert.deepEqual(value.sprites, stageBefore, 'nobody came on stage or into focus');
  assert.equal(value.choices.length, directorStep.options.length);
  for (const [index, row] of value.choices.entries()) {
    assert.equal(row.label, directorStep.options[index].label);
    assert.ok(row.rect.height / (value.game.width / viewport.width) >= 48 - 0.1, `card ${index} is at least 48 CSS px tall`);
    inside(row.rect, value.game, `card ${index}`);
  }
  inside(value.choice_sheet, value.game, 'the director\'s sheet');
  assert.ok(value.controls.menu, '目錄 is on the director\'s sheet too');
  inside(value.controls.menu, value.game, '目錄');
  await screenshot(page, `preview-choice-director-${tag}`, docs);
  result.checks.push(`the director's choice: sheet=director, footnote "${directorStep.note}", ${value.choices.length} cards each at least 48 CSS px, stage unchanged (${tag})`);

  // 4. 目錄 over the director's choice: changing the edition keeps the director's sheet.
  const styleOrder = ['cinema', 'ledger', 'manga'];
  const other = styleOrder.find(style => style !== value.ui_style);
  await controlAny(page, ['menu'], true, '目錄');
  await waitFor(page, () => window.__debtQA?.screen === 'menu', null, 10000);
  await control(page, `menu_style_${other}`, true);
  await waitFor(page, expected => window.__debtQA?.ui_style === expected, other, 10000);
  value = await state(page);
  assert.equal(value.ui_style, other, `the edition is now ${other}`);
  assert.equal(value.choice.sheet, 'director', 'the director\'s sheet is still the one under 目錄');
  await controlAny(page, ['menu_close', 'menu_resume'], true, 'menu close');
  await waitFor(page, () => window.__debtQA?.screen === 'choice', null, 10000);
  value = await state(page);
  assert.deepEqual(value.choice, { perspective: 'director', pov: '', note: directorStep.note, sheet: 'director', tones: ['', '', ''] });
  assert.equal(value.choices.length, directorStep.options.length, 'all the cards are still there');
  inside(value.choice_sheet, value.game, 'the director\'s sheet after the edition changed');
  await screenshot(page, `choices-director-${other}-${tag}`);
  result.checks.push(`changing the edition (${other}) from 目錄 over the director's choice keeps the director's sheet and its cards (${tag})`);

  // 5. A card, tapped: its branch, its flag, and the end.
  const picked = directorStep.options[1];
  await tapRow(value, 1);
  await waitFor(page, expected => window.__debtQA?.node_id === expected, picked.next, 15000);
  value = await state(page);
  assert.equal(value.flags.ep00_ending, picked.set_flags.ep00_ending, 'the card sets ep00_ending');
  await activateSkip(page, true);
  await waitFor(page, () => window.__debtQA?.screen === 'end', null, 30000);
  value = await state(page);
  assert.equal(value.flags.ep00_ending, 'request');
  assert.equal(value.flags.reply, 'loud');
  assert.deepEqual(errors, [], 'no browser or Godot runtime errors');
  result.checks.push(`card "${picked.label}" goes to ${picked.next}, sets ep00_ending=${value.flags.ep00_ending} and the story ends (${tag})`);
  console.log(`PASS choices ${tag}: ${result.checks.length} check groups`);
  await context.close();
}

// EP00 (?sample=ep00), the vertical slice, by real touch. Path A: scene one, the POV choice, the loud row's overlay, the search
// (Gintoki's three lines, the milk, the job document), the director's third card and its ending. Path B: the tired row, the
// search without the job, the director's first card; a manual slot saved in the search and one at the director's choice, the page
// reloaded, both loaded and found at the same event. At 320×568 path A runs as far as the search. Screenshots go to docs/.
function ep00Tools(page) {
  // One tap on the reading box (finishing the line first when it is still typing); returns when the story has moved
  // or an overlay has started.
  const advance = async () => {
    await waitFor(page, () => window.__debtQA && (window.__debtQA.text_complete
      || ['choice', 'investigate', 'end'].includes(window.__debtQA.screen)), null, 20000);
    const before = await state(page);
    if (before.screen !== 'story') return;
    await controlAny(page, ['dialogue', 'advance', 'next'], true, 'dialogue advance');
    await waitFor(page, previous => {
      const v = window.__debtQA;
      return v && (v.comedy?.active || (v.screen !== 'busy' && `${v.node_id}:${v.step_index}` !== previous));
    }, lineKey(before), 20000);
  };
  // Taps through ordinary lines until done(state); every line met on the way is appended to `seen`.
  const readUntil = async (done, label, seen = [], limit = 80) => {
    for (let step = 0; step < limit; step++) {
      await waitFor(page, () => { const v = window.__debtQA; return v && (v.comedy?.active || ['story', 'choice', 'investigate', 'end'].includes(v.screen)); }, null, 30000);
      const value = await state(page);
      if (value.comedy?.active) {
        await waitFor(page, () => !window.__debtQA.comedy?.active, null, 10000);
        continue;
      }
      if (value.screen === 'story' && !seen.some(entry => entry.key === lineKey(value))) {
        seen.push({ key: lineKey(value), node: value.node_id, speaker: value.speaker, text: value.full_text });
      }
      if (done(value)) return value;
      if (value.screen !== 'story') throw new Error(`${label}: stopped on ${value.screen} at ${key(value)}`);
      await advance();
    }
    throw new Error(`${label}: not reached within ${limit} taps`);
  };
  const completeLine = () => waitFor(page, () => window.__debtQA?.text_complete, null, 15000);
  const spotOf = (value, id) => value.phase3.hotspots.find(entry => entry.id === id);
  // Folds the reading box and drags the picture until the spot's tap area is on screen (the strip left of Gintoki).
  const bringIntoReach = async id => {
    let value = await state(page);
    if (!value.phase3.investigate_collapsed) {
      await control(page, 'investigate_collapse', true);
      await waitFor(page, () => window.__debtQA?.phase3?.investigate_collapsed === true, null, 10000);
      value = await state(page);
    }
    const hit = spotOf(value, id).screen_rect;
    const targetX = Math.max(value.game.x + value.game.width * 0.18, value.game.x + hit.width / 2 + 4);
    const shift = targetX - (hit.x + hit.width / 2);
    if (Math.abs(shift) > 40) {
      const from = { x: value.viewport.width / 2, y: value.viewport.height * 0.35 };
      await gesture(page, value.viewport, from, { x: from.x + shift, y: from.y }, 50, true);
      await page.waitForTimeout(300);
    }
    return spotOf(await state(page), id);
  };
  const tapSpot = async id => {
    const value = await state(page);
    const spot = spotOf(value, id);
    assert.ok(spot?.rect?.width > 0, `${id} is in reach of a tap: ${JSON.stringify(spot)}`);
    await tapAt(page, value.viewport, center(spot.rect), true);
  };
  const saveToSlot = async slot => {
    await openSaveSlots(page, true);
    await control(page, `slot_${slot}`, true);
    await closeSaveSlots(page, true);
    await stable(page);
  };
  // What "the same event" means after a save and a load.
  const picture = value => ({
    screen: value.screen, node_id: value.node_id, step_index: value.step_index, flags: value.flags, items: value.items,
    background: value.background,
    on_stage: Object.entries(value.sprites).filter(([, sprite]) => sprite.visible).map(([id, sprite]) => `${id}@${sprite.position}`).sort(),
    spots: (value.phase3.hotspots || []).map(spot => [spot.id, spot.checked]),
    choice: value.choice, labels: value.choices.map(row => row.label),
  });
  return { advance, readUntil, completeLine, spotOf, bringIntoReach, tapSpot, saveToSlot, picture };
}

async function ep00PathA(viewport, tag, firstHalf) {
  const { context, page, errors } = await openPage(viewport, true);
  const result = { route: `ep00-a-${tag}`, viewport, touch: true, checks: [], errors };
  report.runs.push(result);
  const story = JSON.parse(await fs.readFile(path.join(root, 'data', 'ep00_story.json'), 'utf8'));
  const says = nodeId => story.nodes[nodeId].steps.filter(step => step.op === 'say');
  const sceneOne = says('s01_open');
  const gintokiLines = [1, 2, 3].map(n => says(`s04_gintoki_${n}`)[0].text);
  const povStep = story.nodes.s02_pov.steps.find(step => step.op === 'choice');
  const directorStep = story.nodes.s06_open.steps.find(step => step.op === 'choice');
  const impactIndex = story.nodes.s03_loud.steps.findIndex(step => step.op === 'comedy');
  const tools = ep00Tools(page);
  const phone = tag === 'phone';
  const seen = [];
  const inside = (rect, outer, label) => assert.ok(rect.x >= outer.x - 1 && rect.y >= outer.y - 1
    && rect.x + rect.width <= outer.x + outer.width + 1 && rect.y + rect.height <= outer.y + outer.height + 1,
  `${label} lies outside the game area: ${JSON.stringify({ rect, outer })}`);
  const tapRow = async (value, index) => {
    assert.ok(value.choices[index], `row ${index} is on screen and tappable`);
    assertInside(value.choices[index].rect, value.viewport, `row ${index}`);
    await tapAt(page, value.viewport, center(value.choices[index].rect), true);
  };
  const rowsOk = (value, step, kind) => {
    assert.equal(value.choices.length, step.options.length);
    for (const [index, row] of value.choices.entries()) {
      assert.equal(row.label, step.options[index].label, `${kind} ${index} reads as the script says`);
      assert.ok(row.rect.height / (value.game.width / viewport.width) >= 48 - 0.1, `${kind} ${index} is at least 48 CSS px tall`);
      inside(row.rect, value.game, `${kind} ${index}`);
    }
  };

  await control(page, 'begin', true);
  await stable(page);

  // 1. Scene 01: the living room, the three on stage at their places, faces, typing, a tap that finishes a line, the dog off stage.
  let value = await tools.readUntil(v => v.full_text === sceneOne[0].text, 'the first line', seen);
  await tools.completeLine();
  value = await state(page);
  assert.equal(value.background, 'yorozuya_living_room', 'the living room is the background');
  assert.equal(value.speaker, 'gintoki');
  assert.equal(value.sprites.gintoki.expression, 'nosepick', 'Gintoki has the lazy face');
  assertLayout(value, `EP00 ${tag} first line`);
  assert.ok(value.name_plate.width > 0, 'the name plate shows');
  let revealed = 0;
  for (let index = 1; index < sceneOne.length; index++) {
    await tools.advance();
    await waitFor(page, text => window.__debtQA?.full_text === text, sceneOne[index].text, 10000);
    if (await reveal(page, true)) revealed += 1;
    await tools.completeLine();
    value = await state(page);
    assert.equal(value.speaker, sceneOne[index].speaker, `line ${index + 1} is said by ${sceneOne[index].speaker}`);
    if (index === 1) assert.equal(value.sprites.shinpachi.expression, 'angry');
    if (index === 2) {
      assert.deepEqual(['shinpachi', 'gintoki', 'kagura'].map(id => [value.sprites[id].visible, value.sprites[id].position]),
        [[true, 'left'], [true, 'center'], [true, 'right']], 'Shinpachi left, Gintoki centre, Kagura right');
      assert.equal(value.sprites.kagura.expression, 'smile');
      if (phone) await screenshot(page, 'preview-ep00-a-screen-phone', docs);
    }
    if (index === 3) {
      assert.equal(value.sprites.sadaharu.visible, false, 'the dog barks from off stage');
      assert.ok(value.name_plate.width > 0, 'but his name shows');
    }
    if (index === 4) assert.equal(value.sprites.gintoki.expression, 'smug', 'Gintoki changed his face for his excuse');
  }
  assert.ok(revealed >= 1, 'a tap on a line still being typed finishes it and does not go on');
  result.checks.push(`scene one: ${sceneOne.length} lines, living room, left/centre/right, faces change, typing, ${revealed} tap(s) finishing a line, the dog off stage (${tag})`);

  // 2. The POV choice: Shinpachi's thought in the edition's own sheet.
  value = await tools.readUntil(v => v.screen === 'choice', 'the POV choice', seen);
  await page.waitForTimeout(300);
  value = await state(page);
  assert.deepEqual(value.choice, { perspective: 'pov', pov: 'shinpachi', note: '', sheet: value.ui_style, tones: ['loud', 'calm', 'tired'] },
    'a POV choice: the edition\'s own sheet (not the director\'s), the three tones');
  assert.equal(value.speaker, 'shinpachi');
  rowsOk(value, povStep, 'row');
  inside(value.choice_sheet, value.game, 'the POV sheet');
  await screenshot(page, `preview-ep00-pov-${tag}`, docs);
  result.checks.push(`the POV choice is Shinpachi's thought in the ${value.ui_style} sheet, three rows loud/calm/tired, each at least 48 CSS px and inside the game area (${tag})`);

  // 3. The loud row: its branch and flag, then the overlay over the reading screen.
  await tapRow(value, 0);
  await waitFor(page, () => window.__debtQA?.flags?.pov_style === 'loud' && window.__debtQA.node_id === 's03_loud', null, 15000);
  await tools.completeLine();
  value = await state(page);
  assert.equal(value.full_text, '嗯？');
  await tools.advance();
  await waitFor(page, () => window.__debtQA?.comedy?.active, null, 8000);
  value = await state(page);
  assert.equal(value.comedy.preset, 'tsukkomi_impact');
  assert.equal(value.screen, 'busy', 'the story waits while the overlay plays');
  const waiting = lineKey(value);
  await page.waitForTimeout(450);
  value = await state(page);
  assert.ok(value.comedy.active && value.comedy.burst && value.comedy.text, 'the balloon and its line are on screen');
  inside(value.comedy.burst, value.game, 'the balloon');
  inside(value.comedy.text, value.comedy.burst, 'the big line (in the balloon)');
  assert.equal(value.comedy.text_fits, true, 'the whole line fits its box');
  assert.equal(lineKey(value), waiting, 'the story did not move while the overlay played');
  await screenshot(page, `preview-ep00-comedy-${tag}`, docs);
  const kaguraLine = says('s03_loud')[1];
  if (phone) {
    // A tap during the overlay only ends it: Kagura's line is next and shows whole.
    assert.ok(value.controls.stage, 'the stage target is reachable during the overlay');
    await tapAt(page, value.viewport, center(value.controls.stage), true);
    await waitFor(page, () => !window.__debtQA.comedy?.active, null, 4000);
  } else {
    await waitFor(page, () => !window.__debtQA.comedy?.active, null, 8000);
  }
  await waitFor(page, () => window.__debtQA?.screen === 'story', null, 8000);
  await page.waitForTimeout(400);
  value = await state(page);
  assert.equal(`${value.node_id}:${value.step_index}`, `s03_loud:${impactIndex + 1}`, 'the line after the overlay is current (a tap on the overlay did not also advance)');
  assert.equal(value.full_text, kaguraLine.text);
  assert.equal(value.speaker, 'kagura');
  await tools.completeLine();
  value = await state(page);
  assert.equal(value.text, kaguraLine.text, 'and it shows whole');
  result.checks.push(`the loud row goes to s03_loud and sets pov_style=loud; tsukkomi_impact plays over the reading screen, the story waits, ${phone ? 'a tap ends it and does not skip Kagura\'s line' : 'it ends by itself'}, then Kagura answers (${tag})`);

  // 4. The search: only Gintoki is on stage; his spot is his portrait; his lines by tap count.
  value = await tools.readUntil(v => v.screen === 'investigate', 'the search', seen);
  assert.equal(value.node_id, 's04_room');
  assert.deepEqual(Object.entries(value.sprites).filter(([, sprite]) => sprite.visible).map(([id]) => id), ['gintoki'], 'Gintoki alone is on stage');
  assert.deepEqual(value.phase3.hotspots.map(spot => spot.id), ['gintoki', 'strawberry_milk', 'job_document', 'television']);
  assert.equal(value.phase3.investigation.complete, true, 'nothing is required: 繼續 is open');
  assert.ok(value.controls.investigate_continue, '繼續 is a control');
  assertLayout(value, `EP00 ${tag} search`);
  const gin = tools.spotOf(value, 'gintoki');
  assert.ok(gin.rect?.width > 0, 'his spot (the part of his portrait above the box) is in reach');
  const onGin = center(gin.rect);
  for (const other of value.phase3.hotspots.filter(spot => spot.id !== 'gintoki')) {
    const r = other.screen_rect;
    assert.ok(!(onGin.x >= r.x && onGin.x <= r.x + r.width && onGin.y >= r.y && onGin.y <= r.y + r.height), `the tap on Gintoki is not in ${other.id}'s tap area`);
  }
  const taps = phone ? 3 : 1;
  for (let n = 0; n < taps; n++) {
    await tools.tapSpot('gintoki');
    await waitFor(page, () => window.__debtQA?.screen === 'story', null, 15000);
    await tools.completeLine();
    value = await state(page);
    assert.equal(value.speaker, 'gintoki');
    assert.equal(value.node_id, `s04_gintoki_${n + 1}`, `tap ${n + 1} plays his line ${n + 1}`);
    assert.equal(value.full_text, gintokiLines[n]);
    value = await tools.readUntil(v => v.screen === 'investigate', 'back from Gintoki', seen);
  }
  assert.equal(tools.spotOf(value, 'gintoki').checked, true, 'his spot is checked');
  result.checks.push(`the search keeps Gintoki alone on stage with four optional spots and 繼續 open; ${taps} tap(s) on his portrait play ${gintokiLines.slice(0, taps).map(text => `「${text}」`).join('')} in order (${tag})`);

  if (firstHalf) {
    await control(page, 'investigate_collapse', true);
    await waitFor(page, () => window.__debtQA?.phase3?.investigate_collapsed === true, null, 10000);
    await page.waitForTimeout(300);
    value = await state(page);
    assertLayout(value, `EP00 ${tag} search, box folded`);
    await screenshot(page, `preview-ep00-interaction-${tag}`, docs);
    assert.deepEqual(errors, [], 'no browser or Godot runtime errors');
    result.checks.push(`the whole first half fits ${viewport.width}×${viewport.height}: every control inside the viewport (${tag})`);
    console.log(`PASS ep00 path A ${tag} (first half): ${result.checks.length} check groups`);
    await context.close();
    return;
  }

  // 5. The milk (Kagura answers from off stage) and the job document (the clue, the flag), by dragging the picture and tapping.
  let spot = await tools.bringIntoReach('strawberry_milk');
  assert.ok(spot.rect?.width > 0, `the milk is in reach after dragging: ${JSON.stringify(spot)}`);
  await tools.tapSpot('strawberry_milk');
  await waitFor(page, () => window.__debtQA?.screen === 'story', null, 15000);
  await tools.completeLine();
  value = await state(page);
  assert.equal(value.node_id, 's04_milk');
  assert.equal(value.full_text, says('s04_milk')[0].text);
  assert.equal(value.speaker, 'kagura');
  assert.equal(value.sprites.kagura.visible, false, 'Kagura answers from off stage');
  assert.ok(value.name_plate.width > 0);
  value = await tools.readUntil(v => v.screen === 'investigate', 'back from the milk', seen);
  assert.equal(value.flags.examined_strawberry_milk, true);
  assert.equal(value.flags.found_job, false);
  spot = await tools.bringIntoReach('job_document');
  assert.ok(spot.rect?.width > 0, `the job document is in reach after dragging: ${JSON.stringify(spot)}`);
  await tools.tapSpot('job_document');
  await waitFor(page, () => window.__debtQA?.screen === 'story', null, 15000);
  await tools.completeLine();
  value = await state(page);
  assert.equal(value.node_id, 's04_job');
  assert.match(value.full_text, /尋找失蹤寵物/);
  value = await tools.readUntil(v => v.screen === 'investigate', 'back from the job', seen);
  assert.deepEqual(value.items, ['job_document'], 'the document is held');
  assert.equal(value.flags.found_job, true);
  assert.equal(tools.spotOf(value, 'job_document').checked, true);
  assert.equal(tools.spotOf(value, 'strawberry_milk').checked, true);
  await control(page, 'investigate_collapse', true);
  await waitFor(page, () => window.__debtQA?.phase3?.investigate_collapsed === true, null, 10000);
  await page.waitForTimeout(1500);  // the clue's toast has gone
  value = await state(page);
  assertLayout(value, `EP00 ${tag} search, box folded`);
  await screenshot(page, `preview-ep00-interaction-${tag}`, docs);
  result.checks.push(`dragging the picture and tapping: the milk (Kagura off stage, examined_strawberry_milk=true) and the job document (item job_document, found_job=true), both checked (${tag})`);

  // 6. 繼續: found_job picks the branch, the milk flag Kagura's extra line, then the director's choice.
  await control(page, 'investigate_expand', true);
  await waitFor(page, () => window.__debtQA?.phase3?.investigate_collapsed === false, null, 10000);
  await control(page, 'investigate_continue', true);
  const afterSearch = [];
  value = await tools.readUntil(v => v.screen === 'choice', 'the director\'s choice', afterSearch);
  const texts = afterSearch.map(entry => entry.text);
  assert.deepEqual(texts.slice(0, 3), says('s05_found').map(step => step.text), 'found_job: 這不是有工作嗎！ 沒看到。 你剛才明明就在旁邊！！');
  assert.equal(texts[3], says('s05_milk_yes')[0].text, 'the milk flag: Kagura\'s extra line');
  assert.equal(texts[4], says('s06_open')[0].text, 'then the narration');
  assert.ok(!texts.includes(says('s05_missed')[0].text), 'not the 我自己找 branch');
  await waitFor(page, () => window.__debtQA?.screen === 'choice', null, 10000);  // busy until the sheet has sprung in
  value = await state(page);
  assert.deepEqual(value.choice, { perspective: 'director', pov: '', note: directorStep.note, sheet: 'director', tones: ['', '', ''] },
    'the director\'s choice: its own sheet, the footnote, no tones');
  assert.equal(value.speaker, '', 'nobody is speaking');
  rowsOk(value, directorStep, 'card');
  inside(value.choice_sheet, value.game, 'the director\'s sheet');
  assert.ok(value.controls.menu, '目錄 is on the director\'s sheet too');
  await screenshot(page, `preview-ep00-director-${tag}`, docs);
  result.checks.push(`繼續 goes to s05_found, then the milk line, then the director's choice: sheet=director, footnote "${directorStep.note}", ${value.choices.length} cards each at least 48 CSS px (${tag})`);

  // 7. The third card: its branch, its flag, its ending.
  const picked = directorStep.options[2];
  await tapRow(value, 2);
  await waitFor(page, expected => window.__debtQA?.node_id === expected, picked.next, 15000);
  value = await state(page);
  assert.equal(value.flags.ep00_ending, 'unknown');
  value = await tools.readUntil(v => v.screen === 'end', 'the ending', seen);
  await tools.completeLine();
  value = await state(page);
  const endStep = story.nodes[picked.next].steps.find(step => step.op === 'end');
  assert.equal(value.full_text, endStep.text);
  assert.deepEqual(value.flags, { pov_style: 'loud', found_job: true, examined_strawberry_milk: true, ep00_ending: 'unknown' });
  assert.deepEqual(value.items, ['job_document']);
  await screenshot(page, `preview-ep00-ending-${tag}`, docs);
  assert.deepEqual(errors, [], 'no browser or Godot runtime errors');
  result.checks.push(`card "${picked.label}" goes to ${picked.next}, sets ep00_ending=unknown and ends with 「${endStep.text}」; the flags of the whole run are kept (${tag})`);
  console.log(`PASS ep00 path A ${tag}: ${result.checks.length} check groups`);
  await context.close();
}

async function ep00PathB() {
  const viewport = { width: 390, height: 844 };
  const { context, page, errors } = await openPage(viewport, true);
  const result = { route: 'ep00-b-phone', viewport, touch: true, checks: [], errors };
  report.runs.push(result);
  const story = JSON.parse(await fs.readFile(path.join(root, 'data', 'ep00_story.json'), 'utf8'));
  const says = nodeId => story.nodes[nodeId].steps.filter(step => step.op === 'say');
  const gintokiLines = [1, 2, 3].map(n => says(`s04_gintoki_${n}`)[0].text);
  const directorStep = story.nodes.s06_open.steps.find(step => step.op === 'choice');
  const tools = ep00Tools(page);
  const seen = [];
  const tapRow = async (value, index) => {
    assert.ok(value.choices[index], `row ${index} is on screen and tappable`);
    assertInside(value.choices[index].rect, value.viewport, `row ${index}`);
    await tapAt(page, value.viewport, center(value.choices[index].rect), true);
  };
  const playGintoki = async (n) => {
    await tools.tapSpot('gintoki');
    await waitFor(page, () => window.__debtQA?.screen === 'story', null, 15000);
    await tools.completeLine();
    const value = await state(page);
    assert.equal(value.full_text, gintokiLines[n], `Gintoki's line ${n + 1}`);
    return tools.readUntil(v => v.screen === 'investigate', 'back from Gintoki', seen);
  };

  await control(page, 'begin', true);
  await stable(page);
  await activateSkip(page, true);
  await waitFor(page, () => window.__debtQA?.screen === 'choice', null, 30000);
  let value = await state(page);
  assert.equal(value.choice.perspective, 'pov');
  await tapRow(value, 2);  // 「……算了，我甚至不知道從哪裡開始說。」
  await waitFor(page, () => window.__debtQA?.flags?.pov_style === 'tired' && window.__debtQA.node_id === 's03_tired', null, 15000);
  await activateSkip(page, true);
  await waitFor(page, () => window.__debtQA?.screen === 'investigate', null, 30000);
  value = await state(page);
  assert.deepEqual(Object.entries(value.sprites).filter(([, sprite]) => sprite.visible).map(([id]) => id), ['gintoki']);
  assert.equal(value.flags.pov_style, 'tired');
  result.checks.push('the tired row (skipping the reading) sets pov_style=tired and leads to the search');

  // Two taps on Gintoki, then a manual slot in the search.
  value = await playGintoki(0);
  value = await playGintoki(1);
  const searching = tools.picture(value);
  assert.equal(searching.screen, 'investigate');
  await tools.saveToSlot(1);
  assert.deepEqual(tools.picture(await state(page)), searching, 'saving slot 1 leaves the search as it was');
  result.checks.push('two taps on Gintoki, then slot 1 is saved in the search without moving it');

  // 繼續 without the job: 我自己找; no milk was touched, so no extra line; the director's choice.
  await control(page, 'investigate_continue', true);
  const afterSearch = [];
  value = await tools.readUntil(v => v.screen === 'choice', 'the director\'s choice', afterSearch);
  assert.equal(afterSearch[0].node, 's05_missed');
  assert.equal(afterSearch[0].text, says('s05_missed')[0].text, 'found_job is false: 我自己找');
  assert.deepEqual(afterSearch.map(entry => entry.text), [says('s05_missed')[0].text, says('s06_open')[0].text], 'no job lines, no milk line');
  await waitFor(page, () => window.__debtQA?.screen === 'choice', null, 10000);
  value = await state(page);
  assert.deepEqual(value.choice, { perspective: 'director', pov: '', note: directorStep.note, sheet: 'director', tones: ['', '', ''] });
  const atDirector = tools.picture(value);
  await tools.saveToSlot(2);
  assert.deepEqual(tools.picture(await state(page)), atDirector, 'saving slot 2 leaves the director\'s choice as it was');
  result.checks.push('繼續 without the job goes to 「……算了，我自己找。」 and on to the director\'s choice (found_job=false); slot 2 is saved there');

  // The first card: the debt ending.
  value = await state(page);
  await tapRow(value, 0);
  await waitFor(page, () => window.__debtQA?.node_id === 'end_debt', null, 15000);
  value = await tools.readUntil(v => v.screen === 'end', 'the ending', seen);
  await tools.completeLine();
  value = await state(page);
  assert.equal(value.full_text, story.nodes.end_debt.steps.find(step => step.op === 'end').text);
  assert.deepEqual(value.flags, { pov_style: 'tired', found_job: false, examined_strawberry_milk: false, ep00_ending: 'debt' });
  result.checks.push(`card "${directorStep.options[0].label}" ends the story with 「${value.full_text}」, ep00_ending=debt (path B)`);

  // Reload the page: slot 1 comes back to the search (and counts his taps on), slot 2 to the same director's choice.
  await page.waitForTimeout(1500);  // the browser's file system flushes to IndexedDB in the background
  await page.reload({ waitUntil: 'load', timeout: 120000 });
  await waitFor(page, () => window.__debtQA?.screen === 'title', null, 120000);
  await control(page, 'title_load', true);
  value = await state(page);
  assert.deepEqual(value.slots.slice(0, 2).map(slot => slot.occupied), [true, true], 'both manual slots survived the reload');
  await control(page, 'slot_1', true);
  await stable(page);
  value = await state(page);
  assert.deepEqual(tools.picture(value), searching, 'slot 1 after a reload: the same event, the search with the same flags, stage and checked spots');
  value = await playGintoki(2);
  assert.equal(value.screen, 'investigate');
  result.checks.push('after reloading the page, slot 1 returns to the same search; the third tap on Gintoki plays his third line (the count was saved)');
  await controlAny(page, ['menu', 'toolbar_menu', 'menu_open'], true, 'menu');
  await control(page, 'menu_load', true);
  await control(page, 'slot_2', true);
  await stable(page);
  value = await state(page);
  assert.deepEqual(tools.picture(value), atDirector, 'slot 2: the same director\'s choice');
  assert.equal(value.choices.length, directorStep.options.length);
  await waitFor(page, () => window.__debtQA?.screen === 'choice', null, 10000);
  await tapRow(await state(page), 0);
  await waitFor(page, () => window.__debtQA?.node_id === 'end_debt', null, 15000);
  result.checks.push('slot 2 returns to the same director\'s choice (sheet, footnote, cards, flags) and its card still works');
  assert.deepEqual(errors, [], 'no browser or Godot runtime errors');
  console.log(`PASS ep00 path B: ${result.checks.length} check groups`);
  await context.close();
}

try {
  if (ep00Only) {
    await ep00PathA({ width: 390, height: 844 }, 'phone', false);
    await ep00PathB();
    await ep00PathA({ width: 320, height: 568 }, 'narrow', true);
  } else if (choicesOnly) {
    await choicesRoute({ width: 390, height: 844 }, 'phone');
    await choicesRoute({ width: 320, height: 568 }, 'narrow');
  } else if (comedyOnly) {
    await comedyRoute({ width: 390, height: 844 }, 'phone');
    await comedyRoute({ width: 320, height: 568 }, 'narrow');
  } else if (smokeOnly) {
    await touchSmoke();
  } else if (slotsOnly) {
    await slotsRoute();
  } else if (phase3Only) {
    await phase3Route();
  } else if (roundsOnly) {
    await roundsRoute();
  } else if (investigateOnly) {
    await investigateRoute();
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
  const reportName = ep00Only ? 'ep00-browser-report.json' : choicesOnly ? 'choices-browser-report.json' : comedyOnly ? 'comedy-browser-report.json' : smokeOnly ? 'smoke-report.json' : slotsOnly ? 'slots-report.json'
    : phase3Only ? 'phase3-report.json' : roundsOnly ? 'rounds-report.json' : investigateOnly ? 'investigate-report.json'
    : phase2Only ? 'phase2-report.json' : 'browser-report.json';
  await fs.writeFile(path.join(comedyOnly || choicesOnly || ep00Only ? docs : output, reportName), `${JSON.stringify(report, null, 2)}\n`);
  await browser.close();
  console.log(`Evidence: ${output}`);
}
