import { createRequire } from 'node:module';
import { mkdir } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { CAMPAIGN_KEY } from './campaign.js';
const require=createRequire(import.meta.url),arg=n=>process.argv[process.argv.indexOf(n)+1];
const {chromium}=require(arg('--playwright'));
const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:1440,height:900},reducedMotion:'reduce'});
const page=await context.newPage(),out='/tmp/rift-menu-browser';await mkdir(out,{recursive:true});
const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()>=400)errors.push(`${r.status()} ${r.url()}`);});
const click=async id=>page.locator(`[data-menu="${id}"]`).click();
const saved=async()=>page.evaluate(key=>JSON.parse(localStorage.getItem(key)),CAMPAIGN_KEY);
try {
 await page.goto('http://127.0.0.1:5178');await page.locator('[data-menu="play"]').waitFor();
 assert.equal(await page.locator('[data-character]').count(),0,'title must not expose character choice');
 await page.evaluate(async()=>{const image=new Image();image.src='./assets/menu/title-rift.png';await image.decode();});
 await page.screenshot({path:`${out}/title.png`,fullPage:true});
 await click('achievements');await page.screenshot({path:`${out}/achievements.png`,fullPage:true});await click('back');
 await click('play');assert.equal(await page.locator('[data-menu="continue"]').isDisabled(),true);
 await click('new');assert.equal(await page.locator('[data-character]').count(),0);
 await page.locator('[data-build="poison"]').click();await page.screenshot({path:`${out}/setup.png`,fullPage:true});
 await click('choose-character');await page.locator('[data-character="shadow_ninja"]').click();
 await page.locator('#seed').fill('menu-flow-2026');
 assert.match(await page.locator('.character-launch').innerText(),/固定牌保留：毒針/);
 await page.screenshot({path:`${out}/character.png`,fullPage:true});
 await page.locator('#start').click();await page.locator('[data-node]:not(:disabled)').first().click();
 let snap=await saved();assert.ok(snap.run.excludedCards.includes('toxic_mist'));assert.ok(!snap.run.excludedCards.includes('venom_needle'));assert.ok(snap.run.excludedRelics.includes('venom_fang'));
 await page.locator('#end').click();snap=await saved();
 await page.reload();await click('play');await page.screenshot({path:`${out}/continue.png`,fullPage:true});await click('continue');
 assert.deepEqual((await saved()).run,snap.run,'reload preserves exact progress');
 assert.equal(await page.locator('[data-play]').count(),snap.run.hand.length);
 await click('title');await click('play');await click('new');await click('choose-character');
 await page.locator('#start').click();await page.locator('[data-menu="confirm-replace"]').waitFor();
 assert.deepEqual((await saved()).run,snap.run,'new-game setup must not replace old save');
 await click('cancel-replace');await page.locator('#start').click();await click('confirm-replace');
 assert.equal((await saved()).run.phase,'map');assert.ok(!(await saved()).run.excludedCards.includes('toxic_mist'),'new unfiltered run releases earlier build exclusions');assert.notEqual((await saved()).runId,snap.runId);
 await click('title');await click('achievements');assert.match(await page.locator('[data-achievement="first_run"]').getAttribute('class'),/unlocked/);
 await click('back');
 for(const [width,height] of [[390,844],[844,390]]) {
  await page.setViewportSize({width,height});await page.screenshot({path:`${out}/title-${width}.png`,fullPage:true});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  await click('play');await click('new');await page.screenshot({path:`${out}/setup-${width}.png`,fullPage:true});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.keyboard.press('Escape');await page.keyboard.press('Escape');
 }
 assert.deepEqual(errors,[]);console.log(JSON.stringify({passed:true,checks:['title then setup then character','fixed-card protection','card and relic filtering','exact reload continue','overwrite deferred until confirmation','achievements','portrait and landscape','Escape navigation'],screenshots:out}));
} finally {await browser.close();}
