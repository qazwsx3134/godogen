// Real browser controls -> private editor service -> headless game preview, using temporary project data.
import {createRequire} from 'node:module';
import {spawn, spawnSync} from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';

const require = createRequire(import.meta.url);
const arg = (name, fallback) => process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : fallback;
const {chromium} = require(arg('--playwright', 'playwright-core'));
const root = path.resolve(import.meta.dirname, '../..');
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'debt-preview-browser-'));
const out = path.resolve(arg('--out', '/tmp/debt-preview-smoke'));
fs.mkdirSync(out, {recursive: true});
const port = arg('--port', '8888');
const put = (relative, data) => {const file = path.join(fixture, relative); fs.mkdirSync(path.dirname(file), {recursive: true}); fs.writeFileSync(file, data);};
const copy = relative => put(relative, fs.readFileSync(path.join(root, relative)));
for (const file of ['index.html', 'editor.js', 'editor_state.js', 'story_core.js', 'catalog_editor.js', 'editor.css']) copy(`tools/story_editor/${file}`);
for (const file of ['scripts/story_runner.gd', 'data/asset_catalog.json', 'data/phase3_story.json', 'data/ep00_story.json', 'skins/gintama/skin.json']) copy(file);
copy('assets/image/shin-pa-chi.png');
put('data/stories.json', JSON.stringify({stories: [
  {id: 'phase3', kind: 'sample', path: 'res://data/phase3_story.json', authoring: 'graph'},
  {id: 'ep00', kind: 'sample', path: 'res://data/ep00_story.json', authoring: 'dialogue'},
]}));
const before = fs.readFileSync(path.join(fixture, 'data/phase3_story.json'));
const server = spawn('python3', [path.join(import.meta.dirname, 'serve_editor_fixture.py'), '--root', fixture,
  '--port', port, '--godot', arg('--godot', '/Applications/Godot.app/Contents/MacOS/Godot')], {stdio: ['ignore', 'pipe', 'pipe']});
