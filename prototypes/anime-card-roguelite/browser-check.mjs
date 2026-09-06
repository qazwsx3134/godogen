// Run against the local server; the browser and engine replay identical visible actions.
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { PRESETS, CHARACTERS, POTIONS, getCard } from './data.js';
import * as E from './engine.js';
import { STORAGE_KEY } from './profile.js';

const arg = name => process.argv[process.argv.indexOf(name) + 1];
const require = createRequire(import.meta.url);
const { chromium } = require(process.argv.includes('--playwright') ? arg('--playwright') : '@playwright/test');
const url = process.argv.includes('--url') ? arg('--url') : 'http://127.0.0.1:5178';
const output = '/tmp/rift-character-browser';
await mkdir(output, { recursive: true });
const results = [], errors = [], themes = new Set();

async function checkTutorial(page) {
  const before=await page.locator('.view-root').innerHTML();
  const saved=await page.evaluate(key=>localStorage.getItem(key),STORAGE_KEY);
  await page.locator('#tutorial-open').click();
  assert.equal(await page.evaluate(()=>document.activeElement.id),'tutorial-close');
  await page.locator('[data-tutorial-tab="relay"]').click();
  for(let step=0;step<4;step++){
    await page.locator(`[data-tutorial-step="${step}"]`).click();
    assert.match(await page.locator('[data-tutorial="relay-state"]').innerText(),new RegExp(`${step}/3`));
    assert.equal(await page.locator('[data-tutorial-action="empower"]').isDisabled(),step<3);
  }
  await page.locator('[data-tutorial-action="neutral"]').click();
  assert.match(await page.locator('[data-tutorial="relay-state"]').innerText(),/3\/3/);
  await page.locator('[data-tutorial-action="empower"]').click();
  assert.match(await page.locator('[data-tutorial="relay-state"]').innerText(),/3\/3/);
  await page.locator('[data-tutorial-action="play"]').click();
  assert.match(await page.locator('[data-tutorial="relay-state"]').innerText(),/0\/3/);
  await page.screenshot({path:`${output}/tutorial-relay.png`});
  await page.locator('[data-tutorial-tab="charge"]').click();
  await page.locator('[data-tutorial-action="charge"]').click();
  assert.match(await page.locator('[data-tutorial="charge-state"]').innerText(),/3\/9/);
  await page.locator('[data-tutorial-action="meteor"]').click();
  assert.match(await page.locator('[data-tutorial="charge-state"]').innerText(),/17/);
  await page.setViewportSize({width:390,height:844});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'mobile tutorial overflow');
  await page.screenshot({path:`${output}/mobile-tutorial.png`});
  await page.keyboard.press('Tab');
  assert.equal(await page.evaluate(()=>document.querySelector('#tutorial-modal').contains(document.activeElement)),true);
  await page.keyboard.press('Escape');
  assert.equal(await page.evaluate(()=>document.activeElement.id),'tutorial-open');
  assert.equal(await page.locator('.view-root').innerHTML(),before,'tutorial must preserve the real game and draft');
  assert.equal(await page.evaluate(key=>localStorage.getItem(key),STORAGE_KEY),saved);
  await page.setViewportSize({width:1440,height:1000});
}

