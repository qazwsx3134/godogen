// Real editor -> local service -> Godot -> phase3 gameplay test; restores the live file in finally.
import { createRequire } from 'node:module';
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const arg = (name, fallback) => process.argv.includes(name) ? process.argv[process.argv.indexOf(name)+1] : fallback;
const { chromium } = require(arg('--playwright','playwright-core'));
const root = path.resolve(import.meta.dirname,'../..');
const godot = arg('--godot','/Applications/Godot.app/Contents/MacOS/Godot');
const port = arg('--port','8882');
const out = path.resolve(arg('--out','/tmp/debt-project-smoke'));
fs.mkdirSync(out,{recursive:true});
const file = path.join(root,'data/phase3_story.json');
const original = fs.readFileSync(file);
const mode = fs.statSync(file).mode;
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const ownedHashes = new Set([hash(original)]);
const environment = {...process.env};
assert.ok(environment.GODOT_LOCK,'set GODOT_LOCK for coordinated live-project tests');
const server = spawn('python3',[path.join(import.meta.dirname,'project_server.py'),'--port',port,'--godot',godot],{env:environment,stdio:['ignore','pipe','pipe']});
let serverLog='';server.stdout.on('data',b=>serverLog+=b);server.stderr.on('data',b=>serverLog+=b);
let browser;
const gameCheck = script => {
  const run=spawnSync('python3',[path.join(import.meta.dirname,'run_coordinated.py'),godot,'--headless','--path',root,'--script',script],{env:environment,encoding:'utf8',timeout:180000});
  fs.writeFileSync(path.join(out,path.basename(script)+'.log'),(run.stdout||'')+(run.stderr||''));
  assert.equal(run.status,0,(run.stdout||'')+(run.stderr||''));return run.stdout;
};
try {
  for(let i=0;;i++) {
    try {const r=await fetch(`http://127.0.0.1:${port}/api/capabilities`);if(r.ok&&serverLog.includes('Story editor:'))break;}catch{}
    assert.ok(server.exitCode===null&&i<80,'server did not start: '+serverLog);await new Promise(r=>setTimeout(r,100));
  }
  browser=await chromium.launch({headless:true,executablePath:arg('--chromium',undefined)});
  const page=await browser.newPage({viewport:{width:1600,height:1000}});page.setDefaultTimeout(30000);const errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('dialog',d=>d.accept());
  await page.goto(`http://127.0.0.1:${port}/tools/story_editor/?story=phase3`);
  await page.waitForFunction(()=>window.StoryEditor?.story&&StoryEditor.state.service&&StoryEditor.projectSource.ready);
  assert.equal(await page.locator('#btnProjectSave').isVisible(),true);
  const id=await page.evaluate(()=>StoryEditor.story.entry);
  await page.evaluate(id=>{StoryEditor.centerOn(id,.9);StoryEditor.select({type:'node',id});},id);
  const index=await page.evaluate(id=>StoryEditor.story.nodes[id].steps.findIndex(s=>s.op==='say'),id);
  const input=()=>page.locator(`#inspector [data-step="${index}"] textarea`).first();
  const firstLine='本機服務驗證並存檔的測試台詞。';
  await input().fill(firstLine);
  const savedResponse=page.waitForResponse(r=>r.url().endsWith('/api/save'),{timeout:150000});
  await page.locator('#btnProjectSave').click();const response=await savedResponse;
  const result=await response.json();assert.equal(response.status(),200,result.error);ownedHashes.add(result.hash);
  await page.waitForFunction(()=>!StoryEditor.state.dirty);
  let written=fs.readFileSync(file);assert.equal(hash(written),result.hash);
  assert.equal(JSON.parse(written).nodes[id].steps[index].text,firstLine);
  assert.match(JSON.parse(written).version,/^s-[a-f0-9]{12}$/);
  await page.locator('#banner').scrollIntoViewIfNeeded();
  await page.screenshot({path:path.join(out,'save-success.png')});
  assert.match(gameCheck('res://tests/test_phase3_story.gd'),/PHASE 3 STORY TESTS PASSED/);
  const checked=spawnSync('python3',[path.join(import.meta.dirname,'run_coordinated.py'),godot,'--headless','--path',root,'--script','res://tools/story_editor/check_story.gd','--',file],{env:environment,encoding:'utf8',timeout:180000});
  fs.writeFileSync(path.join(out,'phase3-check.log'),(checked.stdout||'')+(checked.stderr||''));
  assert.equal(checked.status,0,checked.stdout+checked.stderr);assert.match(checked.stdout,/OK /);
  console.log('ok  real phase3 editor save -> disk/version -> check_story OK -> PHASE 3 STORY TESTS PASSED');

  // Delay a successful response while the author keeps typing: baseline must advance, newer edits stay dirty.
  let release, arrived;const gate=new Promise(r=>release=r);const seen=new Promise(r=>arrived=r);
  await page.route('**/api/save',async route=>{const r=await route.fetch();const value=await r.json();if(r.ok())ownedHashes.add(value.hash);arrived();await gate;await route.fulfill({response:r});});
  await input().fill('送出驗證時的版本。');
  await page.locator('#btnProjectSave').click();await seen;
  await input().fill('等待驗證時繼續寫的版本。');release();
  await page.waitForFunction(()=>!document.querySelector('#btnProjectSave').disabled);
  assert.equal(await page.evaluate(()=>StoryEditor.state.dirty),true);
  assert.equal(await input().inputValue(),'等待驗證時繼續寫的版本。');
  await page.unroute('**/api/save');
  const secondResponse=page.waitForResponse(r=>r.url().endsWith('/api/save'),{timeout:150000});await page.locator('#btnProjectSave').click();
  const second=await secondResponse;const secondValue=await second.json();assert.equal(second.status(),200,secondValue.error);ownedHashes.add(secondValue.hash);
  await page.waitForFunction(()=>!StoryEditor.state.dirty);
  console.log('ok  edits during in-flight save remain dirty, then save with the advanced disk baseline');

  // Backend errors appear in the problem list and leave dirty data intact.
  await page.route('**/api/save',route=>route.fulfill({status:422,contentType:'application/json',body:JSON.stringify({error:'驗證未通過',errors:["ERROR node 'phase3_open' step 0: missing asset"]})}));
  await input().fill('驗證錯誤仍保留的台詞。');await page.locator('#btnProjectSave').click();
  await page.waitForFunction(()=>document.querySelector('#problems').textContent.includes('missing asset'));
  assert.equal(await page.evaluate(()=>StoryEditor.state.dirty),true);
  assert.equal(await input().inputValue(),'驗證錯誤仍保留的台詞。');await page.unroute('**/api/save');

  // A separate file editor changes disk bytes; stale browser hash must prevent overwriting.
  const external=Buffer.concat([fs.readFileSync(file),Buffer.from('\n')]);
  fs.writeFileSync(file,external);ownedHashes.add(hash(external));
  await input().fill('衝突時仍保留的台詞。');await page.locator('#btnProjectSave').click();
  await page.waitForFunction(()=>document.querySelector('#banner').textContent.includes('磁碟檔案已變更'));
  assert.equal(await page.evaluate(()=>StoryEditor.state.dirty),true);
  assert.deepEqual(fs.readFileSync(file),external);
  await page.evaluate(()=>{document.getElementById('infoBox').open=false;});
  await page.locator('#banner').scrollIntoViewIfNeeded();await page.screenshot({path:path.join(out,'save-conflict.png')});
  await page.reload();await page.waitForFunction(()=>window.StoryEditor?.story);
  await page.getByRole('button',{name:'復原草稿',exact:true}).click();
  await page.evaluate(id=>StoryEditor.select({type:'node',id}),id);
  assert.equal(await input().inputValue(),'衝突時仍保留的台詞。');
  await page.locator('#btnProjectSave').click();
  await page.waitForFunction(()=>document.querySelector('#banner').textContent.includes('磁碟檔案已變更'));
  assert.deepEqual(fs.readFileSync(file),external,'restored draft retains original conflict baseline');
  assert.deepEqual(errors,[]);
  console.log('ok  validation errors in problem list; disk conflict rejects writes; draft recovery preserves the stale baseline');
} finally {
  await browser?.close();server.kill();
  if(server.exitCode===null)await new Promise(resolve=>server.once('exit',resolve));
  fs.writeFileSync(path.join(out,'server.log'),serverLog);
  const current=fs.readFileSync(file);
  if(!ownedHashes.has(hash(current)))throw new Error('phase3 changed outside this test; preserving unexpected bytes instead of overwriting them');
  const restore=file+'.codex-restore.tmp';fs.writeFileSync(restore,original,{mode});fs.renameSync(restore,file);
  assert.deepEqual(fs.readFileSync(file),original);
  const diff=spawnSync('git',['diff','--','prototypes/debt-commission/data/phase3_story.json'],{cwd:path.resolve(root,'../..'),encoding:'utf8'});
  fs.writeFileSync(path.join(out,'phase3-restored.diff'),diff.stdout);
  assert.equal(diff.stdout,'','phase3 must be restored byte-for-byte');
  console.log('ok  phase3 restored byte-for-byte; git diff is empty');
}
console.log('PROJECT SMOKE PASSED');
