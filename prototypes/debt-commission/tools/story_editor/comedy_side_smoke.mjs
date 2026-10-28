// Exercise the real editor control and save validation against a disposable project.
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
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'debt-comedy-side-'));
const put = (relative, data) => {
  const file = path.join(fixture, relative);
  fs.mkdirSync(path.dirname(file), {recursive: true});
  fs.writeFileSync(file, data);
};
const copy = relative => put(relative, fs.readFileSync(path.join(root, relative)));
for (const file of ['index.html', 'editor.js', 'editor_state.js', 'story_core.js', 'catalog_editor.js', 'editor.css']) copy(`tools/story_editor/${file}`);
for (const file of ['scripts/story_runner.gd', 'data/asset_catalog.json', 'skins/gintama/skin.json']) copy(file);
const editableStory = JSON.parse(fs.readFileSync(path.join(root, 'data/comedy_story.json')));
delete editableStory.generated_from;
put('data/comedy_story.json', JSON.stringify(editableStory));
put('data/stories.json', JSON.stringify({stories: [{id: 'comedy', kind: 'sample', path: 'res://data/comedy_story.json', authoring: 'graph'}]}));
const port = arg('--port', '8893');
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
  await page.goto(`http://127.0.0.1:${port}/tools/story_editor/?story=comedy`);
  await page.waitForFunction(() => window.StoryEditor?.story && StoryEditor.state.service && StoryEditor.projectSource.ready);
  const id = 'comedy_open';
  await page.evaluate(id => StoryEditor.select({type: 'node', id}), id);
  const index = await page.evaluate(id => StoryEditor.story.nodes[id].steps.findIndex(step => step.op === 'comedy'), id);
  const step = page.locator(`#inspector [data-step="${index}"]`);
  const side = () => step.locator('.field').filter({hasText: '出場位置'}).locator('select');
  const preset = () => step.locator('.field').filter({has: page.locator('label:text-is("preset")')}).locator('select');
  const data = () => page.evaluate(({id, index}) => StoryEditor.story.nodes[id].steps[index], {id, index});
  assert.equal(await side().inputValue(), '');
  await side().selectOption('right');
  assert.equal((await data()).side, 'right');
  await preset().selectOption('small_reaction');
  assert.equal((await data()).side, undefined);
  assert.equal(await side().count(), 0);
  await preset().selectOption('tsukkomi_impact');
  await side().selectOption('left');
  assert.equal((await data()).side, 'left');
  await side().selectOption('');
  assert.equal((await data()).side, undefined);
  await side().selectOption('right');
  const response = page.waitForResponse(r => r.url().endsWith('/api/save'));
  await page.locator('#btnProjectSave').click();
  const saved = await response;
  assert.equal(saved.status(), 200, JSON.stringify(await saved.json()));
  await page.waitForFunction(() => !StoryEditor.state.dirty);
  assert.equal(JSON.parse(fs.readFileSync(path.join(fixture, 'data/comedy_story.json'))).nodes[id].steps[index].side, 'right');
  await page.reload();
  await page.waitForFunction(() => window.StoryEditor?.story && StoryEditor.projectSource.ready);
  await page.evaluate(id => StoryEditor.select({type: 'node', id}), id);
  assert.equal(await side().inputValue(), 'right');
  assert.deepEqual(errors, []);
  console.log('COMEDY SIDE EDITOR SMOKE PASSED: select, clear, change preset, validate, save and reload');
} finally {
  if (browser) await browser.close();
  server.kill('SIGTERM');
}
