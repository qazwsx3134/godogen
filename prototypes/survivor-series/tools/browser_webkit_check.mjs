// Desktop WebKit compatibility check in a phone-shaped viewport; not physical iPhone validation.
// node tools/browser_webkit_check.mjs --url http://127.0.0.1:8795/qa/index.html
//   --playwright <playwright-core path> [--webkit <pw_run.sh path>] [--out directory]
import {createRequire} from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
const args=process.argv.slice(2);
const arg=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const {webkit}=createRequire(import.meta.url)(arg('--playwright','playwright-core'));
const out=arg('--out','/tmp/survivor-webkit');
const url=new URL(arg('--url','http://127.0.0.1:8795/qa/index.html'));
url.searchParams.set('duration','1');
fs.mkdirSync(out,{recursive:true});
const report={engine:'Desktop WebKit; 390x844 touch viewport; not a physical iPhone',checks:[],snapshots:{},errors:[]};
const expect=(ok,label)=>{if(!ok)throw new Error(label);report.checks.push(label);console.log('PASS '+label);};
const browser=await webkit.launch({headless:true,executablePath:arg('--webkit',undefined)});
try{
 const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true,isMobile:true,deviceScaleFactor:2});
 const page=await context.newPage();
 page.on('pageerror',e=>report.errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|Parse Error|missing glyph/.test(m.text()))report.errors.push(m.text());});
 page.on('requestfailed',r=>report.errors.push(r.url()+': '+r.failure()?.errorText));
 const telemetry=()=>page.evaluate(()=>window.__survivorTelemetry);
 const until=(state,timeout=15000)=>page.waitForFunction(s=>window.__survivorTelemetry?.state===s,state,{timeout});
 const tap=async name=>{
  await page.waitForTimeout(300);
  const layout=await page.evaluate(()=>window.__survivorLayout),rect=layout[name];
  const canvas=await page.locator('canvas').boundingBox();
  await page.touchscreen.tap(canvas.x+(rect[0]+rect[2]/2)/layout.viewport[0]*canvas.width,canvas.y+(rect[1]+rect[3]/2)/layout.viewport[1]*canvas.height);
 };
 await page.goto(url.href,{waitUntil:'load',timeout:60000});
 await until('MENU',60000);
 const menu=report.snapshots.menu=await telemetry();
 expect(menu.qa&&menu.session_duration===1&&menu.save_path==='user://survivor_meta_qa.json','WebKit loads the isolated QA build');
 await tap('start');
 await until('RESULTS');
 const result=report.snapshots.result=await telemetry();
 expect(result.won&&result.coins>menu.coins,'WebKit touch starts and completes the QA run');
 expect(result.effects===0&&result.hazards===0&&result.projectiles===0,'WebKit results reclaim combat objects');
 await page.screenshot({path:path.join(out,'results.png')});
 await page.waitForTimeout(1200);
 await page.reload({waitUntil:'load'});
 await until('MENU',60000);
 const reloaded=report.snapshots.reloaded=await telemetry();
 expect(reloaded.coins===result.coins,'WebKit persists QA progress through IDBFS reload');
 await tap('shop');
 await until('SHOP');
 await tap('shop_back');
 await until('MENU');
 expect(true,'WebKit touch opens and closes the shop');
 expect(report.errors.length===0,'no WebKit, shader, load or Godot script errors');
 console.log('WEBKIT CHECK PASSED');
}catch(error){report.failure=error.message;throw error;}
finally{
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
 await browser.close();
}
