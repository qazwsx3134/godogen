// 故事包 in the editor (served by project_server.py): works are listed under their titles, a work's
// story reads its own catalog (relative art, `extends`), saves go to its folder and pack.json, and
// 新作品 makes a folder whose first chapter saves and validates.
//   node tools/story_editor/pack_smoke.mjs --playwright <playwright-core> --chromium <Chrome> --out <dir>
import {createRequire} from 'node:module';
import {spawn} from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url);
const arg=(name,fallback)=>process.argv.includes(name)?process.argv[process.argv.indexOf(name)+1]:fallback;
const {chromium}=require(arg('--playwright','playwright-core'));
const root=path.resolve(import.meta.dirname,'../..');
const fixture=fs.mkdtempSync(path.join(os.tmpdir(),'debt-pack-editor-'));
const out=path.resolve(arg('--out','/tmp/debt-pack-smoke'));fs.mkdirSync(out,{recursive:true});
const port=arg('--port','8885');
const put=(relative,value)=>{const file=path.join(fixture,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,typeof value==='string'||Buffer.isBuffer(value)?value:JSON.stringify(value,null,2)+'\n');};
const copy=(relative,to=relative)=>put(to,fs.readFileSync(path.join(root,relative)));
const read=relative=>JSON.parse(fs.readFileSync(path.join(fixture,relative)));
for(const file of ['index.html','editor.js','editor_state.js','story_core.js','editor.css'])copy('tools/story_editor/'+file);
copy('scripts/story_runner.gd');copy('data/asset_catalog.json');
for(const id of ['gintama','example'])copy(`skins/${id}/skin.json`);
const story=(id,speaker)=>({id,version:'s-unset',title:'作品測試',entry:'start',initial_flags:{},nodes:{start:{title:'起點',steps:[{op:'say',speaker,text:'原文'},{op:'end',text:'完'}]}}});
put('data/graph_story.json',story('graph','shinpachi'));
put('data/stories.json',{stories:[{id:'graph',kind:'sample',path:'res://data/graph_story.json',save:'user://graph.save',authoring:'graph'}]});
put('stories/titan/pack.json',{id:'titan',title:'城牆',skin:'example',stories:[{id:'titan_ch1',kind:'chapter',path:'titan_ch1_story.json',authoring:'graph'}]});
copy('tests/fixtures/packs/titan/catalog.json','stories/titan/catalog.json');  // validated as that fixture
copy('tests/fixtures/packs/titan/art/wall.png','stories/titan/art/wall.png');
put('stories/titan/titan_ch1_story.json',story('titan_ch1','eren'));
const registryBefore=fs.readFileSync(path.join(fixture,'data/stories.json'));
const server=spawn('python3',[path.join(import.meta.dirname,'serve_editor_fixture.py'),'--root',fixture,'--port',port,'--godot',arg('--godot','/Applications/Godot.app/Contents/MacOS/Godot')],{env:process.env,stdio:['ignore','pipe','pipe']});
let log='';server.stdout.on('data',b=>log+=b);server.stderr.on('data',b=>log+=b);
let browser;
try{
 for(let i=0;;i++){if(log.includes('SKIN FIXTURE READY'))break;assert.ok(server.exitCode===null&&i<80,log);await new Promise(r=>setTimeout(r,100));}
 browser=await chromium.launch({headless:true,executablePath:arg('--chromium',undefined)});
 const context=await browser.newContext({viewport:{width:1600,height:1100}});const page=await context.newPage();
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const answers=[];page.on('dialog',d=>d.type()==='prompt'?d.accept(answers.shift()??''):d.accept());
 const base=`http://127.0.0.1:${port}/tools/story_editor/`;
 const ready=async()=>page.waitForFunction(()=>window.StoryEditor?.story&&StoryEditor.projectSource.ready);
 const save=async endpoint=>{const pending=page.waitForResponse(r=>r.url().endsWith(endpoint),{timeout:150000});await page.locator('#btnProjectSave').click();const r=await pending;const value=await r.json();assert.equal(r.status(),200,JSON.stringify(value));await page.waitForFunction(()=>!StoryEditor.state.dirty);return value;};

 await page.goto(base+'?story=titan_ch1');await ready();
 const state=()=>page.evaluate(()=>({path:StoryEditor.projectSource.path,cast:Object.keys(StoryEditor.state.catalog?.characters||{}),
   wall:StoryEditor.state.catalog?.backgrounds?.wall?.path,readOnly:StoryEditor.isReadOnly()}));
 let s=await state();
 assert.equal(s.path,'stories/titan/titan_ch1_story.json');
 assert.deepEqual(s.cast,['eren'],`only the work's characters: ${s.cast}`);
 assert.equal(s.wall,'res://stories/titan/art/wall.png');assert.equal(s.readOnly,false);
 assert.deepEqual(await page.locator('#storySelect optgroup').evaluateAll(g=>g.map(x=>[x.label,[...x.children].map(o=>o.value)])),[['作品：城牆',['titan_ch1']]]);
 assert.match(await page.locator('#storySkin option').first().innerText(),/預設：example（作品）/);
 console.log('ok  a work is listed under its title and its story reads the work catalog');

 await page.locator('#storyCover').selectOption('res://stories/titan/art/wall.png');
 await page.locator('#info .field').filter({hasText:'title'}).first().locator('input').fill('第一章・城牆');
 const saved=await save('/api/save');
 assert.equal(saved.owner,'stories/titan/pack.json');
 assert.equal(read('stories/titan/titan_ch1_story.json').title,'第一章・城牆');
 assert.equal(read('stories/titan/pack.json').stories[0].cover,'res://stories/titan/art/wall.png');
 assert.deepEqual(fs.readFileSync(path.join(fixture,'data/stories.json')),registryBefore,'data/stories.json untouched');
 console.log('ok  saving a work story validates against its catalog and writes its pack.json');

 answers.push('moon','月亮');
 await page.locator('#btnNewWork').click();
 await page.waitForFunction(()=>StoryEditor.projectSource.path==='stories/moon/moon_ch1_story.json');await ready();
 s=await state();assert.deepEqual(s.cast,['hero'],'a new work starts with its own 主角');
 assert.deepEqual(read('stories/moon/pack.json'),{id:'moon',title:'月亮',stories:[]});
 const first=await save('/api/save');
 assert.deepEqual(first.pack.stories,[{id:'moon_ch1',kind:'chapter',path:'moon_ch1_story.json',authoring:'graph'}]);
 assert.equal(read('stories/moon/moon_ch1_story.json').id,'moon_ch1');
 assert.deepEqual(await page.locator('#storySelect optgroup').evaluateAll(g=>g.map(x=>x.label)),['作品：月亮','作品：城牆'],'works by folder name, as in the game');
 await page.screenshot({path:out+'/new-work.png'});
 console.log('ok  新作品 makes stories/moon/ and its first chapter saves into pack.json');

 answers.push('moon','moon_ch2');
 await page.locator('#btnNewStory').click();
 await page.waitForFunction(()=>StoryEditor.projectSource.path==='stories/moon/moon_ch2_story.json');
 await save('/api/save');
 assert.deepEqual(read('stories/moon/pack.json').stories.map(e=>e.id),['moon_ch1','moon_ch2']);
 await page.locator('#storySelect').selectOption('graph');
 await page.waitForFunction(()=>StoryEditor.projectSource.path==='data/graph_story.json');
 s=await state();assert.ok(!s.cast.includes('eren')&&s.cast.includes('shinpachi'),'the game catalog again for data/');
 console.log('ok  新故事 into a work; data/ stories keep the game catalog');
 assert.deepEqual(errors,[]);console.log('PACK EDITOR SMOKE PASSED');
 await context.close();
}catch(error){if(browser){for(const c of browser.contexts())for(const p of c.pages())await p.screenshot({path:out+'/failure.png'}).catch(()=>{});}fs.writeFileSync(out+'/server.log',log);throw error;}
finally{await browser?.close();server.kill();if(server.exitCode===null)await new Promise(r=>server.once('exit',r));fs.rmSync(fixture,{recursive:true,force:true});}
