import test from 'node:test';
import assert from 'node:assert/strict';
import { CARDS, CHARACTERS } from './data.js';
import { createRun, visitNode, endTurn, chooseReward, chooseEvent, upgradeCard, buyCard, removeCard, assertInvariants } from './engine.js';

test('排除快照在最小三牌候選池中仍能產生完整獎勵與商店，固定牌升級後仍鎖定', () => {
  const character=CHARACTERS[0];
  const candidates=[...character.fixedCards,'ki_blast'];
  const excluded=CARDS.filter(c=>!['strike','defend',...candidates].includes(c.id)).map(c=>c.id);
  const deck=[...character.fixedCards,'ki_blast','ki_blast',...Array(3).fill('strike'),...Array(3).fill('defend')];
  for(let seed=0;seed<20;seed++){
    const run=createRun({deck,excludedCards:excluded,seed:`excluded-${seed}`});
    assert.notEqual(run.excludedCards,excluded);
    visitNode(run,run.map[0][0].id);
    run.enemies.forEach(e=>e.hp=0);
    endTurn(run);
    assert.deepEqual([...run.rewards].sort(),[...candidates].sort());
    const invalidReward=structuredClone(run);
    invalidReward.rewards[0]=excluded[0];
    const beforeReward=structuredClone(invalidReward);
    assert.equal(chooseReward(invalidReward,excluded[0]).ok,false);
    assert.deepEqual(invalidReward,beforeReward);
    chooseReward(run,null);
    visitNode(run,run.map[1].find(n=>n.kind==='event').id);
    chooseEvent(run,'heal');
    visitNode(run,run.map[2].find(n=>n.kind==='camp').id);
    const fixed=run.deck.find(c=>c.fixed);
    assert.equal(upgradeCard(run,fixed.uid).ok,true);
    assert.equal(fixed.fixed,true);assert.equal(fixed.upgraded,1);
    visitNode(run,run.map[3].find(n=>n.kind==='shop').id);
    assert.deepEqual(run.shop.cards.map(c=>c.id).sort(),[...candidates].sort());
    const beforeRemoval=structuredClone(run);
    assert.equal(removeCard(run,fixed.uid).ok,false);assert.deepEqual(run,beforeRemoval);
    const invalidShop=structuredClone(run);
    invalidShop.shop.cards[0].id=excluded[0];
    const beforeShop=structuredClone(invalidShop);
    assert.equal(buyCard(invalidShop,excluded[0]).ok,false);
    assert.deepEqual(invalidShop,beforeShop);
    assertInvariants(run);
  }
});
