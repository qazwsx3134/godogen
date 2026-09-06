import test from 'node:test';
import assert from 'node:assert/strict';
import { CARDS, PRESETS, RELICS, UNIVERSES, getCard } from './data.js';
import { assertInvariants, buyCard, buyRelic, chooseEvent, chooseReward, createRun, endTurn, getIntentDamage, leaveNode, playCard, removeCard, rest, upgradeCard, visitNode } from './engine.js';

const presetRelayDeck = PRESETS.find((preset) => preset.id === 'relay').deck;
function withFixedCards(deck, characterId = 'shadow_ninja') {
  const fixed = new Set({ shadow_ninja: ['kunai_barrage', 'venom_needle'], ki_fighter: ['ki_focus', 'meteor_release'], silver_ronin: ['wooden_guard', 'shield_bash'] }[characterId]);
  const result = [...deck];
  for (const id of fixed) if (!result.includes(id)) result.push(id);
  while (result.length > 10) {
    const basic = result.findLastIndex((id) => (id === 'strike' || id === 'defend') && !fixed.has(id));
    const removable = basic >= 0 ? basic : result.findLastIndex((id) => !fixed.has(id));
    result.splice(removable, 1);
  }
  while (result.length < 10) result.push('strike');
  return result;
}
const relayDeck = withFixedCards(presetRelayDeck);

function runAtBattle(deck = relayDeck, seed = '測試種子') {
  const run = createRun({ deck: withFixedCards(deck), seed });
  assert.equal(visitNode(run, run.map[0][0].id).ok, true);
  return run;
}

function takeCard(run, cardId) {
  const handIndex = run.hand.findIndex((card) => card.cardId === cardId);
  if (handIndex >= 0) return run.hand[handIndex];
  const drawIndex = run.draw.findIndex((card) => card.cardId === cardId);
  assert.notEqual(drawIndex, -1, `找不到 ${cardId}`);
  const [card] = run.draw.splice(drawIndex, 1); run.hand.push(card); return card;
}

function clearEnemies(run) { run.enemies.forEach((enemy) => { enemy.hp = 0; }); }
function chooseNode(run, kind) { return run.map[run.step].find((node) => node.kind === kind); }

test('資料契約包含固定宇宙、38 張卡、十二種遺物與兩套牌', () => {
  assert.deepEqual(Object.keys(UNIVERSES), ['neutral', 'ninja', 'dragon', 'samurai']);
  assert.equal(CARDS.length, 38); assert.equal(RELICS.length, 12);
  const required = ['strike', 'defend', 'kunai_barrage', 'shadow_rush', 'spiral_strike', 'ki_blast', 'pressure_point', 'kame_wave', 'wooden_guard', 'sarcastic_counter', 'spirit_barrier', 'rift_assault', 'ninja_smoke', 'team_tactics', 'leaf_stance', 'shadow_insight', 'turtle_guard', 'saiyan_spirit', 'silver_resolve', 'umbrella_strike'];
  assert.deepEqual(CARDS.slice(0,20).map((card) => card.id), required);
  assert.deepEqual(PRESETS.map((preset) => preset.id), ['relay', 'adaptive']);
  assert.deepEqual(PRESETS.map((preset) => preset.deck.length), [10, 10]);
  const base = getCard('strike'); const upgraded = getCard('strike', 1); upgraded.effects[0].amount = 999;
  assert.equal(base.effects[0].amount, 6); assert.equal(getCard('strike', 1).effects[0].amount, 9); assert.equal(getCard('unknown'), undefined);
});

test('起始牌可只有兩張固定非基礎牌加八張基礎牌，候選池只剩兩種則拒絕', () => {
  const deck = ['kunai_barrage', 'venom_needle', ...Array(5).fill('strike'), ...Array(3).fill('defend')];
  const run = createRun({ deck, seed: '兩固定八基礎' });
  assert.equal(run.deck.filter((card) => card.fixed).length, 2); assertInvariants(run);
  const excluded = CARDS.filter((card) => !['strike', 'defend', 'kunai_barrage', 'venom_needle'].includes(card.id)).map((card) => card.id);
  assert.throws(() => createRun({ deck, seed: '兩候選', excludedCards: excluded }), /排除後至少需要 3 種/);
});

