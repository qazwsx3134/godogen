import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';

// Phase 1 browser acceptance: real canvas mouse/touch input against the Web export (?qa=1).
const require = createRequire(import.meta.url);
const smokeOnly = process.argv.includes('--smoke');
const arg = (name, fallback) => {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : fallback;
};
const { chromium } = require(arg('--playwright', '@playwright/test'));
const url = new URL(arg('--url', 'http://127.0.0.1:5193/'));
url.searchParams.set('qa', '1');
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
  return value && ['title', 'story', 'choice', 'end', 'log', 'menu'].includes(value.screen);
}, null, { timeout: 30000 });
const waitFor = (page, predicate, arg, timeout = 15000) => page.waitForFunction(predicate, arg, { timeout });

function assertInside(rect, viewport, name) {
  assert.ok(rect && rect.width > 0 && rect.height > 0, `${name} needs a visible rectangle`);
  assert.ok(rect.x >= -1 && rect.y >= -1 && rect.x + rect.width <= viewport.width + 1
    && rect.y + rect.height <= viewport.height + 1, `${name} lies outside the viewport`);
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
  await control(page, 'dialogue', touch);
  const after = await state(page);
  assert.equal(key(after), key(before), 'First tap completes the current line without advancing');
  assert.equal(after.text_complete, true, 'First tap reveals all text');
  return true;
}

async function next(page, touch, target = 'dialogue') {
  await waitFor(page, () => window.__debtQA?.text_complete, null, 10000);
  const before = await state(page);
  await control(page, target, touch);
  await waitFor(page, previous => {
    const value = window.__debtQA;
    return value && value.screen !== 'busy' && `${value.screen}:${value.node_id}:${value.step_index}` !== previous;
  }, key(before));
}

async function screenshot(page, name) {
  await page.screenshot({ path: path.join(output, `${name}.png`), fullPage: true });
}

function assertLayout(value, label) {
  const { viewport, dialog, quickbar, controls } = value;
  assertInside(dialog, viewport, `${label} dialogue box`);
  assertInside(quickbar, viewport, `${label} quick bar`);
  const ratio = dialog.height / viewport.height;
  assert.ok(Math.abs(ratio - 0.28) < 0.02, `${label}: dialogue box is ~28% of the screen (got ${ratio.toFixed(3)})`);
  for (const name of ['menu', 'save']) {
    assertInside(controls[name], viewport, `${label} floating ${name}`);
    assert.ok(controls[name].y + controls[name].height <= dialog.y + 1, `${label}: floating ${name} avoids the dialogue box`);
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

// Gestures on the opening lines: background tap, hide UI, swipe-up log, floating buttons, idle, menu, AUTO.
async function phase1Gestures(page, touch, route, checks) {
  let value = await state(page);
  assertLayout(value, route);
  assert.ok(value.name_plate.width > 0 || value.speaker === 'narrator', 'Name plate shows for character lines');
  await screenshot(page, `${route}-dialogue`);
  checks.push('layout: dialogue ~28%, quick bar and floating buttons inside the screen and above the box');

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

  await control(page, 'save', touch);
  value = await state(page);
  assert.equal(value.toast, '長按快速存檔', 'Tap S shows the long-press hint');
  assert.equal(key(value), key(before), 'Tap S does not advance');
  const save = center(value.controls.save);
  await gesture(page, value.viewport, save, save, 900, touch);
  value = await state(page);
  assert.equal(value.toast, '已存檔', 'Long-press S quick-saves');
  assert.equal(key(value), key(before), 'Long-press S does not advance');
  checks.push('tap S hints, long-press S quick-saves with a toast; neither advances');

  const menuStart = center(value.controls.menu);
  await gesture(page, value.viewport, menuStart, { x: value.game.x + 300, y: value.game.y + value.game.height * 0.45 }, 60, touch);
  await page.waitForTimeout(400);
  value = await state(page);
  assert.ok(Math.abs(value.controls.menu.x - (value.game.x + 24)) < 2, 'Dragged menu button snaps to the left edge');
  assert.ok(value.controls.menu.y + value.controls.menu.height <= value.dialog.y + 1, 'Dragged button stays out of the box');
  assert.equal(key(value), key(before), 'Dragging does not advance');
  await screenshot(page, `${route}-dragged`);
  checks.push('dragging (≡) snaps it to the nearest side edge without advancing');

  await page.waitForTimeout(3800);
  value = await state(page);
  assert.ok(value.float_alpha <= 0.45, `Idle buttons fade to 40% (got ${value.float_alpha})`);
  await control(page, 'menu', touch);
  value = await state(page);
  assert.equal(value.screen, 'menu', 'Tap (≡) opens the menu');
  await page.waitForTimeout(300);
  await screenshot(page, `${route}-menu`);
  await control(page, 'menu_dim', touch);
  value = await state(page);
  assert.equal(key(value), key(before), 'Tapping the dimmed background closes the menu without advancing');
  assert.ok(value.float_alpha > 0.5, 'Buttons recover opacity after interaction');
  checks.push('idle 3 s fades buttons to 40%; menu opens and closes from the background');

  await control(page, 'auto', touch);
  await waitFor(page, previous => { const v = window.__debtQA; return `${v.node_id}:${v.step_index}` !== previous; }, lineKey(before), 12000);
  await control(page, 'auto', touch);
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
      current.choices.forEach(choice => assert.ok(choice.rect.y + choice.rect.height <= current.dialog.y, 'Choices sit above the box'));
      await screenshot(page, `${route}-choice`);
      await page.waitForTimeout(400);
      assert.equal(key(await state(page)), key(current), 'Choice waits for the player');
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
        result.checks.push('choices, box and floating buttons fit 360×800 and 320×568');
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
  await control(page, 'skip', touch);
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
  console.log('PASS: touch smoke (reveal/advance, gestures, floating buttons, menu, normal URL)');
  await context.close();
}

try {
  if (smokeOnly) {
    await touchSmoke();
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
  await fs.writeFile(path.join(output, smokeOnly ? 'smoke-report.json' : 'browser-report.json'), `${JSON.stringify(report, null, 2)}\n`);
  await browser.close();
  console.log(`Evidence: ${output}`);
}
