import test from 'node:test';
import assert from 'node:assert/strict';
import {CHARACTERS,CARDS,ARCHETYPES,RELICS,getCard} from './data.js';
import {createRun,visitNode,playCard,endTurn,usePotion,assertInvariants,getBuildSummary,getLootHint} from './engine.js';
function fixture(characterId,ids=[]){
  const character=CHARACTERS.find(c=>c.id===characterId);
  const deck=ids.length?[...ids]:[...character.deck];
  for(const fixed of character.fixedCards){if(!deck.includes(fixed))deck.push(fixed);}
  while(deck.length>10){
    const basic=deck.findLastIndex(id=>(id==='strike'||id==='defend')&&!character.fixedCards.includes(id));
    const removable=basic>=0?basic:deck.findLastIndex(id=>!character.fixedCards.includes(id));
    deck.splice(removable,1);
  }
  while(deck.length<10)deck.push(deck.filter(id=>id==='strike').length<5?'strike':'defend');
  const r=createRun({characterId,deck,seed:'character-test'});visitNode(r,r.map[0][0].id);
  r.enemies.forEach((e,i)=>{e.maxHp=999;e.hp=i?0:999;e.intent={kind:'defend',amount:0,hits:1,label:'等待'};});r.energy=30;
  return r;
}
function take(r,id){
  let c=r.hand.find(c=>c.cardId===id);if(c)return c;
  for(const zone of [r.draw,r.discard]){const i=zone.findIndex(c=>c.cardId===id);if(i>=0){c=zone.splice(i,1)[0];r.hand.push(c);return c;}}
  throw Error(`missing ${id}`);
}
function play(r,id){const c=take(r,id);return playCard(r,c.uid,getCard(id).target==='enemy'?r.enemies[0].id:null);}

test('characters have distinct starters and jobs; all builds have support and bridge cards',()=>{
  assert.equal(CHARACTERS.length,3);assert.equal(new Set(CHARACTERS.map(c=>c.job)).size,3);
  for(const c of CHARACTERS){
    assert.equal(c.fixedCards.length,2);assert.equal(new Set(c.fixedCards).size,2);
    for(const id of c.fixedCards)assert.equal(c.deck.filter(cardId=>cardId===id).length>=1,true);
    const r=createRun({deck:c.deck,characterId:c.id,seed:'start'});
    assert.equal(r.player.hp,c.maxHp);assert.equal(r.currentUniverse,c.universe);assert.equal(r.potions[0].potionId,c.starterPotion);
    for(const id of c.fixedCards){const copies=r.deck.filter(card=>card.cardId===id);assert.equal(copies[0].fixed,true);assert.equal(copies.slice(1).every(card=>!card.fixed),true);}
    assert.equal(r.deck.filter(card=>!c.fixedCards.includes(card.cardId)&&card.fixed).length,0);
  }
  for(const id of Object.keys(ARCHETYPES)){assert.ok(CARDS.filter(c=>c.tags.includes(id)).length>=4,id);assert.ok(RELICS.some(r=>r.tags.includes(id)));}
  assert.ok(CARDS.filter(c=>c.tags.length>1).length>=10);
  assert.throws(()=>createRun({deck:CHARACTERS[0].deck,seed:'s',characterId:'unknown'}),/未知角色/);
});
test('ninja third attack draws once per turn; skill plays and potion do not count',()=>{
  const r=fixture('shadow_ninja',['strike','strike','strike','strike','defend','defend','defend','defend','defend','flash_jab']);
  play(r,'defend');usePotion(r,r.potions[0].uid,r.enemies[0].id);
  play(r,'strike');play(r,'strike');assert.equal(r.metrics.traitTriggers,0);
  take(r,'strike');const before=r.hand.length;play(r,'strike');assert.equal(r.hand.length,before);assert.equal(r.metrics.traitTriggers,1);
  play(r,'strike');assert.equal(r.metrics.traitTriggers,1);endTurn(r);r.energy=20;
  for(let i=0;i<3;i++)play(r,'strike');assert.equal(r.metrics.traitTriggers,2);assertInvariants(r);
});
test('fighter banks capped charge; release consumes it before first-heavy trait refills',()=>{
  const r=fixture('ki_fighter',['ki_focus','ki_focus','meteor_release','meteor_release']);
  play(r,'ki_focus');play(r,'ki_focus');assert.equal(r.player.charge,6);
  const hp=r.enemies[0].hp;play(r,'meteor_release');assert.equal(hp-r.enemies[0].hp,26);assert.equal(r.player.charge,2);assert.equal(r.metrics.traitTriggers,1);
  play(r,'meteor_release');assert.equal(r.player.charge,0);assert.equal(r.metrics.traitTriggers,1);
  r.player.charge=8;play(r,'ki_focus');assert.equal(r.player.charge,9);
});
test('ronin first block bonus and guard relic apply once; shield converts actual block to damage',()=>{
  const r=fixture('silver_ronin',['defend','defend','shield_bash']);r.relics.push('guard_knot');
  play(r,'defend');assert.equal(r.player.block,10);play(r,'defend');assert.equal(r.player.block,15);
  const hp=r.enemies[0].hp;play(r,'shield_bash');assert.equal(hp-r.enemies[0].hp,18);assert.equal(r.player.block,15);
  endTurn(r);r.energy=20;play(r,'defend');assert.equal(r.player.block,10);assert.equal(r.metrics.traitTriggers,2);
});
test('exile enables block engine and capped relic healing, including the power itself',()=>{
  const r=fixture('silver_ronin',['ash_aegis','burning_notes','flash_jab']);r.relics.push('ash_heart');r.player.hp=40;
  play(r,'ash_aegis');assert.equal(r.player.block,3);assert.equal(r.player.hp,41);
  play(r,'burning_notes');assert.equal(r.player.block,6);assert.equal(r.player.hp,42);
  play(r,'flash_jab');assert.equal(r.player.block,9);assert.equal(r.player.hp,42);assert.equal(r.exile.length,3);assertInvariants(r);
});
test('poison multiply works with one venom-fang bonus; potions atomic and single-use',()=>{
  const r=fixture('shadow_ninja',['venom_needle','venom_needle','venom_bloom']);r.relics.push('venom_fang');
  play(r,'venom_needle');assert.equal(r.enemies[0].poison,5);play(r,'venom_needle');assert.equal(r.enemies[0].poison,8);play(r,'venom_bloom');assert.equal(r.enemies[0].poison,16);
  const p=r.potions[0],before=structuredClone(r);assert.equal(usePotion(r,p.uid,'missing').ok,false);assert.deepEqual(r,before);
  const universe=r.currentUniverse,plays=r.metrics.cardsPlayed;assert.equal(usePotion(r,p.uid,r.enemies[0].id).ok,true);assert.equal(r.enemies[0].poison,22);
  assert.equal(r.currentUniverse,universe);assert.equal(r.metrics.cardsPlayed,plays);assert.equal(usePotion(r,p.uid,r.enemies[0].id).ok,false);assert.equal(r.potions.length,0);
});
test('loot is deterministic, unique, affinity-biased and still allows all cross-class cards',()=>{
  const seen=new Set();
  for(let seed=0;seed<800;seed++){
    const c=CHARACTERS[0];const r=createRun({deck:c.deck,characterId:c.id,seed:String(seed)});visitNode(r,r.map[0][0].id);r.enemies.forEach(e=>e.hp=0);
    const twin=structuredClone(r);endTurn(r);endTurn(twin);assert.deepEqual(r,twin);assert.equal(new Set(r.rewards).size,3);
    assert.ok(r.rewards.some(id=>getCard(id).tags.some(t=>c.builds.includes(t))));r.rewards.forEach(id=>seen.add(id));
    assert.ok(getBuildSummary(r).some(b=>b.id==='poison'));assert.ok(getLootHint(r,r.rewards[0]).length>8);
  }
  assert.equal(seen.size,CARDS.length-2,'all nonbasic cards remain obtainable');
});

