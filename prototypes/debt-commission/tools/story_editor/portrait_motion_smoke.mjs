// Actual browser controls -> isolated project service -> Godot validation -> reload.
import {createRequire} from 'node:module';
import {spawn} from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';

const require = createRequire(import.meta.url);
const arg = (name, fallback) => process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : fallback;
const {chromium} = require(arg('--playwright', 'playwright-core'));
const root = path.resolve(import.meta.dirname, '../..');
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'debt-portrait-editor-'));
const put = (relative, data) => {
  const file = path.join(fixture, relative);
  fs.mkdirSync(path.dirname(file), {recursive: true});
  fs.writeFileSync(file, data);
};
const copy = relative => put(relative, fs.readFileSync(path.join(root, relative)));
for (const file of ['index.html', 'editor.js', 'editor_state.js', 'story_core.js', 'catalog_editor.js', 'editor.css']) copy(`tools/story_editor/${file}`);
for (const file of ['scripts/story_runner.gd', 'data/asset_catalog.json', 'data/phase3_story.json', 'skins/gintama/skin.json']) copy(file);
copy('assets/image/shin-pa-chi.png');
put('data/stories.json', JSON.stringify({stories: [{id: 'phase3', kind: 'sample', path: 'res://data/phase3_story.json', authoring: 'graph'}]}));
const port = arg('--port', '8894');
const server = spawn('python3', [path.join(import.meta.dirname, 'serve_editor_fixture.py'), '--root', fixture,
  '--port', port, '--godot', arg('--godot', '/Applications/Godot.app/Contents/MacOS/Godot')], {stdio: ['ignore', 'pipe', 'pipe']});
