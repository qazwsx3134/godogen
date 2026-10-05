import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';

// Visual evidence for the live Web export. This deliberately reports geometry and screenshots,
// not a synthetic visual-parity score. The QA bridge is the same window.__debtQA protocol used by
// browser_check.mjs; all taps are real browser mouse/touch events on the exported game canvas.
const require = createRequire(import.meta.url);
const arg = (name, fallback) => {
  const index = process.argv.indexOf(name);
  return index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : fallback;
};
const { chromium } = require(arg('--playwright', '@playwright/test'));
const baseUrl = new URL(arg('--url', 'http://127.0.0.1:5193/'));
baseUrl.searchParams.set('qa', '1');
baseUrl.searchParams.set('sample', 'debt');

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.resolve(arg('--out', path.join(root, 'test-results', 'ui-parity')));
const styles = ['cinema', 'ledger', 'manga', 'gintama'];
const viewports = [
  { width: 390, height: 844 },
  { width: 320, height: 568 },
];
const textSamples = {
  opening: '午後。銀時靠在桌邊吃糰子。新八把委託書攤平，指尖停在已簽收的訂金欄。',
  comparison: '這次的理由比較長。先從我小時候說起——',
};
const targetNode = 'debt_recall_hearing';
const targetSpeaker = 'gintoki';
const advanceControls = ['dialogue', 'advance', 'next', 'stage'];
const menuControls = ['menu', 'toolbar_menu', 'menu_open'];
const closeMenuControls = ['menu_close', 'menu_resume', 'resume', 'close_menu'];

await fs.mkdir(output, { recursive: true });
const report = {
  source: baseUrl.toString(),
  started: new Date().toISOString(),
  viewports,
  styles,
  sample: { node: targetNode, speaker: targetSpeaker, text: textSamples.comparison },
  captures: [],
  runs: [],
};