test('charge relic and potion resources stay distinct from card traits',()=>{
  const c=CHARACTERS[1],r=createRun({characterId:c.id,deck:c.deck,seed:'relic-start'});r.relics.push('ki_orb','ki_shell');visitNode(r,r.map[0][0].id);
  assert.equal(r.player.charge,2);r.energy=0;assert.equal(usePotion(r,r.potions[0].uid).ok,true);assert.equal(r.energy,1);assert.equal(r.metrics.traitTriggers,0);
  r.energy=10;r.player.charge=6;r.enemies[0].hp=r.enemies[0].maxHp=999;
  play(r,'meteor_release');assert.equal(r.player.block,6);assert.equal(r.player.charge,2);
  const ronin=fixture('silver_ronin');usePotion(ronin,ronin.potions[0].uid);assert.equal(ronin.player.block,12);assert.equal(ronin.metrics.traitTriggers,0);
});
test('relay scroll draws only once each turn and combo bracer triggers on third attack',()=>{
  const r=fixture('ki_fighter',['ki_blast','kunai_barrage','blade_flurry','ki_blast','kunai_barrage']);r.relics.push('relay_scroll','combo_bracer');
  play(r,'ki_blast');play(r,'kunai_barrage');play(r,'blade_flurry');play(r,'ki_blast');
  assert.equal(r.player.block,3);assert.equal(r.log.filter(s=>s.startsWith('越界卷軸')).length,1);
  endTurn(r);r.energy=20;play(r,'kunai_barrage');assert.equal(r.log.filter(s=>s.startsWith('越界卷軸')).length,2);
});
test('venom incense grants defense before poison ticks and incoming damage',()=>{
  const r=fixture('ki_fighter');r.relics.push('venom_incense');r.enemies[0].poison=3;r.enemies[0].intent={kind:'attack',amount:5,hits:1,label:'攻擊'};
  const hp=r.player.hp;endTurn(r);assert.equal(r.player.hp,hp-2);assert.equal(r.enemies[0].poison,2);
});

test('a lethal damage hit does not spend the first actual poison application bonus',()=>{
  const r=fixture('shadow_ninja',['venom_needle','venom_needle']);r.relics.push('venom_fang');
  const other={...structuredClone(r.enemies[0]),id:'surviving-enemy',hp:999};r.enemies.push(other);r.enemies[0].hp=1;
  play(r,'venom_needle');assert.equal(r._turn.poison,false);
  const c=take(r,'venom_needle');assert.equal(playCard(r,c.uid,other.id).ok,true);assert.equal(other.poison,5);
});