let log = '', browser;
server.stdout.on('data', data => log += data); server.stderr.on('data', data => log += data);
try {
  for (let i = 0; !log.includes('SKIN FIXTURE READY'); i++) {
    assert.ok(server.exitCode === null && i < 100, log);
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  browser = await chromium.launch({headless: true, executablePath: arg('--chromium', undefined)});
  const page = await browser.newPage({viewport: {width: 1600, height: 1000}});
  page.setDefaultTimeout(5000);
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.goto(`http://127.0.0.1:${port}/tools/story_editor/?story=phase3`);
  await page.waitForFunction(() => window.StoryEditor?.story && StoryEditor.state.service && StoryEditor.projectSource.ready);
  const id = 'phase3_open';
  await page.evaluate(id => StoryEditor.select({type: 'node', id}), id);
  const charIndex = await page.evaluate(id => StoryEditor.story.nodes[id].steps.findIndex(s => s.op === 'char' && s.id === 'shinpachi'), id);
  const character = page.locator(`#inspector [data-step="${charIndex}"]`);
  const field = (step, label) => step.locator('.field').filter({has: page.locator(`label:text-is("${label}")`)}).locator('select');
  await field(character, '角色狀態').selectOption('leave');
  await field(character, '進退場動畫').selectOption('slide_right');
  let entry = await page.evaluate(({id, charIndex}) => StoryEditor.story.nodes[id].steps[charIndex], {id, charIndex});
  assert.equal(entry.visible, false); assert.equal(entry.transition, 'slide_right');
  await field(character, '角色狀態').selectOption('enter');
  await field(character, '進退場動畫').selectOption('slide_left');
  await page.locator('#addStepPicker summary').click();
  await page.locator('#addStepOp').selectOption('character:portrait_effect');
  await page.getByRole('button', {name: '＋ 新增步驟'}).click();
  const effectIndex = await page.evaluate(id => StoryEditor.story.nodes[id].steps.findIndex(s => s.op === 'portrait_effect'), id);
  const effect = page.locator(`#inspector [data-step="${effectIndex}"]`);
  await field(effect, '角色').selectOption('shinpachi');
  await field(effect, '立繪動作').selectOption('bounce');
  await effect.scrollIntoViewIfNeeded();
  await page.screenshot({path: arg('--screenshot', '/private/tmp/debt-portrait-editor.png')});
  const response = page.waitForResponse(r => r.url().endsWith('/api/save'));
  await page.locator('#btnProjectSave').click();
  const saved = await response;
  assert.equal(saved.status(), 200, JSON.stringify(await saved.json()));
  await page.waitForFunction(() => !StoryEditor.state.dirty);
  const stored = JSON.parse(fs.readFileSync(path.join(fixture, 'data/phase3_story.json'))).nodes[id].steps;
  assert.equal(stored[charIndex].enter, true); assert.equal(stored[charIndex].transition, 'slide_left');
  assert.equal(stored[effectIndex].id, 'shinpachi'); assert.equal(stored[effectIndex].effect, 'bounce');
  await page.reload();
  await page.waitForFunction(() => window.StoryEditor?.story && StoryEditor.projectSource.ready);
  await page.evaluate(id => StoryEditor.select({type: 'node', id}), id);
  assert.equal(await field(character, '角色狀態').inputValue(), 'enter');
  assert.equal(await field(character, '進退場動畫').inputValue(), 'slide_left');
  assert.equal(await field(effect, '立繪動作').inputValue(), 'bounce');

  // Follow the same path an author takes to start a short story, entirely in the fixture.
  page.on('dialog', dialog => dialog.accept('portrait_intro_test'));
  await page.locator('#btnNewStory').click();
  await page.waitForFunction(() => StoryEditor.story?.id === 'portrait_intro_test');
  await page.evaluate(() => StoryEditor.select({type: 'node', id: 'start'}));
  const add = async value => {
    await page.locator('#addStepPicker summary').click();
    await page.locator('#addStepOp').selectOption(value);
    await page.getByRole('button', {name: '＋ 新增步驟'}).click();
  };
  await add('character:char');
  const newCharIndex = await page.evaluate(() => StoryEditor.story.nodes.start.steps.findIndex(s => s.op === 'char'));
  const newChar = page.locator(`#inspector [data-step="${newCharIndex}"]`);
  await field(newChar, '角色').selectOption('shinpachi');
  await field(newChar, '角色狀態').selectOption('enter');
  await field(newChar, '進退場動畫').selectOption('fade');
  await add('character:portrait_effect');
  const newEffectIndex = await page.evaluate(() => StoryEditor.story.nodes.start.steps.findIndex(s => s.op === 'portrait_effect'));
  const newEffect = page.locator(`#inspector [data-step="${newEffectIndex}"]`);
  await field(newEffect, '角色').selectOption('shinpachi');
  await field(newEffect, '立繪動作').selectOption('shake');
  const newResponse = page.waitForResponse(r => r.url().endsWith('/api/save'));
  await page.locator('#btnProjectSave').click();
  const newSave = await newResponse;
  assert.equal(newSave.status(), 200, JSON.stringify(await newSave.json()));
  await page.waitForFunction(() => !StoryEditor.state.dirty);
  const created = JSON.parse(fs.readFileSync(path.join(fixture, 'data/portrait_intro_test_story.json')));
  assert.equal(created.nodes.start.steps[newCharIndex].enter, true);
  assert.equal(created.nodes.start.steps[newEffectIndex].effect, 'shake');
  assert.ok(JSON.parse(fs.readFileSync(path.join(fixture, 'data/stories.json'))).stories.some(s => s.id === 'portrait_intro_test'));
  const say = page.locator('#inspector [data-step="0"] textarea').first();
  await say.fill('尚未存檔，也可以先試玩。');
  await page.locator('#previewConfig summary').click();
  const previewResponse = page.waitForResponse(r => r.url().endsWith('/api/preview'));
  await page.locator('#previewStart').click();
  const preview = await previewResponse;
  assert.equal(preview.status(), 200, JSON.stringify(await preview.json()));
  assert.equal(preview.request().postDataJSON().story.nodes.start.steps[0].text, '尚未存檔，也可以先試玩。');
  assert.deepEqual(errors, []);
  console.log('PORTRAIT EDITOR SMOKE PASSED: entrance, exit, reaction, save/reload and new story preview');
} finally {
  if (browser) await browser.close();
  server.kill('SIGTERM');
}
