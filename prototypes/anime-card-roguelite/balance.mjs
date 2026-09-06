import assert from 'node:assert/strict';
import {CHARACTERS,ARCHETYPES,getCard,POTIONS} from './data.js';
import * as E from './engine.js';
const threat=r=>r.enemies.filter(e=>e.hp>0).reduce((n,e)=>n+E.getIntentDamage(e)*e.intent.hits,0);
const amount=(c,op)=>c.effects.filter(e=>e.op===op).reduce((n,e)=>n+(e.amount||0)*(e.hits||1),0);
function score(r,instance){
  const c=getCard(instance.cardId,instance.upgraded),enemy=r.enemies.find(e=>e.hp>0);
  const damage=amount(c,'damage')+c.effects.reduce((n,e)=>n+(e.chargeMultiplier||0)*r.player.charge+(e.blockMultiplier||0)*r.player.block,0);
  const defense=Math.min(amount(c,'block'),Math.max(0,threat(r)-r.player.block));
  return damage+defense*1.7+amount(c,'poison')*3+amount(c,'poison_multiply')*(enemy?.poison||0)*2
    +amount(c,'strength')*5+amount(c,'thorns')*4+amount(c,'charge')*(r.player.charge<6?3:0)
    +amount(c,'exhaust_guard')*3+amount(c,'draw')*4+amount(c,'energy')*9+amount(c,'resonance')*2+amount(c,'weak')*2;
}
function fight(r){
  for(let n=0;n<16&&r.phase==='battle';n++){
    for(const p of [...r.potions]){
      const item=POTIONS.find(x=>x.id===p.potionId);
      if(item.id==='energy_tonic'&&r.energy>1)continue;
      if(item.id==='guard_tonic'&&threat(r)<=r.player.block)continue;
      E.usePotion(r,p.uid,item.target==='enemy'?r.enemies.find(e=>e.hp>0)?.id:null);
    }
    const playable=r.hand.filter(i=>getCard(i.cardId,i.upgraded).cost<=r.energy).sort((a,b)=>score(r,b)-score(r,a));
    const i=playable[0];if(!i||score(r,i)<=0)break;
    const c=getCard(i.cardId,i.upgraded),target=c.target==='enemy'?r.enemies.find(e=>e.hp>0).id:null;
    assert.equal(E.playCard(r,i.uid,target,r.resonance>=3&&c.effects.some(e=>e.op==='damage'||e.op==='block')).ok,true);
  }
  if(r.phase==='battle')E.endTurn(r);
}
function simulate(character,seed,build){
  const r=E.createRun({characterId:character.id,deck:character.deck,seed:`balance-${seed}`});let actions=0;
  while(!['won','lost'].includes(r.phase)&&actions++<220){
    if(r.phase==='map'){const kind={0:'battle',1:'battle',2:'camp',3:'battle',4:'event',5:'camp',6:'boss'}[r.step];E.visitNode(r,r.map[r.step].find(n=>n.kind===kind).id);}
    else if(r.phase==='battle'){if(build)fight(r);else E.endTurn(r);}
    else if(r.phase==='reward'){
      const picks=[...r.rewards].sort((a,b)=>{
        const value=id=>{const c=getCard(id);return (c.tags.includes(build)?20:0)+(amount(c,'damage')+amount(c,'block')+amount(c,'poison')*3+amount(c,'strength')*5+amount(c,'charge')*3+amount(c,'exhaust_guard')*4)/(c.cost+1);};
        return value(b)-value(a);
      });E.chooseReward(r,build?picks[0]:null);
    }else if(r.phase==='camp')E.rest(r);
    else if(r.phase==='event')E.chooseEvent(r,build&&r.player.hp>50?'risk':'heal');
    E.assertInvariants(r);
  }
  assert.ok(actions<220,`${character.id} stalled`);
  return {win:r.phase==='won'?1:0,battles:r.metrics.battlesWon,traits:r.metrics.traitTriggers,potions:r.metrics.potionsUsed,relays:r.metrics.relays};
}
const report=[];
for(const c of CHARACTERS){
  for(const build of [null,...c.builds]){
    const runs=Array.from({length:100},(_,n)=>simulate(c,n,build));const avg=k=>runs.reduce((n,r)=>n+r[k],0)/runs.length;
    const result={character:c.name,job:c.job,strategy:build?ARCHETYPES[build].name:'只結束回合',runs:100,winRate:avg('win'),battles:avg('battles'),traitTriggers:avg('traits'),potions:avg('potions'),relays:avg('relays')};
    report.push(result);if(build)assert.ok(result.winRate>0,`${c.id}/${build}無通關路線`);else assert.equal(result.battles,0);
  }
}
console.log(JSON.stringify({simulations:900,report,note:'固定路線與簡單可見資訊策略，非真人勝率。'},null,2));
