import test from 'node:test';
import assert from 'node:assert/strict';
import { CAMPAIGN_KEY, freshCampaign, checkpoint, saveCampaign, loadCampaign, configuredDeck, buildExclusions } from './campaign.js';
import { createProfile, applyCharacter } from './profile.js';
import { createRun, visitNode, endTurn, playCard, chooseEvent, leaveNode } from './engine.js';
import { CARDS, CHARACTERS, RELICS, getCard } from './data.js';
const memory=()=>{const m=new Map();return {getItem:k=>m.get(k)||null,setItem:(k,v)=>m.set(k,v),removeItem:k=>m.delete(k)};};
const newRun=()=>createRun({deck:CHARACTERS[0].deck,seed:'campaign-restore',characterId:CHARACTERS[0].id});
test('checkpoint restores exact battle zones, RNG and next-turn outcomes after relaunch',()=>{
 const storage=memory(), profile=createProfile(), run=newRun();visitNode(run,run.map[0][0].id);
 const attack=run.hand.find(c=>getCard(c.cardId).effects.some(e=>e.op==='damage'));
 if(attack) playCard(run,attack.uid,run.enemies[0].id,false);
 const saved=checkpoint(freshCampaign(),run,'run-1',profile);assert.ok(saveCampaign(storage,saved));
 const restored=loadCampaign(storage).campaign.run;assert.deepEqual(restored,run);assert.equal(restored.currentNode,restored.map[0][0]);
 endTurn(run);endTurn(restored);assert.deepEqual(restored,run);
});
test('damaged snapshot falls back, unsupported versions without backup never continue',()=>{
 const storage=memory(), profile=createProfile(), run=newRun();
 saveCampaign(storage,checkpoint(freshCampaign(),run,'run-2',profile));visitNode(run,run.map[0][0].id);saveCampaign(storage,checkpoint(freshCampaign(),run,'run-2',profile));
 const damaged=JSON.parse(storage.getItem(CAMPAIGN_KEY));delete damaged.run._rng;storage.setItem(CAMPAIGN_KEY,JSON.stringify(damaged));
 const result=loadCampaign(storage);assert.match(result.notice,/備份/);assert.equal(result.campaign.run.phase,'map');
 storage.removeItem(`${CAMPAIGN_KEY}.bak`);storage.setItem(CAMPAIGN_KEY,'{"version":99}');assert.equal(loadCampaign(storage).campaign.run,null);
 const malformed=checkpoint(freshCampaign(),run,'bad-metadata',profile);malformed.buildExcludedCards={};storage.setItem(CAMPAIGN_KEY,JSON.stringify(malformed));assert.equal(loadCampaign(storage).campaign.run,null);
});
test('terminal progress unlocks achievements once and retires both active snapshots',()=>{
 const storage=memory(),profile=createProfile(),run=newRun();let state=checkpoint(freshCampaign(),run,'unique',profile);saveCampaign(storage,state);
 run.phase='won';run.metrics.battlesWon=3;run.metrics.relays=4;run.metrics.empowered=1;
 state=checkpoint(state,run,'unique',profile);state=checkpoint(state,run,'unique',profile);saveCampaign(storage,state);
 assert.deepEqual(state.stats,{runs:1,wins:1});assert.ok(state.achievements.includes('win_shadow_ninja'));assert.equal(state.run,null);
 storage.setItem(CAMPAIGN_KEY,'invalid');assert.equal(loadCampaign(storage).campaign.run,null);
});
test('write rejection leaves last save available',()=>{
 const base=memory(),profile=createProfile(),run=newRun();saveCampaign(base,checkpoint(freshCampaign(),run,'safe',profile));
 const failing={getItem:base.getItem,setItem:()=>{throw Error('quota');}};
 visitNode(run,run.map[0][0].id);assert.equal(saveCampaign(failing,checkpoint(freshCampaign(),run,'safe',profile)),false);assert.equal(loadCampaign(base).campaign.run.phase,'map');
});
test('build exclusions cover hybrid cards and relics, preserve fixed cards and refill starter deck',()=>{
 const profile=createProfile();applyCharacter(profile,'shadow_ninja');
 const f=configuredDeck(profile,['poison']);assert.ok(f.protectedCards.includes('venom_needle'));assert.ok(!f.excludedCards.includes('venom_needle'));
 assert.ok(f.excludedCards.includes('toxic_mist'));assert.equal(f.deck.length,10);assert.ok(!f.deck.some(id=>f.excludedCards.includes(id)));
 for(const relic of RELICS.filter(r=>r.tags.includes('poison'))) assert.ok(f.excludedRelics.includes(relic.id));
 for(const c of CHARACTERS) for(const tag of ['combo','poison','charge','guard','exhaust','relay']) {
  const f=buildExclusions([tag],c.id);for(const id of c.fixedCards)assert.ok(!f.excludedCards.includes(id));
 }
});
test('excluded relics never enter event or shop offers',()=>{
 for(let n=0;n<30;n++) {
  const run=createRun({deck:CHARACTERS[0].deck,seed:`relic-filter-${n}`,excludedRelics:RELICS.map(r=>r.id)});
  run.step=1;visitNode(run,run.map[1].find(n=>n.kind==='event').id);chooseEvent(run,'risk');assert.equal(run.relics.length,0);
  run.phase='map';run.step=3;visitNode(run,run.map[3].find(n=>n.kind==='shop').id);assert.equal(run.shop.relic,null);
 }
});
