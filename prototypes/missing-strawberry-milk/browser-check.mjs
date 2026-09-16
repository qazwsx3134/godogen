import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const directory = dirname(fileURLToPath(import.meta.url));
function option(name, fallback) {
  const index = process.argv.indexOf(name);
  if (index === -1) return fallback;
  assert.ok(process.argv[index + 1] && !process.argv[index + 1].startsWith('--'), `${name} needs a value`);
  return process.argv[index + 1];
}
const { chromium } = require(option('--playwright', '@playwright/test'));
const url = option('--url', 'http://127.0.0.1:5191');
const output = resolve(option('--out', resolve(directory, 'qa/browser-smoke')));
await mkdir(output, { recursive: true });

const report = {
  startedAt: new Date().toISOString(),
  status: 'running',
  url,
  viewport: { width: 1280, height: 800 },
  sources: {},
  cases: [],
  errors: [],
  screenshots: [],
  scope: 'Existing text prototype: DOM navigation, real timers, endings and restart.',
  limitations: 'Does not measure comedy, reading pace, immersion, or future art, exploration and authoring features.',
};
for (const path of [
  'index.html', 'package-lock.json', 'src/main.ts', 'src/style.css', 'src/types.ts',
  'src/core/DialogueManager.ts', 'src/core/ChoiceSystem.ts', 'src/core/TsukkomiSystem.ts',
  'src/data/scenes/missingStrawberryMilk.ts',
]) {
  report.sources[path] = createHash('sha256').update(await readFile(resolve(directory, path))).digest('hex');
}

const suspects = [
  { id: 'ask_shinpachi', firstLine: '我才不會喝那種甜死人的東西！' },
  { id: 'ask_kagura', firstLine: '咪呀，我對牛奶沒興趣，我只喝優格。' },
  { id: 'ask_landlady', firstLine: '在問這個之前，你們這個月的房租呢？' },
];
const outcomes = [
  { id: 'meta', result: 'TSUKKOMI PERFECT', opening: '你這樣講他會生氣吧！', ending: '這就是江戶日常。' },
  { id: 'scared', result: '……', opening: '這樣是要吐槽什麼啦！', ending: '所以我們剛剛到底在幹嘛！' },
  { id: 'deflect', result: '……', opening: '這樣是要吐槽什麼啦！', ending: '所以我們剛剛到底在幹嘛！' },
  { id: 'timeout', result: '⏰ 時間到！', opening: '這樣是要吐槽什麼啦！', ending: '所以我們剛剛到底在幹嘛！' },
];

async function advanceUntil(page, selector) {
  for (let step = 0; step < 40; step += 1) {
    if (await page.locator(selector).isVisible()) return;
    await page.locator('[data-action="next-line"], [data-action="advance"]').click();
  }
  throw new Error(`Dialogue did not reach ${selector} within 40 advances`);
}

async function screenshot(page, name) {
  await page.screenshot({ path: resolve(output, name), fullPage: true });
  report.screenshots.push(name);
}

