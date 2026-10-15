// Phone-shaped browser check of the Web QA build (build/qa), driven by real touch input.
//   python3 -m http.server 8793 -d prototypes/survivor-series/build/qa &
//   node tools/browser_check.mjs [--url http://127.0.0.1:8793/index.html] [--duration 25] [--out dir]
//        [--playwright <path to playwright-core>] [--chromium <chrome binary>]
//        [--production-url http://127.0.0.1:8793/web/index.html]
// A run is shortened with index.html?duration=N (only the Web QA preset accepts it). Covers: menu, touch start and
// drag, level-up cards, pause, a full run to the results, retry, home, shop, and coins surviving a page reload (IDBFS).
import {createRequire} from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
const args = process.argv.slice(2);
const arg = (key, fallback) => args.includes(key) ? args[args.indexOf(key)+1] : fallback;
const {chromium} = createRequire(import.meta.url)(arg('--playwright','playwright-core'));
const out = arg('--out','/tmp/survivor-browser');
const duration = Number(arg('--duration','25'));
const withDuration=value=>{const u=new URL(value);u.searchParams.set('duration',String(duration));return u.href;};
const url=withDuration(arg('--url','http://127.0.0.1:8793/index.html'));
const productionUrl=arg('--production-url',null);
fs.mkdirSync(out,{recursive:true});
const browser = await chromium.launch({headless:true,executablePath:arg('--chromium',undefined),args:['--enable-webgl','--ignore-gpu-blocklist','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const errors=[];
const report={duration,checks:[],audio:[],snapshots:{}};
const expect=(ok,label)=>{if(!ok)throw new Error(label);report.checks.push(label);console.log('PASS '+label);};
const watch=page=>{
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|Parse Error|missing glyph/.test(m.text()))errors.push(m.text());});
 page.on('requestfailed',r=>errors.push(r.url()+': '+r.failure()?.errorText));
};
try {
 const ctx = await browser.newContext({viewport:{width:390,height:844},hasTouch:true,isMobile:true,deviceScaleFactor:1});
 await ctx.addInitScript(()=>{
  window.__audioContexts=[];
  const Native=window.AudioContext||window.webkitAudioContext;
  if(Native){const Tracked=new Proxy(Native,{construct(Target,args){const instance=new Target(...args);window.__audioContexts.push(instance);return instance;}});window.AudioContext=Tracked;if(window.webkitAudioContext)window.webkitAudioContext=Tracked;}
 });
 const page=await ctx.newPage();
 watch(page);
 const tel=()=>page.evaluate(()=>window.__survivorTelemetry);
 const until=(state,timeout=15000)=>page.waitForFunction(s=>window.__survivorTelemetry?.state===s,state,{timeout});
 const tapRect=async r=>{
  const layout=await page.evaluate(()=>window.__survivorLayout);
  const box=await page.locator('canvas').boundingBox();
  await page.touchscreen.tap(box.x+(r[0]+r[2]/2)/layout.viewport[0]*box.width,box.y+(r[1]+r[3]/2)/layout.viewport[1]*box.height);
 };
 const click=async name=>{await page.waitForTimeout(300);await tapRect((await page.evaluate(()=>window.__survivorLayout))[name]);};
 const choose=async()=>{await page.waitForTimeout(400);await tapRect((await page.evaluate(()=>window.__survivorLayout)).cards[0]);await page.waitForTimeout(400);};
 let productionBefore;
 if(productionUrl){
  await page.goto(withDuration(productionUrl),{waitUntil:'load',timeout:60000});
  await until('MENU',60000);
  productionBefore=report.snapshots.productionBefore=await tel();
  expect(!productionBefore.qa&&productionBefore.session_duration===600,'production ignores the short-run query');
  expect(productionBefore.save_path==='user://survivor_meta.json','production uses its own progress file');
 }
 await page.goto(url,{waitUntil:'load',timeout:60000});
 await until('MENU',60000);
 await page.screenshot({path:path.join(out,'phone-menu.png')});
 const menuState=await tel();
 expect(menuState.qa&&menuState.session_duration===duration,'QA feature enables the short run');
 expect(menuState.save_path==='user://survivor_meta_qa.json','QA progress is isolated from production');
 const coinsBefore=menuState.coins;
 await click('start');
 await until('RUNNING',10000);
 expect(true,'real touch starts the game');
 await page.waitForTimeout(1500);
 report.audio=await page.evaluate(()=>window.__audioContexts.map(c=>c.state));
 expect(report.audio.includes('running'),'audio context unlocked by the start gesture');
 const before=await tel();
 const cdp=await ctx.newCDPSession(page);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:180,y:580,id:1}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:250,y:600,id:1}]});
 await page.waitForTimeout(800);
 const moved=await tel();
 expect(Math.hypot(moved.player[0]-before.player[0],moved.player[1]-before.player[1])>15,'real touch drag moves the hero');
 expect(Math.hypot(...moved.stick)>0.1,'floating stick receives touch input');
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await page.waitForTimeout(500);
 expect((await tel()).stick.every(v=>v===0),'touch release clears movement');
 await page.screenshot({path:path.join(out,'phone-combat.png')});
 await until('UPGRADE',duration*1000);
 const offer=await tel();
 expect(offer.offers.length>=1,'level-up shows cards');
 await page.screenshot({path:path.join(out,'phone-upgrades.png')});
 await page.waitForTimeout(800);
 expect((await tel()).elapsed===offer.elapsed,'upgrade choice freezes game time');
 const levelsBefore=JSON.stringify(offer.levels);
 await choose();
 while((await tel()).state==='UPGRADE')await choose();
 expect(JSON.stringify((await tel()).levels)!==levelsBefore,'real touch picks a card');
 const afterUpgrade=await tel();
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:180,y:580,id:2}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:250,y:600,id:2}]});
 await page.waitForTimeout(500);
 const afterDrag=await tel();
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 expect(Math.hypot(afterDrag.player[0]-afterUpgrade.player[0],afterDrag.player[1]-afterUpgrade.player[1])>10,'movement still works after choosing an upgrade');

 await click('pause');
 await until('PAUSED');
 const paused=(await tel()).elapsed;
 await page.waitForTimeout(800);
 expect((await tel()).elapsed===paused,'HUD pause stops game time');
 await click('resume');
 await until('RUNNING');
 expect(true,'touch resumes the paused game');
 const started=Date.now();
 for(let s=await tel();s.state!=='RESULTS';s=await tel()){
  if(s.state==='UPGRADE')await choose();
  const fx=s.vfx;
  expect(s.living<=140&&s.hazards<=10&&fx.particles<=fx.limits.particles&&fx.shapes<=fx.limits.shapes&&fx.shaders<=fx.limits.shaders&&s.effects===fx.particles+fx.shapes+fx.shaders,'actual renderer budgets hold');
  if(Date.now()-started>duration*1000*6+60000)throw new Error('run did not finish');
  await page.waitForTimeout(1000);
 }
 const results=report.snapshots.results=await tel();
 await page.screenshot({path:path.join(out,'phone-results.png')});
 expect(results.coins>coinsBefore,'finished run banks coins');
 await click('retry');
 await page.waitForFunction(()=>window.__survivorTelemetry.state==='RUNNING'&&window.__survivorTelemetry.elapsed<2);
 const retry=await tel();
 expect(retry.kills===0&&retry.level===1,'real touch retries with reset score and build');
 await page.reload({waitUntil:'load'});
 await until('MENU',60000);
 expect((await tel()).coins===results.coins,'coins survive a page reload (IDBFS)');
 await click('shop');
 await until('SHOP');
 await page.screenshot({path:path.join(out,'phone-shop.png')});
 await click('shop_back');
 await until('MENU');
 expect(true,'shop opens and closes by touch');
 if(productionUrl){
  await page.goto(withDuration(productionUrl),{waitUntil:'load',timeout:60000});
  await until('MENU',60000);
  const productionAfter=report.snapshots.productionAfter=await tel();
  expect(productionAfter.coins===productionBefore.coins,'QA rewards never reach the production save');
  expect(!productionAfter.qa&&productionAfter.session_duration===600,'production stays full-length after a QA run');
 }
 expect(errors.length===0,'no browser, load or Godot script errors');
 await ctx.close();
 const desktop=await browser.newContext({viewport:{width:960,height:600}});
 const desk=await desktop.newPage();
 watch(desk);
 await desk.goto(url);
 await desk.waitForFunction(()=>window.__survivorTelemetry?.state==='MENU',{},{timeout:60000});
 await desk.screenshot({path:path.join(out,'desktop-menu.png')});
 expect(errors.length===0,'wide desktop browser loads the game');
 await desktop.close();
 report.errors=errors;
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
 console.log('BROWSER CHECK PASSED');
} catch(e){report.errors=errors;report.failure=e.message;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));throw e;}
finally{await browser.close();}
