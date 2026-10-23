import {createRequire} from 'node:module';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url);
const arg=(n,d)=>process.argv.includes(n)?process.argv[process.argv.indexOf(n)+1]:d;
const {chromium}=require(arg('--playwright','@playwright/test'));
const out=arg('--out','/tmp/cde-web');await fs.mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--enable-webgl','--ignore-gpu-blocklist','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const report=[];
try{await Promise.all([{width:390,height:844},{width:320,height:568}].map(async viewport=>{
 const context=await browser.newContext({viewport,hasTouch:true,isMobile:true,deviceScaleFactor:1});const page=await context.newPage();const errors=[];
 const logs=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>logs.push(m.type()+': '+m.text().slice(0,300)));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:/.test(m.text()))errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.__debtQA);
 const wait=(fn,arg,t=30000)=>page.waitForFunction(fn,arg,{timeout:t});
 const point=async(r,s)=>{const c=await page.locator('canvas').boundingBox();return{x:c.x+(r.x+r.width/2)/s.viewport.width*c.width,y:c.y+(r.y+r.height/2)/s.viewport.height*c.height};};
 const clickRect=async(r,s,delay=100)=>{const p=await point(r,s);await page.touchscreen.tap(p.x,p.y);await page.waitForTimeout(delay);};
 const scroll=async(delta)=>{await page.mouse.move(viewport.width*.5,viewport.height*.52);await page.mouse.wheel(0,delta);await page.waitForTimeout(120);};
 const tap=async(name)=>{let s=await state();for(let i=0;!s.controls[name]&&i<24;i++){await scroll(i<12?220:-220);s=await state();}assert.ok(s.controls[name],`${name} unavailable at ${s.screen}; ${Object.keys(s.controls)}`);await clickRect(s.controls[name],s);};
 // Tap again when the screen did not change: a tap can land while a panel is still springing in.
 const tapTo=async(name,screen)=>{for(let i=0;i<4;i++){await wait(()=>window.__debtQA?.screen!=='busy');await tap(name);try{await wait(v=>window.__debtQA?.screen===v,screen,4000);return;}catch(e){if(i===3)throw e;}}};
 const menu=async()=>{await tap('menu');await wait(()=>window.__debtQA?.screen==='menu');};
 const readTo=async(predicate,label)=>{for(let i=0;i<220;i++){
  await wait(()=>window.__debtQA&&(window.__debtQA.comedy?.active||['story','investigate','boke_round','tsukkomi','qte','choice','result','end'].includes(window.__debtQA.screen)));
  const s=await state();if(predicate(s))return s;
  if(s.comedy?.active){await wait(()=>!window.__debtQA?.comedy?.active,null,10000);continue;}
  assert.equal(s.screen,'story',`${label} blocked at ${s.screen} ${s.node_id}`);
  await tap('stage');
 }throw Error(`did not reach ${label}`);};
 await page.goto(arg('--url','http://127.0.0.1:5194/')+'?qa=1&sample=chapter1');await wait(()=>window.__debtQA?.screen==='title',null,120000);
 assert.equal((await state()).ui_style,'gintama');await tap('begin');await wait(()=>window.__debtQA?.screen==='story');await tap('stage');
 const first=await state();await menu();await tap('menu_quick_save');await tap('menu_close');await wait(()=>window.__debtQA?.screen==='story');
 await tap('stage');await wait(s=>window.__debtQA?.source_id!==s,first.source_id);await tap('stage');
 await menu();await tap('menu_rollback');await wait(s=>window.__debtQA?.source_id===s,first.source_id);
 await tap('stage');await menu();await tap('menu_quick_load');await wait(s=>window.__debtQA?.source_id===s,first.source_id);
 await menu();await tap('menu_settings');await wait(()=>window.__debtQA?.screen==='settings');
 await tap('setting_font_size_2');await tap('setting_paper_opacity_0');await wait(()=>window.__debtQA?.settings?.font_size===2&&window.__debtQA.settings.paper_opacity===0,null,10000);let s=await state();assert.equal(s.settings.font_size,2);assert.equal(s.settings.paper_opacity,0);
 await page.screenshot({path:`${out}/${viewport.width}-settings.png`});await tap('settings_close');await wait(()=>window.__debtQA?.screen==='menu');await tap('menu_close');
 await menu();await tapTo('menu_save','save_slots');await tapTo('slot_1','menu');await tapTo('menu_save','save_slots');await tapTo('slot_1','slot_confirm');
 await tap('slot_confirm_no');await tap('slot_next');assert.equal((await state()).slot_page,1);await tap('slot_prev');await page.screenshot({path:`${out}/${viewport.width}-save.png`});await tap('slot_close');await tap('menu_close');
 await tap('log');await wait(()=>window.__debtQA?.screen==='log');await tap('log_close');
 console.log(`PASS convenience ${viewport.width}`);
 // Restore standard typography for the full chapter's screen acceptance.
 await menu();await tap('menu_settings');await tap('setting_font_size_1');await tap('setting_paper_opacity_2');await tap('settings_close');await tap('menu_close');
 await tap('skip');await wait(()=>window.__debtQA?.screen==='investigate',null,30000);
 await page.screenshot({path:`${out}/${viewport.width}-investigation.png`});
 await tap('move_kitchen');await wait(()=>window.__debtQA?.phase3?.investigation?.place==='kitchen');s=await state();assert.ok(!s.sprites.gintoki.visible&&!s.sprites.kagura.visible,'living-room cast stays off the kitchen stage');
 let spot=s.phase3.hotspots.find(x=>x.id==='ch1_fridge');await tap('investigate_collapse');s=await state();spot=s.phase3.hotspots.find(x=>x.id==='ch1_fridge');await clickRect(spot.rect,s);await readTo(s=>s.screen==='investigate','kitchen return');
 assert.equal((await state()).phase3.investigation.place,'home');assert.ok((await state()).sprites.gintoki.visible,'home cast returns');
 for(const id of ['gintoki_mouth','desk_underside','sofa_underside','floor_prints']){
  s=await state();if(!s.phase3.investigate_collapsed)await tap('investigate_collapse');
  for(let i=0;i<12;i++){
   s=await state();spot=s.phase3.hotspots.find(x=>x.id===id);
   if(spot.rect?.width>0)break;
   const c=await page.locator('canvas').boundingBox();const x=(spot.screen_rect.x+spot.screen_rect.width/2-s.game.x-s.game.width*.5)/s.viewport.width*c.width;
   await page.mouse.move(viewport.width*.5,viewport.height*.32);await page.mouse.down();await page.mouse.move(viewport.width*.5-x,viewport.height*.32,{steps:8});await page.mouse.up();await page.waitForTimeout(150);
  }
  assert.ok(spot.rect?.width>0,`${id} is reachable`);await fs.writeFile(`${out}/${viewport.width}-${id}.json`,JSON.stringify(s,null,2));await page.screenshot({path:`${out}/${viewport.width}-${id}.png`});await clickRect(spot.rect,s);await wait(()=>window.__debtQA?.screen==='story');await readTo(s=>s.screen==='investigate',id+' reaction');console.log(id,JSON.stringify((await state()).phase3.investigation));
 }
 await fs.writeFile(`${out}/${viewport.width}-clues.json`,JSON.stringify(await state(),null,2));console.log(`PASS clues ${viewport.width}`);assert.equal((await state()).phase3.investigation.complete,true);if((await state()).phase3.investigate_collapsed)await tap('investigate_expand');await tap('investigate_continue');
 await readTo(s=>s.screen==='boke_round','round one');
 const finishRoundText=async()=>{const s=await state();if(!s.text_complete){await tap('stage');await wait(()=>window.__debtQA?.text_complete);} };
 await finishRoundText();await tap('boke_listen');await readTo(s=>s.screen==='boke_round','listening return');
 assert.ok((await state()).items.includes('gin_sleep_testimony'));
 const next=async(index)=>{for(let n=0;n<5&&(await state()).phase3.boke_line_index!==index;n++)await tap((await state()).phase3.boke_line_index<index?'boke_next':'boke_previous');await finishRoundText();};
 const answer=async(index,id)=>{await next(index);await tap('boke_tsukkomi');await wait(()=>window.__debtQA?.screen==='tsukkomi');const v=await state();const choice=v.choices.find(x=>x.id===id);assert.ok(choice,`option ${id}`);await clickRect(choice.rect,v);await readTo(s=>s.screen==='boke_round'||s.screen==='tsukkomi','reply return');};
 await answer(1,'a');await answer(3,'a');assert.equal((await state()).node_id,'ch1_r2_kagura');
 await answer(0,'a');await next(1);await page.screenshot({path:`${out}/${viewport.width}-placard.png`});await tap('placard');await readTo(s=>s.screen==='boke_round','placard return');console.log(`PASS placard ${viewport.width}`);await answer(2,'a');
 await readTo(s=>s.screen==='boke_round'||s.screen==='tsukkomi','combo');
 if(!(await state()).text_complete)await tap('stage');await wait(()=>window.__debtQA?.screen==='tsukkomi');await page.screenshot({path:`${out}/${viewport.width}-super.png`});await tap('super');
 await readTo(s=>s.node_id==='ch1_r3_combo'&&s.phase3.boke_line_index===4,'C5');s=await state();assert.ok(!s.phase3.round.qte_active&&!s.text_complete,'QTE waits until its sentence is readable');
 // Finish the C5 sentence, then tap early: real timing failure returns to C5 without ending the chapter.
 await tap('stage');await wait(()=>window.__debtQA?.phase3.round.qte_active);await tap('qte');
 await readTo(s=>s.node_id==='ch1_r3_combo'&&s.phase3.boke_line_index===4,'retry QTE');
 // Let the ring run out once: a late QTE also returns to C5.
 if(!(await state()).text_complete)await tap('stage');
 await wait(()=>window.__debtQA?.phase3.round.qte_active);await wait(()=>!window.__debtQA?.phase3.round.qte_active,null,10000);
 assert.ok((await state()).phase3.round.last_qte_offset>0,'late QTE judged late');
 await readTo(s=>s.node_id==='ch1_r3_combo'&&s.phase3.boke_line_index===4,'retry late QTE');
 // Aim at the moment the rings meet (browser clock from QA), a little early to cover one frame of input latency.
 const qteOffsets=[];
 for(let attempt=0;attempt<3;attempt++){
  if(!(await state()).text_complete)await tap('stage');
  await wait(()=>window.__debtQA?.phase3.round.qte_active);s=await state();
  const meet=s.phase3.round.qte_meet_ms;const p=await point(s.controls.qte,s);
  await page.waitForTimeout(Math.max(0,meet-Date.now()-40));await page.touchscreen.tap(p.x,p.y);
  await wait(()=>window.__debtQA?.screen!=='qte');s=await state();qteOffsets.push(+s.phase3.round.last_qte_offset.toFixed(3));
  if(Math.abs(s.phase3.round.last_qte_offset)<=0.12)break;
  await readTo(s=>s.node_id==='ch1_r3_combo'&&s.phase3.boke_line_index===4,'retry missed QTE');
 }
 console.log(`QTE offsets ${viewport.width}: ${qteOffsets.join(', ')}`);
 s=await readTo(s=>s.screen==='choice','fetch choice');const self=s.choices.find(x=>x.id==='fetch_self');assert.ok(self,'fetch_self option');await clickRect(self.rect,s);await readTo(s=>s.screen==='result','chapter result');
 s=await state();const grades={5:'S',4:'A',3:'B',2:'B',1:'C'};assert.equal(s.result.grade,grades[s.phase3.gameplay.glasses],`grade for ${s.phase3.gameplay.glasses} glasses`);assert.ok(s.items.includes('salary_envelope'));await page.screenshot({path:`${out}/${viewport.width}-result.png`});const grade=s.result.grade;
 // Progress survives a reload: chapter select shows the best grade and the ending.
 await tap('result_title');await wait(()=>window.__debtQA?.screen==='title');assert.equal((await state()).cleared.find(x=>x.id==='chapter1').grade,grade,'best grade recorded');// Reload only once the grade is in IndexedDB: Godot syncs user:// there a frame or more after the write.
 const storedGrade=g=>page.evaluate(async(g)=>{const db=await new Promise((ok,no)=>{const r=indexedDB.open('/userfs');r.onsuccess=()=>ok(r.result);r.onerror=no;});
  const rows=await new Promise(ok=>{const out=[];const c=db.transaction('FILE_DATA').objectStore('FILE_DATA').openCursor();c.onsuccess=e=>{const k=e.target.result;if(!k)return ok(out);if(String(k.key).endsWith('/progress.cfg'))out.push(new TextDecoder().decode(k.value.contents));k.continue();};});
  db.close();return rows.some(t=>t.includes(`chapter1="${g}"`));},g);
 let stored=false;for(let i=0;i<40&&!stored;i++){stored=await storedGrade(grade);if(!stored)await page.waitForTimeout(500);}
 if(!stored){const keys=await page.evaluate(async()=>{const db=await new Promise(ok=>{const r=indexedDB.open('/userfs');r.onsuccess=()=>ok(r.result);});return await new Promise(ok=>{const out=[];const c=db.transaction('FILE_DATA').objectStore('FILE_DATA').openCursor();c.onsuccess=e=>{const k=e.target.result;if(!k)return ok(out);if(!String(k.key).includes('shader_cache'))out.push(String(k.key)+' '+new Date(k.value.timestamp).toISOString().slice(11,23)+(String(k.key).endsWith('.cfg')?' '+new TextDecoder().decode(k.value.contents).replace(/\n/g,' | '):''));k.continue();};});});
  await fs.writeFile(`${out}/${viewport.width}-idb-failure.json`,JSON.stringify({keys,errors,logs,now:new Date().toISOString()},null,1));}
 assert.ok(stored,'progress.cfg with the grade reached IndexedDB before reload');
 await page.reload();await wait(()=>window.__debtQA?.screen==='title',null,120000);
 const ch=(await state()).cleared.find(x=>x.id==='chapter1');assert.equal(ch.grade,grade,'best grade kept after reload');assert.ok(ch.endings.length>0,'ending count kept after reload');
 assert.deepEqual(errors,[]);
 report.push({viewport,grade,qte_offsets:qteOffsets,checks:['default gintama','quick save/load','rollback','scrolling typography settings','save slots and overwrite','LOG return','kitchen cast','four clue hotspots with pan','listening material','three rounds','placard','super','C5 text before QTE','early and late QTE retry','timed perfect QTE','salary twist, fetch choice and result','grade from glasses','progress after reload'],errors});console.log(`PASS reading/chapter ${viewport.width}`);await context.close();
}));await fs.writeFile(`${out}/report.json`,JSON.stringify(report,null,2));}finally{await browser.close();}
