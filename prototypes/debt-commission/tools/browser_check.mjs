import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';

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
const location = actor => actor?.position ?? { x: actor?.x, y: actor?.y };
const stable = page => page.waitForFunction(() => {
  const value = window.__debtQA;
  return value && ['title', 'story', 'choice', 'end', 'log'].includes(value.screen);
}, null, { timeout: 30000 });

function assertRect(rect, viewport, name) {
  assert.ok(rect && rect.width > 0 && rect.height > 0, `${name} needs a visible rectangle`);
  assert.ok(rect.x >= -1 && rect.y >= -1 && rect.x + rect.width <= viewport.width + 1
    && rect.y + rect.height <= viewport.height + 1, `${name} lies outside the viewport`);
}

async function clickRect(page, rect, view, touch) {
  assertRect(rect, view, 'click target');
  const bounds = await page.locator('canvas').boundingBox();
  assert.ok(bounds, 'Godot canvas exists');
  const x = bounds.x + (rect.x + rect.width / 2) / view.width * bounds.width;
  const y = bounds.y + (rect.y + rect.height / 2) / view.height * bounds.height;
  if (touch) await page.touchscreen.tap(x, y);
  else await page.mouse.click(x, y);
  await page.waitForTimeout(100);
}

async function control(page, name, touch) {
  const current = await state(page);
  assert.ok(current.controls[name], `Control ${name} is available on ${current.screen}`);
  await clickRect(page, current.controls[name], current.viewport, touch);
}

async function reveal(page, touch) {
  const before = await state(page);
  if (before.screen !== 'story' || before.text_complete) return;
  await control(page, 'next', touch);
  const after = await state(page);
  assert.equal(key(after), key(before), 'First click completes the current line without advancing');
  assert.equal(after.text_complete, true, 'First click reveals all text');
}

async function next(page, touch) {
  await page.waitForFunction(() => window.__debtQA?.text_complete, null, { timeout: 10000 });
  const before = await state(page);
  await control(page, 'next', touch);
  await page.waitForFunction(previous => {
    const value = window.__debtQA;
    return value && `${value.screen}:${value.node_id}:${value.step_index}` !== previous;
  }, key(before), { timeout: 15000 });
  await stable(page);
}

async function screenshot(page, name) {
  await page.screenshot({ path: path.join(output, `${name}.png`), fullPage: true });
}