let log = ''; server.stdout.on('data', b => log += b); server.stderr.on('data', b => log += b);
let browser;
try {
  for (let i = 0; !log.includes('SKIN FIXTURE READY'); i++) {
    assert.ok(server.exitCode === null && i < 100, log);
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  browser = await chromium.launch({headless: true, executablePath: arg('--chromium', undefined)});
  const page = await browser.newPage({viewport: {width: 1600, height: 1000}});
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.goto(`http://127.0.0.1:${port}/tools/story_editor/?story=phase3`);
  await page.waitForFunction(() => window.StoryEditor?.story && StoryEditor.state.service && StoryEditor.projectSource.ready);
  const id = await page.evaluate(() => StoryEditor.story.entry);
  await page.evaluate(id => StoryEditor.centerOn(id, 0.9), id);
  await page.locator(`.card[data-node="${id}"] .head`).click();
  const index = await page.evaluate(id => StoryEditor.story.nodes[id].steps.findIndex(s => s.op === 'say'), id);
  const dialogue = page.locator(`#inspector [data-step="${index}"]`);
  const text = dialogue.locator('textarea').first();
  await text.fill('瀏覽器裡尚未存檔的台詞。');
  const charIndex = await page.evaluate(id => StoryEditor.story.nodes[id].steps.findIndex(s => s.op === 'char' && s.id === 'shinpachi'), id);
  const character = page.locator(`#inspector [data-step="${charIndex}"]`);
  const actor = character.locator('.stage-position-actor'), stage = character.locator('.stage-position-preview');
  await actor.scrollIntoViewIfNeeded();
  assert.equal(await actor.locator('img').evaluate(img => img.complete && img.naturalWidth > 0), true);
  const from = await actor.boundingBox(), to = await stage.boundingBox();
  await page.mouse.move(from.x + from.width / 2, from.y + from.height / 2);
  await page.mouse.down();
  await page.mouse.move(to.x + to.width * 0.85, to.y + to.height / 2, {steps: 8});
  await page.mouse.up();
  assert.equal(await page.evaluate(({id, charIndex}) => StoryEditor.story.nodes[id].steps[charIndex].position, {id, charIndex}), 'right');
  assert.equal(await character.getByRole('button', {name: '右側'}).getAttribute('aria-pressed'), 'true');
  await page.locator('#btnUndo').click();
  assert.equal(await page.evaluate(({id, charIndex}) => StoryEditor.story.nodes[id].steps[charIndex].position, {id, charIndex}), undefined);
  await page.locator('#btnRedo').click();
  assert.equal(await page.evaluate(({id, charIndex}) => StoryEditor.story.nodes[id].steps[charIndex].position, {id, charIndex}), 'right');
  await character.getByRole('button', {name: '中央'}).click();
  assert.equal(await page.evaluate(({id, charIndex}) => StoryEditor.story.nodes[id].steps[charIndex].position, {id, charIndex}), 'center');
  await character.getByRole('button', {name: '右側'}).click();
  await actor.scrollIntoViewIfNeeded();
  await page.screenshot({path: path.join(out, 'character-position.png')});
  console.log('ok  a portrait can be dragged or selected by button, with undo and redo');
  await page.locator('#previewConfig summary').click();
  await page.locator('#previewConfig .field').filter({hasText: 'round_result'}).locator('input').fill('perfect');
  await page.locator('#previewConfig .preview-item').filter({hasText: 'milk_bottle'}).locator('input').check();
  const responsePromise = page.waitForResponse(r => r.url().endsWith('/api/preview'));
  await page.locator('#previewStart').click();
  const response = await responsePromise, result = await response.json();
  assert.equal(response.status(), 200, JSON.stringify(result));
  const sent = response.request().postDataJSON();
  assert.equal(sent.node, id); assert.equal(sent.flags.round_result, 'perfect');
  assert.deepEqual(sent.items, ['milk_bottle']);
  assert.equal(sent.story.nodes[id].steps[index].text, '瀏覽器裡尚未存檔的台詞。');
  assert.equal(sent.story.nodes[id].steps[charIndex].position, 'right');
  assert.equal(await page.evaluate(() => StoryEditor.state.dirty), true);
  assert.deepEqual(fs.readFileSync(path.join(fixture, 'data/phase3_story.json')), before);
  await page.locator('#previewConfig').scrollIntoViewIfNeeded();
  await page.screenshot({path: path.join(out, 'preview-controls.png')});
  console.log('ok  edited scene, flags and item reach the real headless game; unsaved text and disk remain intact');

  let release, arrived;
  const gate = new Promise(resolve => release = resolve), seen = new Promise(resolve => arrived = resolve);
  await page.route('**/api/preview', async route => {
    const pending = await route.fetch(); arrived(); await gate; await route.fulfill({response: pending});
  });
  await page.locator('#previewStart').click(); await seen;
  await page.evaluate(() => { StoryEditor.centerOn('gintoki_round', 0.9); StoryEditor.select({type: 'node', id: 'gintoki_round'}); });
  await page.locator('#previewConfig summary').click();
  assert.equal(await page.locator('#previewStart').isDisabled(), true);
  release();
  await page.waitForFunction(() => !document.querySelector('#previewStart').disabled);
  await page.unroute('**/api/preview');
  await page.evaluate(id => { StoryEditor.centerOn(id, 0.9); StoryEditor.select({type: 'node', id}); }, id);
  await page.locator('#previewConfig summary').click();
  console.log('ok  switching scenes during startup restores the new scene preview button');

  await page.route('**/api/preview', route => route.fulfill({status: 503, contentType: 'application/json',
    body: JSON.stringify({error: '模擬啟動失敗', errors: ['測試錯誤']})}));
  await page.locator('#previewStart').click();
  await page.waitForFunction(() => document.querySelector('#problems').textContent.includes('測試錯誤'));
  assert.equal(await text.inputValue(), '瀏覽器裡尚未存檔的台詞。');
  assert.equal(await page.evaluate(() => StoryEditor.state.dirty), true);
  await page.unroute('**/api/preview');
  console.log('ok  failed preview reports the error without losing edits');

  const answers = [];
  page.on('dialog', dialog => dialog.type() === 'prompt' ? dialog.accept(answers.shift() || '') : dialog.accept());
  await page.goto(`http://127.0.0.1:${port}/tools/story_editor/?story=ep00`);
  await page.waitForFunction(() => window.StoryEditor?.story?.id === 'ep00' && StoryEditor.state.service);
  const builtId = await page.evaluate(() => StoryEditor.story.entry);
  await page.evaluate(id => StoryEditor.centerOn(id, 0.9), builtId);
  await page.locator(`.card[data-node="${builtId}"] .head`).click();
  assert.equal(await page.evaluate(() => StoryEditor.isReadOnly()), true);
  await page.locator('#previewConfig summary').click();
  assert.equal(await page.locator('#previewStart').isEnabled(), true);
  const builtResponse = page.waitForResponse(r => r.url().endsWith('/api/preview'));
  await page.locator('#previewStart').click();
  const built = await builtResponse; assert.equal(built.status(), 200, JSON.stringify(await built.json()));

  // A small complete branching story made with the visible authoring controls, in the fixture only.
  answers.push('workflow_demo');
  await page.locator('#btnNewStory').click();
  await page.waitForFunction(() => StoryEditor.story?.id === 'workflow_demo');
  await page.evaluate(() => StoryEditor.select({type: 'node', id: 'start'}));
  await page.locator('#addStepPicker summary').click();
  await page.locator('#addStepOp').selectOption('event:choice');
  await page.getByRole('button', {name: '＋ 新增步驟'}).click();
  assert.deepEqual(await page.evaluate(() => StoryEditor.story.nodes.start.steps.map(step => step.op)), ['say', 'choice']);
  for (let i = 0; i < 3; i++) await page.locator('#btnAddNode').click();
  await page.evaluate(() => StoryEditor.select({type: 'node', id: 'start'}));
  const choice = page.locator('#inspector [data-step="1"]');
  await choice.getByRole('button', {name: '＋選項'}).click();
  for (let i = 0; i < 3; i++) await page.locator('#inspector [data-step="1"] .opt').nth(i).locator('select').selectOption(`node_${i + 1}`);
  assert.deepEqual(await page.evaluate(() => StoryEditor.state.a.problems), []);
  const savedResponse = page.waitForResponse(r => r.url().endsWith('/api/save'));
  await page.locator('#btnProjectSave').click();
  const saved = await savedResponse; assert.equal(saved.status(), 200, JSON.stringify(await saved.json()));
  await page.waitForFunction(() => !StoryEditor.state.dirty);
  const authoredFile = path.join(fixture, 'data/workflow_demo_story.json');
  const runnerCheck = spawnSync('python3', [path.join(import.meta.dirname, 'run_coordinated.py'),
    arg('--godot', '/Applications/Godot.app/Contents/MacOS/Godot'), '--headless', '--path', root,
    '--script', 'res://tools/story_editor/test_authored_branches.gd', '--', authoredFile], {encoding: 'utf8', timeout: 30000});
  assert.equal(runnerCheck.status, 0, (runnerCheck.stdout || '') + (runnerCheck.stderr || ''));
  assert.match(runnerCheck.stdout, /AUTHORED BRANCHES PASSED/);
  console.log('ok  created a story with three endings in the editor, saved it, and played all three branches through StoryRunner');
  assert.deepEqual(errors, []);
  console.log('ok  a built, read-only story can also be previewed without conversion');
  console.log('PREVIEW BROWSER SMOKE PASSED');
} finally {
  await browser?.close(); server.kill();
  if (server.exitCode === null) await new Promise(resolve => server.once('exit', resolve));
  fs.writeFileSync(path.join(out, 'server.log'), log);
  fs.rmSync(fixture, {recursive: true, force: true});
}