const browser = await chromium.launch({
  headless: true,
  executablePath: arg('--chromium', undefined),
  args: ['--enable-webgl', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});

const readState = page => page.evaluate(() => window.__debtQA || null);
const qaKey = value => [value.screen, value.node_id, value.step_index].join(':');
const center = rect => ({ x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 });
const fullText = value => value.full_text ?? value.text ?? '';

function assertRectInside(rect, viewport, label) {
  assert.ok(rect && Number.isFinite(rect.x) && Number.isFinite(rect.y)
    && Number.isFinite(rect.width) && Number.isFinite(rect.height)
    && rect.width > 0 && rect.height > 0, label + ' has a visible rectangle');
  assert.ok(rect.x >= -1 && rect.y >= -1
    && rect.x + rect.width <= viewport.width + 1
    && rect.y + rect.height <= viewport.height + 1,
  label + ' overflows viewport: ' + JSON.stringify({ rect, viewport }));
}

async function waitForState(page, predicate, argument, description, timeout = 30000) {
  await page.waitForFunction(predicate, argument, { timeout });
  const value = await readState(page);
  assert.ok(value, 'QA bridge publishes state after ' + description);
  return value;
}

async function waitForScreen(page, expected, timeout = 30000) {
  const accepted = Array.isArray(expected) ? expected : [expected];
  return waitForState(page,
    screens => window.__debtQA && screens.includes(window.__debtQA.screen),
    accepted, 'screen ' + accepted.join('/'), timeout);
}

async function canvasBounds(page) {
  const bounds = await page.locator('canvas').first().boundingBox();
  assert.ok(bounds && bounds.width > 0 && bounds.height > 0, 'Godot canvas has visible bounds');
  return bounds;
}

async function tapRect(page, viewport, rect) {
  assertRectInside(rect, viewport, 'tap target');
  const canvas = await canvasBounds(page);
  const point = center(rect);
  const x = canvas.x + point.x / viewport.width * canvas.width;
  const y = canvas.y + point.y / viewport.height * canvas.height;
  if (page.touchscreen) await page.touchscreen.tap(x, y);
  else await page.mouse.click(x, y);
  await page.waitForTimeout(180);
}

function getControl(value, candidates, description) {
  for (const name of candidates) {
    const rect = value.controls?.[name];
    if (rect) return { name, rect };
  }
  assert.fail(description + ' is not exposed by QA controls; available: '
    + Object.keys(value.controls || {}).sort().join(', '));
}

async function tapControl(page, candidates, description) {
  const value = await readState(page);
  assert.ok(value, 'QA bridge is available before ' + description);
  const control = getControl(value, candidates, description);
  await tapRect(page, value.viewport, control.rect);
  return control.name;
}

function logicalToCssRect(rect, viewport, canvas) {
  return {
    x: canvas.x + rect.x / viewport.width * canvas.width,
    y: canvas.y + rect.y / viewport.height * canvas.height,
    width: rect.width / viewport.width * canvas.width,
    height: rect.height / viewport.height * canvas.height,
  };
}

function isActionTarget(name) {
  if (/^(stage|menu_dim|dialogue|quickbar|toolbar|name_plate|choice_sheet|title_panel|timer_preview)$/.test(name)) {
    return false;
  }
  return /^(begin|continue|title_load|menu|toolbar_|menu_|close_|resume|style_|title_style_|menu_style_|choice|advance|next|log|auto|skip|material|save|restart|title|investigate_|boke_|game_over_|slot_)/.test(name);
}

async function geometryChecks(page, value, screenLabel) {
  const canvas = await canvasBounds(page);
  const viewport = value.viewport;
  assert.ok(viewport && viewport.width > 0 && viewport.height > 0,
    screenLabel + ' publishes a positive viewport');
  const rectangles = [];
  const hitTargets = [];
  const knownTargets = new Set();
  for (const [name, rect] of Object.entries(value.controls || {})) {
    assertRectInside(rect, viewport, screenLabel + ' control ' + name);
    rectangles.push({ name, rect });
    if (isActionTarget(name)) {
      const rectangleKey = [rect.x, rect.y, rect.width, rect.height].join(':');
      if (knownTargets.has(rectangleKey)) continue;
      knownTargets.add(rectangleKey);
      const cssRect = logicalToCssRect(rect, viewport, canvas);
      hitTargets.push({ name, logical: rect, css: cssRect });
    }
  }
  for (const [index, choice] of (value.choices || []).entries()) {
    const rect = choice.rect || choice;
    assertRectInside(rect, viewport, screenLabel + ' choice ' + (choice.id || index));
    const rectangleKey = [rect.x, rect.y, rect.width, rect.height].join(':');
    if (knownTargets.has(rectangleKey)) continue;
    knownTargets.add(rectangleKey);
    const cssRect = logicalToCssRect(rect, viewport, canvas);
    hitTargets.push({ name: 'choice:' + (choice.id || index), logical: rect, css: cssRect });
  }
  for (const field of ['game', 'dialog', 'quickbar', 'name_plate']) {
    const rect = value[field];
    if (rect && Number.isFinite(rect.width) && rect.width > 0 && Number.isFinite(rect.height) && rect.height > 0) {
      assertRectInside(rect, viewport, screenLabel + ' ' + field);
    }
  }

  const violations = hitTargets.filter(target => target.css.width < 48 || target.css.height < 48);
  assert.deepEqual(violations.map(({ name, css }) => ({ name, width: css.width, height: css.height })), [],
    screenLabel + ' has a tappable target below 48 CSS px');

  const overlapping = [];
  for (let i = 0; i < hitTargets.length; i++) {
    for (let j = i + 1; j < hitTargets.length; j++) {
      const a = hitTargets[i];
      const b = hitTargets[j];
      const intersectionWidth = Math.min(a.css.x + a.css.width, b.css.x + b.css.width) - Math.max(a.css.x, b.css.x);
      const intersectionHeight = Math.min(a.css.y + a.css.height, b.css.y + b.css.height) - Math.max(a.css.y, b.css.y);
      if (intersectionWidth > 1 && intersectionHeight > 1) overlapping.push([a.name, b.name]);
    }
  }
  assert.deepEqual(overlapping, [], screenLabel + ' has overlapping action hit targets');

  const documentBounds = await page.evaluate(() => ({
    width: document.documentElement.clientWidth,
    height: document.documentElement.clientHeight,
    scrollWidth: document.documentElement.scrollWidth,
    scrollHeight: document.documentElement.scrollHeight,
  }));
  assert.ok(documentBounds.scrollWidth <= documentBounds.width + 1
    && documentBounds.scrollHeight <= documentBounds.height + 1,
  screenLabel + ' Web page overflows viewport: ' + JSON.stringify(documentBounds));

  return {
    viewport,
    canvas: { x: canvas.x, y: canvas.y, width: canvas.width, height: canvas.height },
    document: documentBounds,
    controls: rectangles,
    hitTargets,
  };
}

async function capture(page, style, viewport, screen, value, run) {
  const geometry = await geometryChecks(page, value, style + ' ' + viewport.width + 'x' + viewport.height + ' ' + screen);
  const directory = path.join(output, String(viewport.width) + 'x' + String(viewport.height), style);
  await fs.mkdir(directory, { recursive: true });
  const file = path.join(directory, screen + '.png');
  await page.screenshot({ path: file, fullPage: true });
  const entry = {
    style,
    viewport,
    screen,
    file: path.relative(root, file).split(path.sep).join('/'),
    node_id: value.node_id,
    step_index: value.step_index,
    speaker: value.speaker,
    text: fullText(value),
    background: value.background,
    gintoki_visible: value.sprites?.gintoki?.visible === true,
    geometry,
  };
  report.captures.push(entry);
  run.screens.push({ screen, file: entry.file, node_id: entry.node_id, step_index: entry.step_index });
  return entry;
}

async function revealCurrentLine(page) {
  const before = await readState(page);
  if (before.text_complete) return before;
  await page.waitForFunction(() => window.__debtQA?.text_complete === true, null, { timeout: 15000 });
  return readState(page);
}

async function advanceUntilTarget(page) {
  for (let step = 0; step < 80; step++) {
    let value = await readState(page);
    assert.ok(value, 'QA bridge stays available while advancing the approved story');
    if (value.screen === 'story' && value.node_id === targetNode && fullText(value) === textSamples.comparison) {
      value = await revealCurrentLine(page);
      assert.equal(fullText(value), textSamples.comparison, 'Comparison line uses the approved story text');
      assert.equal(value.speaker, targetSpeaker, 'Comparison line is spoken by Gintoki');
      return value;
    }
    if (value.screen === 'choice') {
      throw new Error('Unexpected choice while advancing to ' + targetNode + ': ' + JSON.stringify(value.choices));
    }
    assert.equal(value.screen, 'story', 'Expected story while advancing; got ' + value.screen);
    value = await revealCurrentLine(page);
    const previous = qaKey(value);
    await tapControl(page, advanceControls, 'dialogue advance');
    await page.waitForFunction(previousKey => {
      const current = window.__debtQA;
      return current && current.screen !== 'busy' && [
        'story', 'choice', 'end', 'result', 'menu', 'investigate', 'boke_round', 'tsukkomi',
      ].includes(current.screen) && qaKeyForBrowser(current) !== previousKey;
      function qaKeyForBrowser(state) { return [state.screen, state.node_id, state.step_index].join(':'); }
    }, previous, { timeout: 15000 });
  }
  throw new Error('Could not reach ' + targetNode + ' with the approved comparison text in 80 advances');
}

async function clickStyleOnTitle(page, style) {
  const value = await readState(page);
  const control = getControl(value,
    ['style_' + style, 'title_style_' + style, 'ui_style_' + style],
    'title style ' + style);
  await tapRect(page, value.viewport, control.rect);
  await page.waitForFunction(expected => window.__debtQA?.ui_style === expected, style,
    { timeout: 10000 });
}

async function createGamePage(viewport, style, run) {
  const context = await browser.newContext({
    viewport,
    deviceScaleFactor: 1,
    hasTouch: true,
    isMobile: true,
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(message.text())) errors.push(message.text());
  });
  await page.goto(baseUrl.toString(), { waitUntil: 'load', timeout: 120000 });
  await waitForScreen(page, 'title', 120000);
  const title = await readState(page);
  await clickStyleOnTitle(page, style);
  const styledTitle = await readState(page);
  assert.equal(styledTitle.ui_style, style, 'Title selector applies ' + style);
  await capture(page, style, viewport, 'title', styledTitle, run);
  return { context, page, errors };
}

