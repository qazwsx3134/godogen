// Actual editor controls, temporary library and synthetic confirmation receipts only.
import {createRequire} from 'node:module';
import {spawn, spawnSync} from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';

const require = createRequire(import.meta.url);
const arg = (name, fallback) => process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : fallback;
const {chromium} = require(arg('--playwright', 'playwright-core'));
const root = path.resolve(import.meta.dirname, '../..');
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'debt-persona-editor-'));
const out = arg('--out', '/private/tmp/debt-persona-editor-evidence');
fs.mkdirSync(out, {recursive: true});
const put = (relative, data) => {
  const file = path.join(fixture, relative);
  fs.mkdirSync(path.dirname(file), {recursive: true});
  fs.writeFileSync(file, data);
};
const copy = file => put(file, fs.readFileSync(path.join(root, file)));
const canonical = value => Array.isArray(value) ? value.map(canonical) : value && typeof value === 'object'
  ? Object.fromEntries(Object.keys(value).sort().map(k => [k, canonical(value[k])])) : value;
const hash = value => crypto.createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
for (const name of ['index.html', 'editor.js', 'editor_state.js', 'story_core.js', 'catalog_editor.js', 'editor.css']) copy(`tools/story_editor/${name}`);
for (const name of ['data/asset_catalog.json', 'data/phase3_story.json', 'scripts/story_runner.gd']) copy(name);
put('data/stories.json', JSON.stringify({stories: [{id: 'phase3', kind: 'sample', path: 'res://data/phase3_story.json', authoring: 'graph'}]}));
const manifest = {schema_version: 1, records: {}};
for (const folder of ['characters', 'memories']) {
  for (const name of fs.readdirSync(path.join(root, 'authoring', folder)).filter(n => n.endsWith('.json'))) {
    const record = JSON.parse(fs.readFileSync(path.join(root, 'authoring', folder, name)));
    if (record.kind === 'memory') record.known_to = [record.owner]; // Exercise private knowledge.
    put(`authoring/${folder}/${name}`, JSON.stringify(record));
    manifest.records[record.id] = {decision:'confirmed', sha256:hash(record), reviewer:'synthetic fixture',
      evidence:'TEST ONLY, not actual author consent', confirmed_at:'2026-10-28T00:00:00Z'};
  }
}
const draft = JSON.parse(fs.readFileSync(path.join(fixture, 'authoring/characters/gintoki.json')));
draft.id = 'draft_person'; draft.name = '<script>draft</script>';
put('authoring/characters/draft_person.json', JSON.stringify(draft));
put('authoring/confirmations.json', JSON.stringify(manifest));
const libraryBefore = fs.readFileSync(path.join(fixture, 'authoring/confirmations.json'));
const server = spawn('python3', [path.join(import.meta.dirname, 'project_server.py'), '--project', fixture, '--port', '0'],
  {stdio:['ignore','pipe','pipe']});
