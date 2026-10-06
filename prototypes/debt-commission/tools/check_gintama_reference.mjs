import {createRequire} from 'node:module';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url);
const arg=(name,fallback)=>{const index=process.argv.indexOf(name);return index>=0?process.argv[index+1]:fallback;};
const {chromium}=require(arg('--playwright','@playwright/test'));
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const output=path.resolve(arg('--out',path.join(root,'test-results','gintama-reference')));
const url=new URL(arg('--url','http://127.0.0.1:5194/'));
url.searchParams.set('sample','comedy');url.searchParams.set('qa','1');
await fs.mkdir(output,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--enable-webgl','--ignore-gpu-blocklist','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const results=[];
try {
for(const viewport of [{width:720,height:1280},{width:390,height:844},{width:320,height:568}]) {
 const context=await browser.newContext({viewport,deviceScaleFactor:1,hasTouch:true,isMobile:true});
 const page=await context.newPage();
 const errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:/.test(m.text()))errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.__debtQA);
 const tap=async name=>{const s=await state();const r=s.controls[name];assert.ok(r,name);const c=await page.locator('canvas').boundingBox();await page.touchscreen.tap(c.x+(r.x+r.width/2)/s.viewport.width*c.width,c.y+(r.y+r.height/2)/s.viewport.height*c.height);await page.waitForTimeout(250);};
 await page.goto(url.toString());
 await page.waitForFunction(()=>window.__debtQA?.screen==='title',null,{timeout:120000});
 await tap('title_style_gintama');await tap('begin');
 await page.waitForFunction(()=>window.__debtQA?.screen==='story'&&window.__debtQA.text_complete,null,{timeout:30000});
 let s=await state();assert.equal(s.full_text,'今天也完全沒有工作啊。');
 await page.screenshot({path:`${output}/${viewport.width}x${viewport.height}.png`});
 const initial=s;
 await tap('log');await page.waitForFunction(()=>window.__debtQA?.screen==='log');
 await tap('log_close');await page.waitForFunction(()=>window.__debtQA?.screen==='story');
 assert.equal((await state()).full_text,initial.full_text);
 await tap('menu');await page.waitForFunction(()=>window.__debtQA?.screen==='menu');
 await tap('menu_close');await page.waitForFunction(()=>window.__debtQA?.screen==='story');
 assert.equal((await state()).full_text,initial.full_text);
 await tap('auto');assert.equal((await state()).auto,true);
 await tap('auto');assert.equal((await state()).auto,false);
 await tap('skip');assert.equal((await state()).skip,true);
 await tap('skip');assert.equal((await state()).skip,false);
 assert.deepEqual(errors,[]);
 results.push({viewport,initial,checks:['same reference quote','LOG returns to same line','MENU returns to same line','AUTO on/off','SKIP on/off'],errors});
 await context.close();
}
await fs.writeFile(`${output}/report.json`,JSON.stringify(results,null,2));
console.log('REFERENCE CAPTURE AND FOUR BUTTON CHECKS PASSED');
} finally {await browser.close();}