test('固定牌不可移除，但額外固定牌副本可移除', () => {
  const deck = ['kunai_barrage', 'kunai_barrage', 'venom_needle', ...Array(5).fill('strike'), ...Array(2).fill('defend')];
  const run = createRun({ deck, seed: '固定副本' });
  run.phase = 'shop'; run.shop = { cards: [], relic: null, removalPrice: 60, removed: false }; run.gold = 100;
  const primary = run.deck.find((card) => card.cardId === 'kunai_barrage' && card.fixed);
  const extra = run.deck.find((card) => card.cardId === 'kunai_barrage' && !card.fixed);
  const before = structuredClone(run); assert.deepEqual(removeCard(run, primary.uid), { ok: false, error: '角色固定牌不可移除。' }); assert.deepEqual(run, before);
  assert.equal(removeCard(run, extra.uid).ok, true); assert.equal(run.deck.some((card) => card.uid === primary.uid), true); assertInvariants(run);
});

test('固定種子重現地圖、敵人、意圖與起始牌序', () => {
  const a = createRun({ deck: relayDeck, seed: '同一裂縫' }); const b = createRun({ deck: relayDeck, seed: '同一裂縫' });
  assert.deepEqual(a.map, b.map); assert.equal(a.phase, 'map'); assert.deepEqual(a.map.map((layer) => layer.map((node) => node.kind)), [['battle'], ['battle', 'event'], ['camp', 'elite'], ['battle', 'shop'], ['event', 'elite'], ['camp', 'shop'], ['boss']]);
  assert.equal(visitNode(a, a.map[0][0].id).ok, true); assert.equal(visitNode(b, b.map[0][0].id).ok, true);
  assert.deepEqual(a.enemies, b.enemies); assert.deepEqual(a.hand, b.hand); assert.deepEqual(a.draw, b.draw);
});

test('無效選擇完全不改變狀態，區域 UID 不可遺失或增加', () => {
  const run = runAtBattle(); const card = run.hand.find((instance) => getCard(instance.cardId).target === 'enemy'); const before = structuredClone(run);
  assert.deepEqual(playCard(run, card.uid, '不存在'), { ok: false, error: '請選擇存活敵人。' }); assert.deepEqual(run, before);
  const removed = run.hand.pop(); assert.throws(() => assertInvariants(run), /卡牌區域不一致/); run.hand.push(removed); assertInvariants(run);
  run.hand.push({ uid: 'extra-card', cardId: 'strike', upgraded: 0 }); assert.throws(() => assertInvariants(run), /卡牌區域不一致/);
});

test('跨宇宙接力累積三點共鳴，強化只消耗舊共鳴並只加第一段', () => {
  const run = runAtBattle(relayDeck, '接力'); run.energy = 20; const enemy = run.enemies[0]; enemy.maxHp = 300; enemy.hp = 300;
  const play = (cardId, empowered = false) => { const card = takeCard(run, cardId); assert.equal(playCard(run, card.uid, enemy.id, empowered).ok, true); };
  play('kunai_barrage'); play('ki_blast'); play('kunai_barrage'); play('ki_blast');
  assert.equal(run.resonance, 3); assert.equal(run.currentUniverse, 'dragon'); assert.equal(run.lastUniverse, 'dragon');
  const hp = enemy.hp; play('strike', true); assert.equal(hp - enemy.hp, 10); assert.equal(run.resonance, 0); assert.equal(run.metrics.relays, 3); assert.equal(run.metrics.empowered, 1); assert.equal(run.currentUniverse, 'dragon');
  assert.match(run.log.join('\n'), /跨宇宙接力/); assertInvariants(run);
});

test('強化多段牌只在第一段加成，兩點共鳴與跨宇宙嘗試會原子失敗', () => {
  const deck = ['strike', 'strike', 'strike', 'defend', 'defend', 'defend', 'kunai_barrage', 'ki_blast', 'rift_assault', 'rift_assault'];
  const run = runAtBattle(deck, '多段強化'); run.energy = 20; const enemy = run.enemies[0]; enemy.maxHp = 300; enemy.hp = 300; run.resonance = 3;
  const kunai = takeCard(run, 'kunai_barrage'); const hp = enemy.hp; assert.equal(playCard(run, kunai.uid, enemy.id, true).ok, true); assert.equal(hp - enemy.hp, 13); assert.equal(run.resonance, 0);

  const rejected = runAtBattle(deck, '預充拒絕'); rejected.energy = 20; rejected.currentUniverse = 'ninja'; rejected.lastUniverse = 'ninja'; rejected.resonance = 2; const target = rejected.enemies[0]; const ki = takeCard(rejected, 'ki_blast'); const before = structuredClone(rejected);
  assert.deepEqual(playCard(rejected, ki.uid, target.id, true), { ok: false, error: '共鳴不足，無法強化。' }); assert.deepEqual(rejected, before); assertInvariants(rejected);
});