let log = '', browser;
server.stdout.on('data', b => log += b); server.stderr.on('data', b => log += b);
try {
  for (let i = 0; !log.match(/http:\/\/127\.0\.0\.1:\d+\//); i++) {
    assert.ok(server.exitCode === null && i < 100, log);
    await new Promise(r => setTimeout(r, 100));
  }
  const url = log.match(/http:\/\/127\.0\.0\.1:\d+/)[0];
  browser = await chromium.launch({headless: true, executablePath:arg('--chromium', undefined)});
  const page = await browser.newPage({viewport:{width:1366,height:900}, acceptDownloads:true});
  const errors = []; page.on('pageerror', e => errors.push(e.message));
  await page.goto(`${url}/tools/story_editor/?story=phase3`);
  await page.waitForFunction(() => window.StoryEditor?.story && StoryEditor.state.service);
  const storyBefore = await page.evaluate(() => StoryEditor.exportText());
  await page.locator('#btnPersonas').click();
  const panel = page.locator('#personaPanel');
  const check = id => panel.locator(`input[data-persona-id="${id}"]`);
  await check('gintoki').waitFor();
  assert.ok(await check('draft_person').isDisabled());
  assert.ok(await check('gintoki_yorozuya_baseline').isDisabled());
  await check('gintoki').check(); await check('shinpachi').check();
  await panel.locator('#personaGenerate').click();
  await page.waitForFunction(() => document.getElementById('personaOutput')?.value);
  let context = JSON.parse(await panel.locator('#personaOutput').inputValue());
  assert.deepEqual(context.memories_by_character, {gintoki:[], shinpachi:[]});
  await check('gintoki_yorozuya_baseline').check();
  assert.equal(await panel.locator('#personaOutput').isVisible(), false);
  assert.ok(await panel.locator('#personaDownload').isDisabled());
  await panel.locator('#personaGenerate').click();
  await page.waitForFunction(() => document.getElementById('personaOutput')?.value);
  context = JSON.parse(await panel.locator('#personaOutput').inputValue());
  assert.equal(context.memories_by_character.gintoki.length, 1);
  assert.equal(context.memories_by_character.shinpachi.length, 0);
  const cli = spawnSync('python3', [path.join(root,'tools/persona_context.py'), '--root', path.join(fixture,'authoring'),
    'context','--characters','gintoki','shinpachi','--memories','gintoki_yorozuya_baseline'], {encoding:'utf8'});
  assert.equal(cli.status,0,cli.stderr); assert.deepEqual(context,JSON.parse(cli.stdout));
  const event = page.waitForEvent('download');
  await panel.locator('#personaDownload').click();
  const file = await event; await file.saveAs(path.join(out, 'authoring-context.fixture.json'));
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(out,'authoring-context.fixture.json'))),context);
  await panel.getByText('查看完整參考內容',{exact:true}).first().click();
  assert.ok(await panel.getByText('人格核心',{exact:true}).first().isVisible());
  await page.screenshot({path:path.join(out,'persona-desktop.png')});
  await check('gintoki').uncheck();
  assert.equal(await check('gintoki_yorozuya_baseline').isChecked(),false);
  assert.ok(await check('gintoki_yorozuya_baseline').isDisabled());
  // A re-approved file changed after opening must still require a fresh view.
  const filename = path.join(fixture,'authoring/characters/shinpachi.json');
  const changed = JSON.parse(fs.readFileSync(filename)); changed.revision++;
  fs.writeFileSync(filename,JSON.stringify(changed)); manifest.records.shinpachi.sha256=hash(changed);
  put('authoring/confirmations.json',JSON.stringify(manifest));
  await panel.locator('#personaGenerate').click();
  await page.waitForFunction(() => document.getElementById('personaMessage')?.textContent.includes('資料已更新'));
  assert.ok(await panel.locator('#personaDownload').isDisabled());
  await panel.press('Escape'); await panel.waitFor({state:'detached'});
  assert.equal(await page.evaluate(() => StoryEditor.exportText()),storyBefore);
  assert.equal(await page.evaluate(() => StoryEditor.state.dirty),false);
  await page.locator('#btnPersonas').click(); await check('shinpachi').check();
  await panel.locator('#personaGenerate').click();
  await page.waitForFunction(() => document.getElementById('personaOutput')?.value);
  assert.equal(JSON.parse(await panel.locator('#personaOutput').inputValue()).versions.shinpachi.revision,changed.revision);
  await page.setViewportSize({width:640,height:600});
  await page.screenshot({path:path.join(out,'persona-narrow.png')});
  const bounds=await panel.boundingBox(); assert.ok(bounds.x>=0 && bounds.x+bounds.width<=640);
  await panel.getByRole('button',{name:'關閉',exact:true}).click();
  assert.equal(await page.evaluate(() => StoryEditor.exportText()),storyBefore);
  // The UI never approves anything, even while exporting data.
  const receipts = JSON.parse(fs.readFileSync(path.join(fixture,'authoring/confirmations.json')));
  assert.equal(receipts.records.draft_person,undefined);
  assert.equal(JSON.parse(libraryBefore).records.gintoki.sha256,receipts.records.gintoki.sha256);
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({passed:true,checks:[
    'draft disabled; memory owner required','explicit memories and known_to isolation',
    'UI export equals CLI; JSON download','selection clears stale output',
    'changed approved version requires refresh','dialog keyboard and story preserved',
    'narrow viewport; no page errors; no automatic confirmation']},null,2));
  console.log(`PASS persona editor smoke: ${out}`);
} finally {
  await browser?.close();
  const exited = new Promise(r => server.once('exit',r));
  if(server.exitCode===null) {server.kill('SIGTERM'); await exited;}
  fs.writeFileSync(path.join(out,'server.log'),log);
  fs.rmSync(fixture,{recursive:true,force:true});
}
