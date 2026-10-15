// Exports the upstream procedural VFX as PNG and captures the local study page.
// node capture_reference.mjs --playwright <playwright-core> --chromium <Chrome> [--url http://127.0.0.1:8798/viewer.html]
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const args=process.argv.slice(2),arg=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
const {chromium}=createRequire(import.meta.url)(arg('--playwright','playwright-core'));
const root=path.dirname(fileURLToPath(import.meta.url)),out=path.join(root,'generated');
fs.mkdirSync(out,{recursive:true});fs.mkdirSync(path.join(root,'screenshots'),{recursive:true});
const browser=await chromium.launch({headless:true,executablePath:arg('--chromium','/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')});
const page=await browser.newPage({viewport:{width:1440,height:1000},deviceScaleFactor:1});
const errors=[];
await page.addInitScript(()=>window.addEventListener('error',e=>window.__studyError=e.message));
page.on('pageerror',e=>{errors.push(e.message);console.log('PAGE ERROR',e.message);});
page.on('console',m=>{if(m.type()==='error'){errors.push(m.text());console.log('CONSOLE ERROR',m.text());}});
await page.route('**/*',route=>{
 const u=new URL(route.request().url());
 if(['127.0.0.1','localhost'].includes(u.hostname)||u.protocol==='data:')return route.continue();
 return route.abort();
});
try{
 await page.goto(arg('--url','http://127.0.0.1:8798/viewer.html'),{waitUntil:'networkidle'});
 await page.waitForFunction(()=>window.__studyReady||window.__studyError);
 const initializationError=await page.evaluate(()=>window.__studyError);if(initializationError)throw new Error(initializationError);
 await page.locator('#play').click();
 await page.locator('#sprite-play').click();
 const data=await page.evaluate(()=>window.exportStudy());
 for(const item of data.frames){
  const dir=path.join(out,'vfx',item.pal);fs.mkdirSync(dir,{recursive:true});
  fs.writeFileSync(path.join(dir,`${item.shape}-${item.frame}.png`),Buffer.from(item.data.split(',')[1],'base64'));
 }
 for(const item of data.atlas){fs.writeFileSync(path.join(out,`atlas-${item.pal}.png`),Buffer.from(item.data.split(',')[1],'base64'));}
 const frameCount=data.frames.length;delete data.frames;delete data.atlas;
 fs.writeFileSync(path.join(out,'vfx-catalogue.json'),JSON.stringify({shapes:data.shapes,palettes:data.palettes,icons:data.icons,exported_png_frames:frameCount},null,2));
 fs.writeFileSync(path.join(out,'sprite-metadata.json'),JSON.stringify(data.metadata,null,2));
 await page.locator('#shapes').screenshot({path:path.join(root,'screenshots/vfx-shapes.png')});
 await page.locator('#effect').selectOption('beam');
 await page.locator('#time').fill('80');await page.locator('#time').dispatchEvent('input');
 await page.locator('#timing').screenshot({path:path.join(root,'screenshots/beam-080ms.png')});
 await page.locator('#effect').selectOption('melee');
 await page.locator('#time').fill('120');await page.locator('#time').dispatchEvent('input');
 await page.locator('#timing').screenshot({path:path.join(root,'screenshots/melee-120ms.png')});
 await page.locator('#anim').selectOption('Attack');
 await page.locator('#sprite-frame').fill('3');await page.locator('#sprite-frame').dispatchEvent('input');
 await page.waitForTimeout(400);
 await page.locator('#sprites').screenshot({path:path.join(root,'screenshots/sprite-animation.png')});
 await page.locator('#world').screenshot({path:path.join(root,'screenshots/world-and-icons.png')});
 fs.writeFileSync(path.join(out,'capture-observation.json'),JSON.stringify({shapes:Object.keys(data.shapes).length,palettes:Object.keys(data.palettes).length,png_frames:frameCount,species:Object.keys(data.metadata).length,icons:data.icons.length,errors},null,2));
 console.log(JSON.stringify({shapes:Object.keys(data.shapes).length,palettes:Object.keys(data.palettes).length,png_frames:frameCount,species:Object.keys(data.metadata).length,icons:data.icons.length,errors}));
}finally{await browser.close();}