test('接力強化裂界合擊同時加傷害與格擋，接力透鏡各加到 6', () => {
  const deck = ['strike', 'strike', 'strike', 'defend', 'defend', 'defend', 'rift_assault', 'rift_assault', 'kunai_barrage', 'ki_blast'];
  const run = runAtBattle(deck, '合擊強化'); run.energy = 20; run.resonance = 3; const enemy = run.enemies[0]; enemy.maxHp = 300; enemy.hp = 300; const card = takeCard(run, 'rift_assault'); const hp = enemy.hp;
  assert.equal(playCard(run, card.uid, enemy.id, true).ok, true); assert.equal(hp - enemy.hp, 14); assert.equal(run.player.block, 10);

  const withLens = runAtBattle(deck, '透鏡強化'); withLens.energy = 20; withLens.resonance = 3; withLens.relics.push('relay_lens'); const lensEnemy = withLens.enemies[0]; lensEnemy.maxHp = 300; lensEnemy.hp = 300; const lensCard = takeCard(withLens, 'rift_assault'); const lensHp = lensEnemy.hp;
  assert.equal(playCard(withLens, lensCard.uid, lensEnemy.id, true).ok, true); assert.equal(lensHp - lensEnemy.hp, 16); assert.equal(withLens.player.block, 12); assertInvariants(withLens);
});

test('中立牌不打斷接力，跨戰鬥保留畫面宇宙但重置共鳴鏈', () => {
  const run = runAtBattle(relayDeck, '宇宙保留'); run.energy = 20; const enemy = run.enemies[0]; enemy.maxHp = 300; enemy.hp = 300;
  const ninja = takeCard(run, 'kunai_barrage'); assert.equal(playCard(run, ninja.uid, enemy.id).ok, true);
  const dragon = takeCard(run, 'ki_blast'); assert.equal(playCard(run, dragon.uid, enemy.id).ok, true);
  assert.equal(run.currentUniverse, 'dragon'); assert.equal(run.resonance, 1);
  const neutral = takeCard(run, 'strike'); assert.equal(playCard(run, neutral.uid, enemy.id).ok, true); assert.equal(run.currentUniverse, 'dragon'); assert.equal(run.resonance, 1);
  clearEnemies(run); assert.equal(endTurn(run).ok, true); assert.equal(run.phase, 'reward'); assert.equal(chooseReward(run, null).ok, true);
  assert.equal(visitNode(run, run.map[1].find((node) => node.kind === 'battle').id).ok, true); assert.equal(run.currentUniverse, 'dragon'); assert.equal(run.lastUniverse, null); assert.equal(run.resonance, 0);
});

test('敵方毒先扣血且能殺死敵人，死亡者不再執行攻擊；舊格擋在行動前消失', () => {
  const run = runAtBattle(relayDeck, '毒與格擋'); const enemy = run.enemies[0]; run.enemies.slice(1).forEach((other) => { other.hp = 0; });
  enemy.hp = 2; enemy.block = 20; enemy.poison = 3; enemy.intent = { kind: 'attack', label: '攻擊', amount: 50, hits: 1 };
  const playerHp = run.player.hp; assert.equal(endTurn(run).ok, true); assert.equal(run.phase, 'reward'); assert.equal(enemy.hp, 0); assert.equal(enemy.poison, 2); assert.equal(enemy.block, 0); assert.equal(run.player.hp, playerHp); assert.match(run.log.join('\n'), /無視格擋/);
});

