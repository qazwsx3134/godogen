// Uses a temporary in-memory story; never writes the author's story files.
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const arg = (name, fallback) => process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : fallback;
const {chromium} = require(arg('--playwright', 'playwright-core'));
let browser;
try {
  browser = await chromium.launch({headless:true,executablePath:arg('--chromium', undefined)});
  const page = await browser.newPage({viewport:{width:1400,height:900}});
  page.setDefaultTimeout(5000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(pathToFileURL(path.join(import.meta.dirname, 'index.html')).href);
  await page.evaluate(async () => {
    await StoryEditor.ready;
    const story = StoryCore.newStory('insert_smoke');
    story.nodes.start.steps = Array.from({length:60}, (_, i) => ({op:'say',speaker:'narrator',text:`台詞 ${i}`,source_id:`L${i}`}));
    story.nodes.start.steps.push({op:'end',text:'結束'});
    StoryEditor.loadStory(story, 'insert_smoke.json');
  });
  await page.locator('.card[data-node="start"] .head').click();
  const steps = () => page.evaluate(() => StoryEditor.story.nodes.start.steps);
  const original = await steps();
  const gap = index => page.locator(`#inspector .step-insert[data-insert-index="${index}"]`);
  const open = async index => {
    await gap(index).locator('.insert-step-button').click();
    assert.equal(await gap(index).locator('.insert-step-button').isHidden(), true);
  };
  const insert = async (index, type) => {
    await open(index);
    await gap(index).locator('select').selectOption(type);
    await gap(index).locator('.confirm-insert').click();
    assert.equal(await page.locator(`#inspector .step[data-step="${index}"]`).evaluate(el => el.contains(document.activeElement)), true);
  };
  await open(30);
  await gap(30).getByRole('button', {name:'取消',exact:true}).click();
  assert.deepEqual(await steps(), original);
  assert.equal(await gap(30).locator('.insert-step-panel').count(), 0);
  await insert(30, 'narration:say');
  const middle = await steps();
  assert.deepEqual(middle[30], {op:'say',speaker:'narrator',text:''});
  assert.deepEqual(middle.toSpliced(30, 1), original);
  const visible = await page.locator('#inspector .step[data-step="30"] .step-head').evaluate(el => {
    const rect = el.getBoundingClientRect();
    return rect.top >= 0 && rect.top < window.innerHeight;
  });
  assert.equal(visible, true, 'inserting into a long scene scrolls to the new step');
  await page.locator('#btnUndo').click();
  assert.deepEqual(await steps(), original);
  await page.locator('#btnRedo').click();
  assert.deepEqual(await steps(), middle);
  await insert(0, 'scene:bg');
  assert.equal((await steps())[0].op, 'bg');
  const endingIndex = (await steps()).length - 1;
  await open(endingIndex);
  await gap(endingIndex).locator('select').selectOption('event:choice');
  const beforeError = await steps();
  await gap(endingIndex).locator('.confirm-insert').click();
  assert.match(await gap(endingIndex).locator('.err').textContent(), /最後一步/);
  assert.deepEqual(await steps(), beforeError);
  await gap(endingIndex).locator('select').selectOption('narration:say');
  await gap(endingIndex).locator('.confirm-insert').click();
  assert.deepEqual((await steps()).at(-1), original.at(-1));
  // Existing append control still inserts before the ending.
  await page.locator('#addStepPicker').evaluate(el => { el.open = true; });
  await page.locator('#addStepOp').selectOption('narration:say');
  await page.getByRole('button', {name:'＋ 新增步驟',exact:true}).click();
  assert.equal((await steps()).length, original.length + 4);
  assert.deepEqual((await steps()).at(-1), original.at(-1));
  await page.evaluate(() => {
    const story = StoryCore.newStory('insert_readonly');
    story.generated_from = 'fixture';
    StoryEditor.loadStory(story, 'insert_readonly.json');
  });
  await page.locator('.card[data-node="start"] .head').click();
  assert.equal(await gap(0).locator('.insert-step-button').isDisabled(), true);
  assert.deepEqual(errors, []);
  console.log('PASS: long scene insertion, positions, focus, cancel, undo/redo, terminal guard, append and read-only');
} finally {
  await browser?.close();
}