async function skipToDebtChoice(page) {
  const before = await readState(page);
  if (before.controls?.skip) {
    await tapControl(page, ['skip'], 'SKIP');
    try {
      return await waitForScreen(page, 'choice', 30000);
    } catch {
      // Fall back to direct dialogue taps for exports that omit the optional quick action.
    }
  }
  for (let step = 0; step < 60; step++) {
    const value = await readState(page);
    if (value.screen === 'choice') return value;
    assert.equal(value.screen, 'story', 'Expected the debt story before its first choice');
    const complete = await revealCurrentLine(page);
    const previous = qaKey(complete);
    await tapControl(page, advanceControls, 'dialogue advance to first choice');
    await page.waitForFunction(previousKey => {
      const current = window.__debtQA;
      return current && current.screen !== 'busy'
        && [current.screen, current.node_id, current.step_index].join(':') !== previousKey;
    }, previous, { timeout: 15000 });
  }
  throw new Error('Did not reach debt_choose_method choice in 60 dialogue advances');
}

async function runDebtComparison(style, viewport) {
  const run = { style, viewport, screens: [], checks: [], errors: [] };
  report.runs.push(run);
  const { context, page, errors } = await createGamePage(viewport, style, run);
  try {
    await tapControl(page, ['begin'], 'begin story');
    let value = await waitForScreen(page, 'story');
    value = await revealCurrentLine(page);
    assert.equal(value.node_id, 'debt_intro', 'Opening overflow sample comes from the real debt story');
    assert.equal(fullText(value), textSamples.opening, 'Opening long narration matches debt_story.json');
    await capture(page, style, viewport, 'opening-overflow', value, run);
    run.checks.push('captured the first real debt narration line as the narrow layout case');

    value = await skipToDebtChoice(page);
    assert.equal(value.node_id, 'debt_choose_method', 'First story choice is debt_choose_method');
    assert.deepEqual((value.choices || []).map(choice => choice.id), ['hear_first', 'ledger_first'],
      'Approved first choice exposes both story branches');
    await capture(page, style, viewport, 'choices', value, run);
    run.checks.push('captured the actual first story choice before selecting hear_first');

    const hear = value.choices.find(choice => choice.id === 'hear_first');
    assert.ok(hear, 'hear_first branch is present');
    await tapRect(page, value.viewport, hear.rect);
    value = await waitForScreen(page, 'story');
    assert.equal(value.flags?.question_method, 'hear_first', 'Choice click follows hear_first');
    value = await advanceUntilTarget(page);
    assert.equal(value.node_id, targetNode);
    assert.equal(fullText(value), textSamples.comparison);
    assert.equal(value.background, 'yorozuya_living_room', 'Comparison line keeps the approved interior background');
    assert.equal(value.sprites?.gintoki?.visible, true, 'Comparison line keeps Gintoki visible');
    await capture(page, style, viewport, 'dialogue-comparison', value, run);
    run.checks.push('reached the exact approved Gintoki line after hear_first');

    const comparisonKey = qaKey(value);
    await tapControl(page, menuControls, 'single menu toolbar control');
    value = await waitForScreen(page, 'menu');
    assert.equal(value.node_id, targetNode, 'Opening the menu preserves the target story node');
    await capture(page, style, viewport, 'menu', value, run);
    await tapControl(page, closeMenuControls, 'menu close/resume');
    value = await waitForScreen(page, 'story');
    assert.equal(qaKey(value), comparisonKey, 'Closing menu does not advance the target line');
    assert.equal(fullText(value), textSamples.comparison);
    run.checks.push('menu opens and closes without moving the story');
    run.errors = errors;
    assert.deepEqual(errors, [], 'No browser or Godot errors at ' + style + ' ' + viewport.width + 'x' + viewport.height);
  } finally {
    await context.close();
  }
}

try {
  for (const viewport of viewports) {
    for (const style of styles) await runDebtComparison(style, viewport);
  }
  report.passed = true;
} catch (error) {
  report.passed = false;
  report.failure = error.stack || String(error);
  for (const context of browser.contexts()) {
    for (const page of context.pages()) {
      try {
        const value = await readState(page);
        const dimensions = value?.viewport || viewports[0];
        const canvas = await canvasBounds(page);
        const directory = path.join(output, 'failures');
        await fs.mkdir(directory, { recursive: true });
        const failurePath = path.join(directory, 'failure-' + Date.now() + '.png');
        await page.screenshot({ path: failurePath, fullPage: true });
        report.failureCapture = path.relative(root, failurePath).split(path.sep).join('/');
        report.failureState = value;
        report.failureCanvas = canvas;
        report.failureViewport = dimensions;
      } catch {
        // Keep the original acceptance failure as the report cause if a browser is already gone.
      }
    }
  }
  process.exitCode = 1;
  console.error(report.failure);
} finally {
  report.finished = new Date().toISOString();
  await fs.writeFile(path.join(output, 'report.json'), JSON.stringify(report, null, 2) + '\n');
  await browser.close();
  console.log('UI parity evidence: ' + output);
}