test('生命歸零與荊棘同時發生時，失敗優先於擊殺', () => {
  const run = runAtBattle(relayDeck, '死亡荊棘'); const enemy = run.enemies[0]; run.enemies.slice(1).forEach((other) => { other.hp = 0; });
  run.player.hp = 1; run.player.thorns = 3; enemy.hp = 2; enemy.intent = { kind: 'attack', label: '攻擊', amount: 1, hits: 1 };
  assert.equal(endTurn(run).ok, true); assert.equal(run.player.hp, 0); assert.equal(enemy.hp, 0); assert.equal(run.phase, 'lost'); assert.match(run.log.join('\n'), /冒險結束/); assertInvariants(run);
});

test('弱化預告使用每段實際傷害，回合結束無固定攻擊且重置玩家資源', () => {
  const run = runAtBattle(relayDeck, '弱化'); const enemy = run.enemies[0]; run.enemies.slice(1).forEach((other) => { other.hp = 0; });
  enemy.weak = 2; enemy.intent = { kind: 'attack', label: '連續攻擊', amount: 8, hits: 2 }; run.player.block = 20;
  assert.equal(getIntentDamage(enemy), 6); const hp = enemy.hp; assert.equal(endTurn(run).ok, true); assert.equal(run.phase, 'battle'); assert.equal(enemy.hp, hp); assert.equal(enemy.weak, 1); assert.equal(run.player.block, 0); assert.equal(run.energy, 3); assert.equal(run.turn, 2); assert.equal(run.player.hp, run.player.maxHp); assertInvariants(run);
});

test('卡牌效果依序結算，力量、格擋與放逐在戰鬥內正確生效', () => {
  const deck = ['strike', 'defend', 'kunai_barrage', 'ki_blast', 'wooden_guard', 'rift_assault', 'team_tactics', 'leaf_stance', 'shadow_insight', 'turtle_guard'];
  const run = runAtBattle(deck, '效果順序'); run.energy = 20; const enemy = run.enemies[0]; enemy.maxHp = 300; enemy.hp = 300;
  const assault = takeCard(run, 'rift_assault'); assert.equal(playCard(run, assault.uid, enemy.id).ok, true); assert.equal(enemy.hp, 290); assert.equal(run.player.block, 6);
  const power = takeCard(run, 'leaf_stance'); assert.equal(playCard(run, power.uid).ok, true); assert.equal(run.player.strength, 2); assert.ok(run.exile.some((card) => card.uid === power.uid));
  const tactics = takeCard(run, 'team_tactics'); assert.equal(playCard(run, tactics.uid).ok, true); assert.equal(run.energy, 18); assert.ok(run.exile.some((card) => card.uid === tactics.uid)); assert.equal(playCard(run, tactics.uid).ok, false);
  assertInvariants(run);
});

test('獎勵、營火升級／休息、商店購買／移除與事件可推進七層路線', () => {
  const run = runAtBattle(relayDeck, '完整節點'); clearEnemies(run); assert.equal(endTurn(run).ok, true); assert.equal(run.phase, 'reward');
  const reward = run.rewards[0]; const activeCount = run._battleCardCount; assert.equal(chooseReward(run, reward).ok, true); assert.equal(run.phase, 'map'); assert.equal(run.step, 1); assert.equal(run.deck.length, 11); assert.equal(run._battleCardCount, activeCount);
  assert.equal(visitNode(run, chooseNode(run, 'event').id).ok, true); run.player.hp = 20; assert.equal(chooseEvent(run, 'risk').ok, true); assert.equal(run.player.hp, 12); assert.equal(run.relics.length, 1);
  assert.equal(visitNode(run, chooseNode(run, 'camp').id).ok, true); const upgradeUid = run.deck.find((card) => !card.upgraded).uid; assert.equal(upgradeCard(run, upgradeUid).ok, true); assert.equal(run.step, 3); assert.equal(run.deck.find((card) => card.uid === upgradeUid).upgraded, 1);
  assert.equal(visitNode(run, chooseNode(run, 'shop').id).ok, true); run.gold = 500; const offer = run.shop.cards[0]; assert.equal(buyCard(run, offer.id).ok, true); assert.equal(run.shop.cards[0].sold, true); if (run.shop.relic) assert.equal(buyRelic(run, run.shop.relic.id).ok, true); const removeUid = run.deck[0].uid; assert.equal(removeCard(run, removeUid).ok, true); assert.equal(run.shop.removed, true); assert.equal(leaveNode(run).ok, true); assert.equal(run.step, 4);
  assert.equal(visitNode(run, chooseNode(run, 'event').id).ok, true); run.player.hp = 20; assert.equal(chooseEvent(run, 'heal').ok, true); assert.equal(run.player.hp, 26);
  assert.equal(visitNode(run, chooseNode(run, 'camp').id).ok, true); run.player.hp = 20; assert.equal(rest(run).ok, true); assert.equal(run.player.hp, 38); assert.equal(run.step, 6);
  assert.equal(visitNode(run, run.map[6][0].id).ok, true); clearEnemies(run); assert.equal(endTurn(run).ok, true); assert.equal(run.phase, 'won'); const before = structuredClone(run); assert.deepEqual(endTurn(run), { ok: false, error: '目前不在戰鬥中。' }); assert.deepEqual(run, before); assertInvariants(run);
});

