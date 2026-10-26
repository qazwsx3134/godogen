// Local Web export smoke check; no credentials or production storage.
// node tools/browser_check.mjs --playwright /path/to/playwright --url http://127.0.0.1:8774 --out /tmp/skybound-web
import {createRequire} from 'node:module';
import {mkdir, writeFile} from 'node:fs/promises';
import path from 'node:path';
const args = process.argv.slice(2);
const arg = (name, fallback) => { const i=args.indexOf(name); return i<0?fallback:args[i+1]; };
const {chromium} = createRequire(import.meta.url)(arg('--playwright','playwright'));
const out = arg('--out','/tmp/skybound-web');
await mkdir(out,{recursive:true});
const browser = await chromium.launch({headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const context = await browser.newContext({viewport:{width:1440,height:900}});
const page = await context.newPage();
const errors=[];
page.on('pageerror', error=>errors.push(String(error)));
page.on('console', message=>{
  if (/SCRIPT ERROR|Parse Error|Failed loading resource|Shader compilation failed|WebAssembly.*(failed|error)/i.test(message.text())) errors.push(message.text());
});
try {
  await page.goto(arg('--url','http://127.0.0.1:8774'),{waitUntil:'networkidle',timeout:120000});
  await page.waitForFunction(()=>{
    const canvas=document.querySelector('canvas');
    const status=document.querySelector('#status');
    return canvas && canvas.width>0 && (!status || getComputedStyle(status).display==='none');
  },{},{timeout:120000});
  await page.waitForTimeout(2500);
  await page.screenshot({path:path.join(out,'desktop.png')});
  await page.keyboard.press('Escape');
  await page.waitForTimeout(400);
  await page.screenshot({path:path.join(out,'settings.png')});
  await page.keyboard.press('Escape');
  await page.setViewportSize({width:844,height:390});
  await page.waitForTimeout(1200);
  await page.screenshot({path:path.join(out,'phone.png')});
  const report={url:page.url(),errors,viewports:['1440x900','844x390'],scope:'startup, resize, pause screen; not real-device FPS or save durability'};
  await writeFile(path.join(out,'report.json'),JSON.stringify(report,null,2));
  if (errors.length) throw new Error(errors.join('\n'));
  console.log('WEB SMOKE PASS',out);
} finally {
  await context.close();
  await browser.close();
}