function value(run) {
  if (run.phase === 'lost') return -1e5;
  return run.player.hp * 2.8 - run.enemies.reduce((n, e) => n + e.hp * 1.5, 0)
    + run.player.strength * 4 + run.player.thorns * 3 + run.player.charge*2 + run.player.exhaustGuard*3 + run.resonance + run.enemies.reduce((n,e)=>n+(e.hp>0?e.poison*2:0),0)
    + (run.phase !== 'battle' ? 1000 : 0);
}
function bestCard(run) {
  const ended = structuredClone(run); E.endTurn(ended);
  let best = null, score = value(ended);
  for (const instance of run.hand) {
    const card = getCard(instance.cardId, instance.upgraded);
    if (card.cost > run.energy) continue;
    const targets = card.target === 'enemy' ? run.enemies.filter(e => e.hp > 0).map(e => e.id) : [null];
    for (const target of targets) for (const empowered of run.resonance >= 3 ? [false, true] : [false]) {
      const next = structuredClone(run);
      if (!E.playCard(next, instance.uid, target, empowered).ok) continue;
      const remaining = next.energy, cards = next.hand.length;
      if (next.phase === 'battle') E.endTurn(next);
      const candidate = value(next) + remaining * .1 + cards * .08;
      if (candidate > score) { score = candidate; best = { uid: instance.uid, target, empowered }; }
    }
  }
  return best;
}
function routeNode(run, mode) {
  const preferred = mode !== 'elite' ? ['battle','event','camp','shop','event','camp','boss']
    : ['battle','battle','camp','battle','elite','shop','boss'];
  return run.map[run.step].find(n => n.kind === preferred[run.step]) || run.map[run.step][0];
}
function rewardId(run) {
  const rank = ['leaf_stance','silver_resolve','team_tactics','wooden_guard','kunai_barrage','ninja_smoke','saiyan_spirit','umbrella_strike'];
  return [...run.rewards].sort((a,b) => (rank.indexOf(a) < 0 ? 99 : rank.indexOf(a)) - (rank.indexOf(b) < 0 ? 99 : rank.indexOf(b)))[0];
}
function nextAction(run, mode) {
  if (run.phase === 'map') return { fn: 'visitNode', args: [routeNode(run, mode).id], selector: `[data-node="${routeNode(run, mode).id}"]` };
  if (run.phase === 'reward') return mode === 'remove'
    ? { fn:'chooseReward', args:[null], selector:'#skip' }
    : { fn: 'chooseReward', args: [rewardId(run)], selector: `[data-reward="${rewardId(run)}"]` };
  if (run.phase === 'battle') {
    const threat=run.enemies.filter(e=>e.hp>0).reduce((n,e)=>n+E.getIntentDamage(e)*e.intent.hits,0);
    const potion=run.potions.find(p=>p.potionId==='venom_flask'||p.potionId==='energy_tonic'&&run.energy<2||p.potionId==='guard_tonic'&&threat>run.player.block);
    if(potion){const d=POTIONS.find(p=>p.id===potion.potionId);return {fn:'usePotion',args:[potion.uid,d.target==='enemy'?run.enemies.find(e=>e.hp>0).id:null],selector:`[data-potion="${potion.uid}"]`};}
    const card = bestCard(run);
    return card ? { fn: 'playCard', args: [card.uid,card.target,card.empowered], selector: `[data-play="${card.uid}"]` }
      : { fn:'endTurn', args:[], selector:'#end' };
  }
  if (run.phase === 'camp') {
    if(mode === 'remove' && run.step === 2) return {fn:'leaveNode',args:[],selector:'#leave'};
    const upgrade = run.deck.find(c => !c.upgraded && c.cardId === 'kunai_barrage');
    if (run.step === 2 && upgrade) return { fn:'upgradeCard', args:[upgrade.uid], selector:`[data-upgrade="${upgrade.uid}"]` };
    return { fn:'rest', args:[], selector:'#rest' };
  }
  if (run.phase === 'event') {
    const choice = run.step === 1 && run.player.hp > 20 ? 'risk' : 'heal';
    return { fn:'chooseEvent', args:[choice], selector:`[data-event="${choice}"]` };
  }
  if (run.phase === 'shop') {
    const shop = run.shop;
    if (mode === 'shop' || mode === 'remove') {
      const c = shop.cards.find(c => !c.sold);
      if (mode === 'shop' && c && !shop.cards.some(c => c.sold) && run.gold >= c.price) return {fn:'buyCard',args:[c.id],selector:`[data-buy-card="${c.id}"]`};
      if (!shop.removed && run.gold >= shop.removalPrice) {
        const c = run.deck.find(c => c.cardId === 'strike');
        if (c) return {fn:'removeCard',args:[c.uid],selector:`[data-remove="${c.uid}"]`};
      }
    } else if (shop.relic && !shop.relic.sold && run.gold >= shop.relic.price) return {fn:'buyRelic',args:[shop.relic.id],selector:`[data-buy-relic="${shop.relic.id}"]`};
    return {fn:'leaveNode',args:[],selector:'#leave'};
  }
  throw Error(`unexpected phase ${run.phase}`);
}
function simulate(preset, seed, mode) {
  const run = E.createRun({deck:preset.deck,seed,characterId:CHARACTERS.some(c=>c.id===preset.id)?preset.id:CHARACTERS[0].id,excludedCards:preset.excludedCards||[]});
  const actions=[];
  while (!['won','lost'].includes(run.phase) && actions.length < 350) {
    const action=nextAction(run,mode);
    assert.equal(E[action.fn](run,...action.args).ok,true,action.fn);
    E.assertInvariants(run);
    actions.push(action);
  }
  return {run,actions};
}

