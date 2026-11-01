/* Optional actual browser acceptance. Start build/showcase/serve.py first.
   PLAYWRIGHT_MODULE and CHROMIUM_BIN can point at an existing installation. */
const assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const fs=require('node:fs');const path=require('node:path');
const base=process.argv[2]||'http://127.0.0.1:8765/';
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_BIN?{executablePath:process.env.CHROMIUM_BIN}:{})});
 const errors=[];const page=await browser.newPage({viewport:{width:1360,height:1000},reducedMotion:'reduce'});
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 try{
  await page.goto(base);await page.waitForFunction(()=>document.querySelectorAll('.effect-item').length===41);
  await page.waitForFunction(()=>document.querySelector('#preview').width>0);
  await page.getByRole('button',{name:'下一幀'}).click();
  assert.match(await page.locator('#frame-label').textContent(),/02 \/ 18/);
  await page.locator('#search').fill('meteor');assert.equal(await page.locator('.effect-item').count(),1);
  await page.locator('.effect-item').click();assert.equal(await page.locator('#effect-name').textContent(),'Ember Meteor');
  await page.locator('#frame').focus();await page.keyboard.press('Home');for(let i=0;i<12;i++)await page.keyboard.press('ArrowRight');assert.match(await page.locator('#frame-label').textContent(),/13 \/ 26/);
  await page.locator('#fps').focus();await page.keyboard.press('Home');for(let i=0;i<23;i++)await page.keyboard.press('ArrowRight');assert.equal(await page.locator('#fps-label').textContent(),'24 fps');
  await page.locator('#scale').focus();await page.keyboard.press('Home');await page.keyboard.press('ArrowRight');assert.equal(await page.locator('#scale-label').textContent(),'2×');
  await page.locator('#search').fill('not-a-real-effect');assert.equal(await page.locator('.effect-item').count(),0);
  await page.locator('#search').fill('');assert.equal(await page.locator('.effect-item').count(),41);
  const output=path.resolve(__dirname,'../build');fs.mkdirSync(output,{recursive:true});
  await page.screenshot({path:path.join(output,'showcase-desktop.png'),fullPage:true});
  await page.setViewportSize({width:390,height:844});
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'mobile layout fits viewport');
  await page.screenshot({path:path.join(output,'showcase-mobile.png'),fullPage:true});
  await page.setViewportSize({width:1360,height:1000});
  await page.locator('#godot-tab').click();await page.locator('#load-godot').click();
  const frame=await(await page.locator('#godot-frame').elementHandle()).contentFrame();
  await frame.waitForFunction(()=>typeof Engine!=='undefined',null,{timeout:60000});
  await frame.waitForFunction(()=>!document.getElementById('status'),null,{timeout:120000});
  await page.screenshot({path:path.join(output,'showcase-godot.png'),fullPage:true});
  assert.deepEqual(errors,[]);
  console.log('BROWSER ACCEPTANCE PASSED: selection, search, frame/fps/scale, mobile, real Godot Web boot');
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
