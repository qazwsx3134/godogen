// Real canvas mouse input and IndexedDB save/reload against the local Web export.
// node tools/browser_check.mjs --playwright /path/to/playwright-core --chromium /path/to/chrome
import {createRequire} from 'node:module';
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import path from 'node:path';
const arg=(name,fallback)=>{const i=process.argv.indexOf(name);return i<0?fallback:process.argv[i+1];};
const {chromium}=createRequire(import.meta.url)(arg('--playwright','playwright'));
const out=arg('--out','prototypes/dreamling-idle/evidence/web');
await mkdir(out,{recursive:true});
const url=new URL(arg('--url','http://127.0.0.1:8797/'));
url.searchParams.set('qa','1');
const browser=await chromium.launch({headless:true,executablePath:arg('--chromium',undefined),
  args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:1280,height:900}});
const page=await context.newPage();
const errors=[];
const checks=[];
page.on('pageerror',error=>errors.push(String(error)));
page.on('console',message=>{if(/SCRIPT ERROR|Parse Error|Failed loading resource|Shader compilation failed|WebAssembly.*(failed|error)/i.test(message.text())) errors.push(message.text());});
const state=()=>page.evaluate(()=>window.__dreamlingQA);
async function ready(){await page.waitForFunction(()=>window.__dreamlingQA?.ready,null,{timeout:120000});}
async function clickRect(rect){
  const current=await state();
  const canvas=await page.locator('canvas').boundingBox();
  assert.ok(canvas,'canvas exists');
  await page.mouse.click(canvas.x+(rect.x+rect.w/2)/current.logical_size.w*canvas.width,
    canvas.y+(rect.y+rect.h/2)/current.logical_size.h*canvas.height);
  await page.waitForTimeout(300);
}
async function button(suffix){
  for(let attempt=0;attempt<8;attempt++){
    const current=await state();
    const control=current.controls.find(item=>item.key.endsWith(suffix));
    if(control){assert.equal(control.disabled,false,`${suffix} enabled`);await clickRect(control);return;}
    const canvas=await page.locator('canvas').boundingBox();
    await page.mouse.move(canvas.x+canvas.width*.80,canvas.y+canvas.height*.75);
    await page.mouse.wheel(0,180);
    await page.waitForTimeout(250);
  }
  throw new Error(`visible control not found: ${suffix}`);
}
async function tab(index){await clickRect((await state()).tabs[index]);assert.equal((await state()).tab,index);}
try{
  await page.goto(url.toString(),{waitUntil:'domcontentloaded',timeout:120000});
  await ready();
  await page.waitForTimeout(500);
  assert.equal((await state()).deployed.length,2);checks.push('fresh profile and real battlefield loaded');
  await button('/Pause');assert.equal((await state()).paused,true);checks.push('mouse pause');
  const dismiss=(await state()).controls.find(item=>item.key.endsWith('/DismissHelp'));
  if(dismiss) await clickRect(dismiss);
  await button('/Dew/Body/Actions/Inspect');assert.equal((await state()).selected,'dew');
  await button('/Ember/Body/Actions/Deploy');
  await button('/Dew/Body/Actions/Deploy');
  assert.deepEqual((await state()).deployed,['moss','dew']);checks.push('mouse party replacement');
  const level=(await state()).roster.dew.level;
  await button('/Train');assert.equal((await state()).roster.dew.level,level+1);checks.push('paid training through canvas');
  await page.screenshot({path:path.join(out,'party.png')});
  await tab(1);await page.screenshot({path:path.join(out,'equipment.png')});
  await tab(2);await page.screenshot({path:path.join(out,'map.png')});
  await tab(3);await page.screenshot({path:path.join(out,'talents.png')});
  await tab(5);await page.screenshot({path:path.join(out,'report.png')});checks.push('six-page navigation');
  await button('/Save');
  await page.waitForFunction(()=>window.__dreamlingQA.save_status.includes('已儲存'));
  await page.waitForTimeout(1500);
  url.searchParams.set('resume','1');
  await page.goto(url.toString(),{waitUntil:'domcontentloaded',timeout:120000});
  await ready();
  assert.deepEqual((await state()).deployed,['moss','dew']);
  assert.ok((await state()).roster.dew.level>=level+1);checks.push('IndexedDB persistence across engine restart');
  await page.screenshot({path:path.join(out,'restored.png')});
  await page.setViewportSize({width:960,height:675});await page.waitForTimeout(750);
  assert.ok((await state()).controls.some(control=>control.key.endsWith('/Save')));checks.push('compact viewport keeps save control reachable');
  await page.screenshot({path:path.join(out,'compact.png')});
  assert.deepEqual(errors,[],'no runtime or browser errors');
  const report={status:'PASS',url:url.toString(),checks,errors,viewports:['1280x900','960x675'],
    scope:'real browser canvas input, pause, party replacement, training, navigation, IndexedDB reload, compact viewport; no real-device performance claim'};
  await writeFile(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');
  console.log('DREAMLING WEB PASSED',JSON.stringify(report));
}catch(error){
  await page.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});
  await writeFile(path.join(out,'report.json'),JSON.stringify({status:'FAIL',checks,errors,error:String(error)},null,2));
  throw error;
}finally{await context.close();await browser.close();}