async function playRoute(route, viewport, touch) {
  const context = await browser.newContext({ viewport, hasTouch: touch, isMobile: touch, deviceScaleFactor: 1 });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(message.text())) errors.push(message.text());
  });
  const result = { route, viewport, touch, nodes: [], lines: [], checks: [], errors };
  report.runs.push(result);
  console.log(`Starting route ${route} at ${viewport.width}×${viewport.height}`);
  await page.goto(url.toString(), { waitUntil: 'load', timeout: 120000 });
  await page.waitForFunction(() => window.__debtQA?.screen === 'title', null, { timeout: 120000 });
  await screenshot(page, `${route}-title`);
  await control(page, 'begin', touch);
  await stable(page);
  // Exercise reveal once on the opening's long line. Short lines may naturally
  // finish while Playwright calculates coordinates; those are read to completion.
  await reveal(page, touch);
  result.checks.push('first click reveals the opening line without advancing');
  let selected = false;
  let resumed = false;
  let readerPosition;
  let otherPosition;
  let initialOtoseHidden = false;
  let otoseAppeared = false;
  let finished = false;

  for (let step = 0; step < 150; step++) {
    await stable(page);
    const current = await state(page);
    assert.ok(current && current.node_id, 'Current story location is observable');
    if (!result.nodes.includes(current.node_id)) result.nodes.push(current.node_id);
    if (current.screen === 'story') {
      await page.waitForFunction(() => window.__debtQA?.text_complete, null, { timeout: 10000 });
      const completed = await state(page);
      result.lines.push({ node: completed.node_id, text: completed.text, speaker: completed.speaker });
      if (current.node_id === 'debt_intro' && readerPosition === undefined) {
        readerPosition = location(current.actors.shinpachi);
        initialOtoseHidden = current.actors.otose?.visible === false;
        await screenshot(page, `${route}-opening`);
      }
      otoseAppeared ||= current.actors.otose?.visible === true;
      if (current.node_id === 'debt_ask_salary' && !resumed) {
        otherPosition = location(current.actors.shinpachi);
        assert.notDeepEqual(otherPosition, readerPosition, 'Shinpachi moved to the other side of the table');
        await screenshot(page, `${route}-salary`);
        const checkpoint = await state(page);
        await page.waitForTimeout(1400); // Let the browser flush Godot user:// to IndexedDB.
        await page.reload({ waitUntil: 'load', timeout: 120000 });
        await page.waitForFunction(() => window.__debtQA?.screen === 'title', null, { timeout: 120000 });
        await control(page, 'continue', touch);
        await stable(page);
        const restored = await state(page);
        assert.equal(key(restored), key(checkpoint), 'Continue restores the same reading point');
        assert.equal(restored.text, checkpoint.text, 'Continue preserves the current line');
        assert.deepEqual(restored.flags, checkpoint.flags, 'Continue preserves branch flags');
        for (const actor of ['shinpachi', 'gintoki', 'otose']) {
          assert.deepEqual(location(restored.actors[actor]), location(checkpoint.actors[actor]), `${actor} position restored`);
          assert.equal(restored.actors[actor].visible, checkpoint.actors[actor].visible, `${actor} visibility restored`);
        }
        result.checks.push('reload + continue preserves text, branch and all character positions');
        resumed = true;
      }
      await next(page, touch);
    } else if (current.screen === 'choice') {
      assert.equal(selected, false, 'Only one deliberate choice is required');
      assert.equal(current.choices.length, 2, 'Both approved options are visible');
      current.choices.forEach(choice => assertRect(choice.rect, current.viewport, choice.label));
      await screenshot(page, `${route}-choice`);
      await page.waitForTimeout(400);
      assert.equal(key(await state(page)), key(current), 'Choice waits for the player');
      await control(page, 'log', touch);
      assert.equal((await state(page)).screen, 'log');
      await screenshot(page, `${route}-log`);
      await control(page, 'log_close', touch);
      const closed = await state(page);
      assert.equal(key(closed), key(current), 'Closing the log does not advance or choose');
      assert.deepEqual(closed.flags, current.flags);
      result.checks.push('choices wait; log opens and closes without choosing');
      if (route === 'B') {
        await page.setViewportSize({ width: 320, height: 568 });
        await page.waitForTimeout(400);
        const narrow = await state(page);
        narrow.choices.forEach(choice => assertRect(choice.rect, narrow.viewport, choice.label));
        await screenshot(page, 'B-choice-320x568');
        await page.setViewportSize(viewport);
        await page.waitForTimeout(300);
        result.checks.push('choice controls fit 320×568 and recover after resize');
      }
      const ready = await state(page);
      const chosen = ready.choices[route === 'A' ? 0 : 1];
      result.selection = chosen;
      await clickRect(page, chosen.rect, ready.viewport, touch);
      await stable(page);
      assert.equal((await state(page)).flags.question_method, route === 'A' ? 'hear_first' : 'ledger_first');
      selected = true;
    } else if (current.screen === 'end') {
      assert.equal(current.flags.question_method, route === 'A' ? 'hear_first' : 'ledger_first');
      assert.equal(current.flags.repayment_promised, true, 'Gintoki promised repayment, not paid it off');
      await screenshot(page, `${route}-end`);
      result.final = current;
      finished = true;
      break;
    } else {
      throw new Error(`Unexpected stable screen: ${current.screen}`);
    }
  }
  assert.ok(finished && selected && resumed, 'Route finished through a choice and reload');
  assert.ok(initialOtoseHidden && otoseAppeared, 'Otose enters the stage during the opening');
  const expected = route === 'A' ? 'debt_recall_hearing' : 'debt_recall_ledger';
  const other = route === 'A' ? 'debt_recall_ledger' : 'debt_recall_hearing';
  assert.ok(result.nodes.includes(expected), 'The selected questioning method gets its callback');
  assert.ok(!result.nodes.includes(other), 'The other branch is not shown');
  result.checks.push('Otose enters; Shinpachi changes position; correct callback; complete ending');
  await control(page, 'restart', touch);
  await stable(page);
  if ((await state(page)).screen === 'title') {
    await control(page, 'begin', touch);
    await stable(page);
  }
  const restarted = await state(page);
  assert.equal(restarted.node_id, 'debt_intro');
  assert.equal(restarted.flags.question_method, 'unset');
  assert.equal(restarted.flags.repayment_promised, false);
  result.checks.push('restart resets the story and both flags');
  assert.deepEqual(errors, [], 'No browser or Godot runtime errors');
  console.log(`PASS route ${route}: ${result.lines.length} reading points, ${result.checks.length} check groups`);
  await context.close();
}

async function touchSmoke() {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(message.text())) errors.push(message.text());
  });
  await page.goto(url.toString(), { waitUntil: 'load', timeout: 120000 });
  await page.waitForFunction(() => window.__debtQA?.screen === 'title', null, { timeout: 120000 });
  await control(page, 'begin', true);
  await stable(page);
  const before = await state(page);
  assert.equal(before.text_complete, false, 'Opening line is still typing');
  await control(page, 'dialogue', true);
  const revealed = await state(page);
  assert.equal(key(revealed), key(before), 'Touching dialogue reveals without advancing twice');
  assert.equal(revealed.text_complete, true);
  await control(page, 'dialogue', true);
  await stable(page);
  const advanced = await state(page);
  assert.notEqual(key(advanced), key(before), 'Next dialogue touch advances');
  const mutedBefore = advanced.audio_muted;
  await control(page, 'mute', true);
  const muted = await state(page);
  assert.equal(muted.audio_muted, !mutedBefore);
  assert.equal(key(muted), key(advanced), 'Mute does not advance the story');
  await control(page, 'log', true);
  assert.equal((await state(page)).screen, 'log');
  await control(page, 'log_close', true);
  assert.equal(key(await state(page)), key(advanced));
  await control(page, 'restart', true);
  await stable(page);
  assert.equal((await state(page)).flags.question_method, 'unset');
  await screenshot(page, 'smoke-mobile');
  const normalUrl = new URL(url);
  normalUrl.searchParams.delete('qa');
  await page.goto(normalUrl.toString(), { waitUntil: 'networkidle', timeout: 120000 });
  assert.equal(await page.evaluate(() => typeof window.__debtQA), 'undefined', 'Normal play has no QA bridge');
  assert.deepEqual(errors, []);
  report.runs.push({ route: 'touch-smoke', checks: ['tap dialogue twice', 'mute', 'log', 'restart', 'normal URL'], errors });
  console.log('PASS: direct dialogue touch, mute, log, restart and normal URL');
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