test('失敗的商店與事件操作完全不改變狀態', () => {
  const shopRun = runAtBattle(relayDeck, '商店原子'); clearEnemies(shopRun); assert.equal(endTurn(shopRun).ok, true); assert.equal(chooseReward(shopRun, null).ok, true);
  assert.equal(visitNode(shopRun, chooseNode(shopRun, 'battle').id).ok, true); clearEnemies(shopRun); assert.equal(endTurn(shopRun).ok, true); assert.equal(chooseReward(shopRun, null).ok, true);
  assert.equal(visitNode(shopRun, chooseNode(shopRun, 'camp').id).ok, true); assert.equal(leaveNode(shopRun).ok, true); assert.equal(visitNode(shopRun, chooseNode(shopRun, 'shop').id).ok, true); shopRun.gold = 0;
  const cardBefore = structuredClone(shopRun); assert.deepEqual(buyCard(shopRun, shopRun.shop.cards[0].id), { ok: false, error: '金幣不足。' }); assert.deepEqual(shopRun, cardBefore);
  const relicBefore = structuredClone(shopRun); assert.deepEqual(buyRelic(shopRun, shopRun.shop.relic.id), { ok: false, error: '金幣不足。' }); assert.deepEqual(shopRun, relicBefore);
  const removeBefore = structuredClone(shopRun); assert.deepEqual(removeCard(shopRun, shopRun.deck[0].uid), { ok: false, error: '金幣不足。' }); assert.deepEqual(shopRun, removeBefore);

  const eventRun = runAtBattle(relayDeck, '事件原子'); clearEnemies(eventRun); assert.equal(endTurn(eventRun).ok, true); assert.equal(chooseReward(eventRun, null).ok, true); assert.equal(visitNode(eventRun, chooseNode(eventRun, 'event').id).ok, true); eventRun.player.hp = 8;
  const eventBefore = structuredClone(eventRun); assert.deepEqual(chooseEvent(eventRun, 'risk'), { ok: false, error: '生命必須大於 8 才能承擔風險。' }); assert.deepEqual(eventRun, eventBefore); assert.deepEqual(chooseEvent(eventRun, 'bad'), { ok: false, error: '事件選擇無效。' }); assert.deepEqual(eventRun, eventBefore); assertInvariants(eventRun);
});

test('菁英勝利給遺物，遺物與戰利品都由種子決定', () => {
  const run = runAtBattle(relayDeck, '菁英'); clearEnemies(run); assert.equal(endTurn(run).ok, true); assert.equal(chooseReward(run, null).ok, true);
  assert.equal(visitNode(run, chooseNode(run, 'event').id).ok, true); assert.equal(chooseEvent(run, 'heal').ok, true); assert.equal(visitNode(run, chooseNode(run, 'elite').id).ok, true); clearEnemies(run); assert.equal(endTurn(run).ok, true);
  assert.equal(run.phase, 'reward'); assert.equal(run.gold, 145); assert.equal(run.relics.length, 1); assert.equal(run.rewards.length, 3); assertInvariants(run);
});

test('開戰遺物在第一回合提供格擋，升級資料不會污染原卡', () => {
  const run = createRun({ deck: relayDeck, seed: '開戰遺物' }); run.relics.push('opening_guard'); assert.equal(visitNode(run, run.map[0][0].id).ok, true); assert.equal(run.player.block, 8); assert.equal(getCard('defend', 0).effects[0].amount, 5); assert.equal(getCard('defend', 1).effects[0].amount, 8); assertInvariants(run);
});