let browser;
let page;
try {
  browser = await chromium.launch({ headless: true });
  report.browser = await browser.version();
  page = await browser.newPage({ viewport: report.viewport });
  page.setDefaultTimeout(5000);
  page.on('pageerror', error => report.errors.push(`pageerror: ${error.message}`));
  page.on('console', message => {
    if (message.type() === 'error') report.errors.push(`console: ${message.text()}`);
  });
  page.on('requestfailed', request => report.errors.push(`requestfailed: ${request.url()}: ${request.failure()?.errorText}`));
  page.on('response', response => {
    if (response.status() >= 400) report.errors.push(`HTTP ${response.status()}: ${response.url()}`);
  });

  for (const suspect of suspects) {
    for (const outcome of outcomes) {
      const name = `${suspect.id}/${outcome.id}`;
      await page.goto(url);
      assert.equal(await page.title(), '消失的草莓牛奶');
      assert.equal(await page.locator('.text').first().innerText(), '……沒了。');
      if (report.cases.length === 0) await screenshot(page, 'opening.png');

      await advanceUntil(page, '[data-action="choice"][data-option="ask_shinpachi"]');
      assert.equal(await page.locator('[data-action="choice"]').count(), 3);
      if (report.cases.length === 0) await screenshot(page, 'suspects.png');
      await page.locator(`[data-action="choice"][data-option="${suspect.id}"]`).click();
      assert.equal(await page.locator('.text').first().innerText(), suspect.firstLine);
      await advanceUntil(page, '.tsukkomi-announce');
      await page.locator('[data-action="tsukkomi"]').first().waitFor();
      const countdown = parseFloat(await page.locator('#tsukkomi-countdown').innerText());
      assert.ok(countdown > 1.5 && countdown <= 2, `${name}: countdown begins near two seconds`);
      const choosingAt = Date.now();

      if (report.cases.length === 0) await screenshot(page, 'tsukkomi.png');
      if (outcome.id === 'timeout') {
        // Real time, without a fake browser clock or a direct call into the game core.
        await page.locator('.tsukkomi-result').waitFor();
        const elapsed = Date.now() - choosingAt;
        assert.ok(elapsed >= 1500 && elapsed < 5000, `${name}: observed timeout ${elapsed} ms`);
        report.cases.push({ name, timeoutObservedMs: elapsed, status: 'pending' });
      } else {
        const target = page.locator(`[data-action="tsukkomi"][data-option="${outcome.id}"]`);
        if (report.cases.length === 0) {
          // Regression: holding a pointer across countdown updates must still register a click.
          const box = await target.boundingBox();
          assert.ok(box, 'Timed option has a visible hit target');
          await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
          await page.mouse.down();
          await page.waitForTimeout(250);
          await page.mouse.up();
        } else {
          await target.click();
        }
        await page.locator('.tsukkomi-result').waitFor();
        report.cases.push({ name, heldAcrossTimerTick: report.cases.length === 0, status: 'pending' });
      }
      assert.equal(await page.locator('.tsukkomi-result').innerText(), outcome.result);
      assert.equal(await page.locator('[data-action="tsukkomi"]').count(), 0);
      await page.getByText(outcome.opening, { exact: true }).waitFor();
      await advanceUntil(page, '[data-action="restart"]');
      assert.ok((await page.locator('#app').innerText()).includes(outcome.ending), `${name}: expected ending`);
      assert.equal(await page.locator('.the-end').innerText(), '— 完 —');
      if (name === 'ask_shinpachi/meta') await screenshot(page, 'ending-success.png');
      if (name === 'ask_shinpachi/timeout') await screenshot(page, 'ending-timeout.png');

      await page.locator('[data-action="restart"]').click();
      assert.equal(await page.locator('.text').count(), 1);
      assert.equal(await page.locator('.text').innerText(), '……沒了。');
      assert.equal(await page.locator('.tsukkomi-result, .the-end').count(), 0);
      report.cases.at(-1).status = 'passed';
      console.log(`PASS ${name}: correct ending and restart`);
    }
  }

  await page.waitForTimeout(2700);
  assert.equal(await page.locator('.text').count(), 1, 'Restart remains at the opening after old timer deadlines');
  assert.equal(await page.locator('.text').innerText(), '……沒了。');
  assert.deepEqual(report.errors, [], 'No browser console, runtime, network or HTTP errors');
  assert.equal(report.cases.length, 12);
  report.restartAfterTimerDeadline = 'passed';
  report.status = 'passed';
} catch (error) {
  report.status = 'failed';
  report.failure = error.stack ?? String(error);
  if (page) await screenshot(page, 'failure.png').catch(() => {});
  console.error(report.failure);
  process.exitCode = 1;
} finally {
  report.finishedAt = new Date().toISOString();
  await writeFile(resolve(output, 'evidence.json'), `${JSON.stringify(report, null, 2)}\n`);
  if (browser) await browser.close();
}
console.log(`${report.status.toUpperCase()}: ${report.cases.filter(item => item.status === 'passed').length}/12 browser cases; ${resolve(output, 'evidence.json')}`);
