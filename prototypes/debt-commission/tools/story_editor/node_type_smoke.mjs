// Browser regression for the scene menu and step type picker. Uses only an in-memory story.
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';

const require = createRequire(import.meta.url);
const arg = (name, fallback) => process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : fallback;
const {chromium} = require(arg('--playwright', 'playwright-core'));
let browser;
try {
  browser = await chromium.launch({headless: true, executablePath: arg('--chromium', undefined)});
  const page = await browser.newPage({viewport: {width: 1400, height: 900}});
  page.setDefaultTimeout(5000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  let acceptChange = true, confirmations = 0;
  page.on('dialog', dialog => { confirmations++; return acceptChange ? dialog.accept() : dialog.dismiss(); });
  await page.goto(pathToFileURL(path.join(import.meta.dirname, 'index.html')).href);
  await page.evaluate(async () => { await StoryEditor.ready; StoryEditor.loadStory(StoryCore.newStory('node_type_smoke'), 'node_type_smoke.json'); });
  const storyNode = () => page.evaluate(() => StoryEditor.story.nodes.start);
  const head = () => page.locator('.card[data-node="start"] .head');
  const menu = page.locator('#nodeContextMenu');
  const openMenu = () => head().click({button: 'right'});

  await openMenu();
  assert.equal(await menu.isVisible(), true);
  assert.doesNotMatch(await menu.textContent(), /false/);
  await menu.locator('[data-scene-type="choice"]').click();
  assert.equal((await storyNode()).steps.at(-1).op, 'choice');
  await openMenu();
  await menu.locator('[data-action="add-option"]').click();
  assert.equal((await storyNode()).steps.at(-1).options.length, 3);
  await page.locator('#btnUndo').click();
  assert.equal((await storyNode()).steps.at(-1).options.length, 2);
  await page.locator('#btnRedo').click();
  assert.equal((await storyNode()).steps.at(-1).options.length, 3);

  acceptChange = false;
  await openMenu();
  await menu.locator('[data-scene-type="goto"]').click();
  assert.equal((await storyNode()).steps.at(-1).op, 'choice');
  assert.equal(confirmations, 1);
  acceptChange = true;
  await openMenu();
  await menu.locator('[data-scene-type="goto"]').click();
  assert.equal((await storyNode()).steps.at(-1).op, 'goto');
  assert.equal(confirmations, 2);

  await page.locator('.flow-node[data-step="0"]').click({button: 'right'});
  await menu.locator('[data-action="edit-step"]').click();
  const type = page.locator('#inspector .step[data-step="0"] .step-type-picker');
  await type.selectOption('event:choice');
  assert.match(await page.locator('#inspector .step[data-step="0"] .err').first().textContent(), /最後一步/);
  assert.equal((await storyNode()).steps[0].op, 'say');
  await type.selectOption('dialogue:say');
  assert.notEqual((await storyNode()).steps[0].speaker, 'narrator');

  const button = page.locator('.card[data-node="start"] .node-menu-button');
  await button.click();
  assert.equal(await button.getAttribute('aria-expanded'), 'true');
  await page.keyboard.press('Escape');
  assert.equal(await menu.isHidden(), true);
  assert.equal(await button.getAttribute('aria-expanded'), 'false');

  await page.evaluate(() => {
    const story = StoryCore.newStory('node_type_readonly');
    story.generated_from = 'fixture';
    StoryEditor.loadStory(story, 'node_type_readonly.json');
  });
  await openMenu();
  assert.equal(await menu.locator('[data-scene-type="choice"]').isDisabled(), true);
  assert.equal(await menu.locator('[data-action="add-option"]').isDisabled(), true);
  assert.equal(await page.locator('#inspector .step-type-picker').first().isDisabled(), true);
  assert.deepEqual(errors, []);
  console.log('PASS: scene menu, choice, undo/redo, confirmation, step types, keyboard and read-only');
} finally {
  await browser?.close();
}