if (process.argv.includes('--dry-run')) {
  for (const [index,preset] of CHARACTERS.entries()) {
    const outcomes=[];
    for(let n=0;n<10;n++) {
      const {run,actions}=simulate(preset,`browser-solo-${preset.id}-${n}`,index===0?'shop':'elite');
      outcomes.push({seed:run.seed,phase:run.phase,step:run.step,hp:run.player.hp,actions:actions.length});
    }
    console.log(JSON.stringify(outcomes));
  }
  process.exit(0);
}
const browser = await chromium.launch({ headless: true });
try {
  const context = await browser.newContext({ viewport:{width:1440,height:1000}, reducedMotion:'reduce' });
  const page = await context.newPage();
  page.on('pageerror', e => errors.push(e.message));
  await page.goto(url);
  await page.locator('#start').waitFor();
  assert.equal(await page.title(),'裂界牌局');
  await page.screenshot({path:`${output}/home.png`,fullPage:true});
  await page.locator('[data-tab="collection"]').first().click();
  assert.equal(await page.locator('[data-remove-deck]').count(),10);
  await page.locator('[data-remove-deck]:not(:disabled)').first().click();
  assert.equal(await page.locator('[data-remove-deck]').count(),9);
  await page.locator('[data-add-deck="strike"]').click();
  await page.locator('#save-loadout').click();
  await page.locator('#coins').click();
  await page.locator('#pack').click();
  const grant=page.locator('[data-grant]:not(:disabled)').first();
  if(await grant.count()) await grant.click();
  const saved=await page.evaluate(key=>JSON.parse(localStorage.getItem(key)),STORAGE_KEY);
  assert.equal(saved.deck.length,10); assert.equal(saved.lastPack.length,3);
  assert.ok(saved.coins>=1400 && saved.coins<=1460);
  await page.reload();
  assert.deepEqual(await page.evaluate(key=>JSON.parse(localStorage.getItem(key)),STORAGE_KEY),saved);
  results.push('ten-card editor, free packs, direct acquisition, persistence');

  // Exclusions are a draft until a valid ten-card setup is committed.
  await page.locator('[data-tab="collection"]').first().click();
  assert.equal(await page.locator('[data-remove-deck]:disabled').count(),2);
  for (const id of CHARACTERS[0].fixedCards) {
    assert.match(await page.locator(`[data-card-id="${id}"]`).innerText(),/固定牌.*不可排除/);
  }
  await page.locator('[data-exclude="flash_jab"]').click();
  assert.equal(await page.locator('[data-remove-deck]').count(),9);
  assert.equal(await page.locator('#save-loadout').isDisabled(),true);
  assert.equal(await page.locator('[data-add-deck="flash_jab"]').isDisabled(),true);
  assert.deepEqual(await page.evaluate(key=>JSON.parse(localStorage.getItem(key)).deck,STORAGE_KEY),saved.deck);
  await page.locator('[data-add-deck="ki_blast"]').click();
  await page.locator('#save-loadout').click();
  const configured=await page.evaluate(key=>JSON.parse(localStorage.getItem(key)),STORAGE_KEY);
  assert.deepEqual(configured.excludedCards,['flash_jab']);
  assert.equal(configured.deck.includes('flash_jab'),false);
  assert.equal(configured.deck.length,10);
  await page.reload();
  await page.locator('[data-tab="collection"]').first().click();
  assert.equal(await page.locator('[data-exclude="flash_jab"]').getAttribute('aria-pressed'),'true');
  await page.setViewportSize({width:390,height:844});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'mobile loadout overflow');
  await page.screenshot({path:`${output}/mobile-loadout.png`,fullPage:true});
  await page.setViewportSize({width:1440,height:1000});
  results.push('fixed starter cards locked; exclusion draft removes optional card, validates ten cards and survives reload');
  await checkTutorial(page);
  results.push('interactive resonance and charge examples, mobile layout, focus return, no profile mutation');
  await page.locator('[data-exclude="toxic_mist"]').click();
  await page.locator('[data-tab="home"]').first().click();
  await page.locator('[data-preset="relay"]').click();
  const presetSaved=await page.evaluate(key=>JSON.parse(localStorage.getItem(key)),STORAGE_KEY);
  assert.deepEqual(presetSaved.excludedCards,['flash_jab','toxic_mist']);
  assert.equal(presetSaved.deck.length,10);
  assert.equal(presetSaved.deck.some(id=>presetSaved.excludedCards.includes(id)),false);
  results.push('preset completes an incomplete draft while preserving unsaved exclusions');

  if(process.argv.includes('--loadout-only')){
    assert.deepEqual(errors,[]);
    console.log(JSON.stringify({results,errors,screenshots:output},null,2));
    await browser.close();
    process.exit(0);
  }

  let completed=0;
  for (const [preset,mode] of [[CHARACTERS[0],'shop'],[CHARACTERS[1],'elite'],[CHARACTERS[2],'remove']]) {
    const excludedCards=mode==='shop'?['kame_wave']:[];
    let planned;
    for(let n=0;n<30;n++) {
      const candidate=simulate({...preset,excludedCards},`browser-solo-${preset.id}-${n}`,mode);
      if(candidate.run.phase==='won') {planned=candidate;break;}
      if(!planned) planned=candidate;
    }
    await page.locator('[data-tab="home"]').first().click();
    await page.locator(`[data-character="${preset.id}"]`).click();
    assert.equal(await page.locator(`[data-character="${preset.id}"]`).getAttribute('aria-pressed'),'true');
    if(excludedCards.length){
      await page.locator('[data-tab="collection"]').first().click();
      await page.locator('[data-exclude="kame_wave"]').click();
      await page.locator('#save-loadout').click();
      await page.locator('[data-tab="home"]').first().click();
    }
    await page.locator('#seed').fill(planned.run.seed);
    await page.locator('#start').click();
    const run=E.createRun({deck:preset.deck,seed:planned.run.seed,characterId:preset.id,excludedCards});
    await page.screenshot({path:`${output}/map-${mode}.png`,fullPage:true});
    const exercised=new Set();
    for(const action of planned.actions) {
      if(run.phase==='battle') {
        assert.deepEqual(await page.locator('[data-play]').evaluateAll(ns=>ns.map(n=>n.dataset.play).sort()),run.hand.map(c=>c.uid).sort());
        assert.ok((await page.locator('.player-card:visible').innerText()).includes(`${run.player.hp}/${run.player.maxHp}`));
        if(!exercised.has('modal')) {
          if(mode==='shop') {
            await checkTutorial(page);
            exercised.add('tutorial-preserves-battle');
          }
          await page.locator('[data-pile="draw"]').click();
          assert.equal(await page.evaluate(()=>document.activeElement.id),'close-modal');
          await page.keyboard.press('Tab');
          assert.equal(await page.evaluate(()=>document.querySelector('#modal').contains(document.activeElement)),true);
          await page.keyboard.press('Escape');
          assert.equal(await page.evaluate(()=>document.activeElement.dataset.pile),'draw');
          exercised.add('modal');
        }
      }
      if(action.fn==='playCard' && action.args[2]) await page.locator('#empower').click();
      await page.locator(action.selector).click();
      if(['playCard','usePotion'].includes(action.fn) && action.args[1]) await page.locator(`[data-enemy="${action.args[1]}"]`).click();
      assert.equal(E[action.fn](run,...action.args).ok,true);
      E.assertInvariants(run);
      if(run.phase==='reward') for(const id of excludedCards) assert.equal(await page.locator(`[data-reward="${id}"]`).count(),0);
      if(run.phase==='shop') {
        for(const id of excludedCards) assert.equal(await page.locator(`[data-buy-card="${id}"]`).count(),0);
        for(const instance of run.deck.filter(c=>c.fixed)) assert.equal(await page.locator(`[data-remove="${instance.uid}"]`).isDisabled(),true);
      }
      assert.equal(await page.locator('html').getAttribute('data-universe'),run.currentUniverse);
      exercised.add(action.fn);
      if(run.phase==='reward'&&!exercised.has('mobile-reward')){
        await page.setViewportSize({width:390,height:844});
        assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'mobile reward overflow');
        await page.screenshot({path:`${output}/mobile-reward-${mode}.png`,fullPage:true});
        await page.setViewportSize({width:1440,height:1000});exercised.add('mobile-reward');
      }
      if(['camp','shop','reward'].includes(run.phase)) await page.screenshot({path:`${output}/${run.phase}-${mode}.png`,fullPage:true});
      if(action.fn==='removeCard') assert.equal(await page.locator('[data-remove]:not(:disabled)').count(),0);
      if(run.phase==='battle' && !themes.has(run.currentUniverse) && run.currentUniverse!=='neutral') {
        themes.add(run.currentUniverse);
        await page.screenshot({path:`${output}/${run.currentUniverse}.png`,fullPage:true});
      }
    }
    assert.equal(run.phase,'won',`${preset.id} has a reproducible complete winning path`);
    await page.locator('#return').waitFor();
    completed++;
    const stats=await page.evaluate(key=>JSON.parse(localStorage.getItem(key)).stats,STORAGE_KEY);
    assert.equal(stats.runs,completed);
    await page.locator('[data-tab="home"]').first().click();
    await page.locator('[data-tab="run"]').click();
    assert.equal((await page.evaluate(key=>JSON.parse(localStorage.getItem(key)).stats,STORAGE_KEY)).runs,completed);
    await page.screenshot({path:`${output}/won-${preset.id}-${mode}.png`,fullPage:true});
    if(mode==='remove') assert.ok(exercised.has('removeCard'),'shop removal was exercised');
    assert.ok(run.metrics.traitTriggers>0,'character trait triggered through browser play');
    assert.ok(exercised.has('usePotion'),'consumable used through browser');
    results.push({character:preset.id,route:mode,seed:run.seed,result:run.phase,metrics:run.metrics,exercised:[...exercised]});
    await page.locator('#return').click();
  }
  assert.deepEqual([...themes].sort(),['dragon','ninja','samurai']);

  await page.locator('#start').click();
  await page.locator('[data-node]:not(:disabled)').first().click();
  const before=await page.locator('[data-enemy]').allTextContents();
  await page.locator('#end').click();
  // Enemy HP read from independent engine simulation is validated in engine tests.
  assert.ok(before.length>0);
  for(let i=0;i<45 && !await page.locator('#return').count();i++) await page.locator('#end').click();
  await page.getByRole('heading',{name:'旅人倒下'}).waitFor();
  assert.equal((await page.evaluate(key=>JSON.parse(localStorage.getItem(key)).stats,STORAGE_KEY)).runs,++completed);
  await page.locator('#return').click();
  results.push('passing turns loses; terminal result stored once');

  await page.setViewportSize({width:390,height:844});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'mobile home overflow');
  await page.locator('#start').click();
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'mobile map overflow');
  await page.locator('[data-node]:not(:disabled)').first().click();
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'mobile battle overflow');
  await page.screenshot({path:`${output}/mobile.png`,fullPage:true});
  results.push('390px home/map/battle responsive');

  const blocked=await browser.newContext();
  await blocked.addInitScript(()=>{
    for(const key of ['localStorage','sessionStorage']) Object.defineProperty(window,key,{get(){throw Error('blocked');}});
  });
  const fallback=await blocked.newPage();
  fallback.on('pageerror',e=>errors.push(e.message));
  await fallback.goto(url); await fallback.locator('#start').click();
  await fallback.locator('[data-node]:not(:disabled)').first().click();
  await fallback.locator('#end').waitFor();
  results.push('blocked storage remains playable');

  const legacy=await browser.newContext();
  await legacy.addInitScript(()=>localStorage.setItem('rift-cards.profile.v1',JSON.stringify({version:1,coins:742,collection:{silver_samurai:1},stats:{runs:4,wins:2}})));
  const migrated=await legacy.newPage(); migrated.on('pageerror',e=>errors.push(e.message));
  await migrated.goto(url); await migrated.locator('[data-preset="relay"]').click();
  const migratedSave=await migrated.evaluate(key=>JSON.parse(localStorage.getItem(key)),STORAGE_KEY);
  assert.equal(migratedSave.coins,742); assert.equal(migratedSave.collection.silver_resolve,1);
  assert.deepEqual(migratedSave.stats,{runs:4,wins:2});
  results.push('browser legacy profile migration');
  assert.deepEqual(errors,[]);
  console.log(JSON.stringify({results,themes:[...themes],errors,screenshots:output},null,2));
} finally { await browser.close(); }
