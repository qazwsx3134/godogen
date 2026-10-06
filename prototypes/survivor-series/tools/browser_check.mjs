import {createRequire} from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
const args = process.argv.slice(2);
const arg = (key, fallback) => args.includes(key) ? args[args.indexOf(key)+1] : fallback;
const {chromium} = createRequire(import.meta.url)(arg('--playwright','playwright-core'));
const out = arg('--out','/tmp/survivor-browser');
fs.mkdirSync(out,{recursive:true});
const browser = await chromium.launch({headless:true,executablePath:arg('--chromium',undefined),args:['--enable-webgl','--ignore-gpu-blocklist','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const errors=[];
const report={mode:args.includes("--visual-only")?"visual-only":"full-90-seconds",checks:[],audio:[],snapshots:{}};
const expect=(ok,label)=>{if(!ok)throw new Error(label);report.checks.push(label);console.log('PASS '+label);};
try {
 const ctx = await browser.newContext({viewport:{width:390,height:844},hasTouch:true,isMobile:true,deviceScaleFactor:1});
 await ctx.addInitScript(()=>{
  window.__audioContexts=[];
  const Native=window.AudioContext||window.webkitAudioContext;
  if(Native){const Tracked=new Proxy(Native,{construct(Target,args){const instance=new Target(...args);window.__audioContexts.push(instance);return instance;}});window.AudioContext=Tracked;if(window.webkitAudioContext)window.webkitAudioContext=Tracked;}
 });
 const page=await ctx.newPage();
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|Parse Error|missing glyph/.test(m.text()))errors.push(m.text());});
 page.on('requestfailed',r=>errors.push(r.url()+': '+r.failure()?.errorText));
 await page.goto(arg('--url','http://127.0.0.1:8793/index.html'),{waitUntil:'load',timeout:60000});
 await page.waitForFunction(()=>window.__survivorTelemetry?.state==='MENU',{},{timeout:60000});
 await page.screenshot({path:path.join(out,'phone-menu.png')});
 const click=async name=>{
  const layout=await page.evaluate(()=>window.__survivorLayout);
  const box=await page.locator('canvas').boundingBox();
  const r=layout[name];
  await page.touchscreen.tap(box.x+(r[0]+r[2]/2)/layout.viewport[0]*box.width,box.y+(r[1]+r[3]/2)/layout.viewport[1]*box.height);
 };
 await click('start');
 await page.waitForFunction(()=>window.__survivorTelemetry?.state==='RUNNING',{},{timeout:10000});
 expect(true,'real touch starts the game');
 await page.waitForTimeout(1800);
 report.audio=await page.evaluate(()=>window.__audioContexts.map(c=>c.state));
 expect(report.audio.includes('running'),'audio context unlocked by the start gesture');
 const before=await page.evaluate(()=>window.__survivorTelemetry);
 const cdp=await ctx.newCDPSession(page);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:180,y:580,id:1}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:250,y:600,id:1}]});
 await page.waitForTimeout(800);
 const moved=await page.evaluate(()=>window.__survivorTelemetry);
 expect(Math.hypot(moved.player[0]-before.player[0],moved.player[1]-before.player[1])>15,'real touch drag moves the hero');
 expect(Math.hypot(...moved.stick)>0.1,'floating stick receives touch-to-mouse input');
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await page.waitForTimeout(500);
 expect((await page.evaluate(()=>window.__survivorTelemetry.stick)).every(v=>v===0),'touch release clears movement');
 await page.waitForFunction(()=>window.__survivorTelemetry.state==='UPGRADE',{},{timeout:40000});
 const first=await page.evaluate(()=>window.__survivorTelemetry);
 expect(JSON.stringify(first.offers)==='["wave","kick","sweep"]','first level presents three distinct attack modes');
 await page.screenshot({path:path.join(out,'phone-upgrades.png')});
 const choose=async()=>{
  const state=await page.evaluate(()=>window.__survivorTelemetry);
  const layout=await page.evaluate(()=>window.__survivorLayout);
  const box=await page.locator('canvas').boundingBox();
  const index=state.offers.includes('wave')?state.offers.indexOf('wave'):state.offers.includes('kick')?state.offers.indexOf('kick'):0;
  const r=layout.cards[index];
  await page.touchscreen.tap(box.x+(r[0]+r[2]/2)/layout.viewport[0]*box.width,box.y+(r[1]+r[3]/2)/layout.viewport[1]*box.height);
  await page.waitForTimeout(400);
 };
 await page.waitForTimeout(800);
 expect((await page.evaluate(()=>window.__survivorTelemetry.elapsed))===first.elapsed,'upgrade choice freezes game time');
 await choose();
 await page.waitForFunction(()=>window.__survivorTelemetry.state==='RUNNING');
 expect((await page.evaluate(()=>window.__survivorTelemetry.stacks.wave))===1,'real touch selects and unlocks shockwave');
 const beforeAgain=await page.evaluate(()=>window.__survivorTelemetry.player);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:160,y:580,id:2}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:230,y:580,id:2}]});
 await page.waitForTimeout(500);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await page.waitForTimeout(300);
 const afterAgain=await page.evaluate(()=>window.__survivorTelemetry.player);
 expect(Math.hypot(afterAgain[0]-beforeAgain[0],afterAgain[1]-beforeAgain[1])>10,'touch movement resumes after selecting an upgrade');
 const waitForWave=Date.now();
 while((await page.evaluate(()=>window.__survivorTelemetry.waves_fired))<1){
  if((await page.evaluate(()=>window.__survivorTelemetry.state))==='UPGRADE')await choose();
  if(Date.now()-waitForWave>30000)throw new Error('unlocked wave did not fire');
  await page.waitForTimeout(500);
 }
 expect(true,'unlocked shockwave fires in the Web build');
 await page.screenshot({path:path.join(out,'phone-combat.png')});
 report.snapshots.combat=await page.evaluate(()=>window.__survivorTelemetry);
 expect(report.snapshots.combat.punches>0&&report.snapshots.combat.sounds.launch>0,'auto punch, lethal launch and audio occur in Web build');
 await click('pause');
 await page.waitForFunction(()=>window.__survivorTelemetry.state==='PAUSED');
 const paused=await page.evaluate(()=>window.__survivorTelemetry.elapsed);
 await page.waitForTimeout(800);
 expect((await page.evaluate(()=>window.__survivorTelemetry.elapsed))===paused,'HUD pause stops game time');
 await click('resume');
 await page.waitForFunction(()=>window.__survivorTelemetry.state==='RUNNING');
 expect(true,'touch resumes the paused game');
 if(!args.includes("--visual-only")){
 let last=Date.now();
 while((await page.evaluate(()=>window.__survivorTelemetry.state))!=='RESULTS'){
  await page.waitForTimeout(1500);
  if((await page.evaluate(()=>window.__survivorTelemetry.state))==='UPGRADE')await choose();
  const s=await page.evaluate(()=>window.__survivorTelemetry);
  expect(s.living<=22&&s.effects<=24&&s.hazards<=18&&s.waves<=12,'runtime object budgets hold');
  if(Date.now()-last>180000)throw new Error('90-second run did not finish');
  console.log('game time '+s.elapsed.toFixed(1));
 }
 report.snapshots.results=await page.evaluate(()=>window.__survivorTelemetry);
 expect(report.snapshots.results.level>1&&report.snapshots.results.waves_fired>0,'full run includes growth and alternate attacks');
 await page.screenshot({path:path.join(out,'phone-results.png')});
 expect(report.snapshots.results.elapsed===90&&report.snapshots.results.actors===0&&report.snapshots.results.hazards===0,'full 90-second Web run concludes and cleans the arena');
 await click('retry');
 await page.waitForFunction(()=>window.__survivorTelemetry.state==='RUNNING'&&window.__survivorTelemetry.elapsed<2);
 report.snapshots.retry=await page.evaluate(()=>window.__survivorTelemetry);
 expect(report.snapshots.retry.kills===0&&report.snapshots.retry.level===1&&Object.keys(report.snapshots.retry.stacks).length===0,'real touch retries with reset score and build');
 }
 expect(errors.length===0,'no browser, load or Godot script errors');
 await ctx.close();
 const desktop=await browser.newContext({viewport:{width:540,height:960}});
 const desk=await desktop.newPage();
 desk.on('pageerror',e=>errors.push(e.message));
 await desk.goto(arg('--url','http://127.0.0.1:8793/index.html'));
 await desk.waitForFunction(()=>window.__survivorTelemetry?.state==='MENU',{},{timeout:60000});
 await desk.screenshot({path:path.join(out,'desktop-menu.png')});
 expect(true,'desktop browser loads the same portrait game');
 await desktop.close();
 report.errors=errors;
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
 console.log('BROWSER CHECK PASSED');
} catch(e){report.errors=errors;report.failure=e.message;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));throw e;}
finally{await browser.close();}
