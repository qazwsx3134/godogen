import { CARDS, RELICS, UNIVERSES, CHARACTERS, ARCHETYPES, POTIONS, getCard, isBasicCard } from './data.js';

const CARD_BY_ID = new Map(CARDS.map((card) => [card.id, card]));
const RELIC_BY_ID = new Map(RELICS.map((relic) => [relic.id, relic]));
const PHASES = new Set(['map', 'battle', 'reward', 'camp', 'shop', 'event', 'won', 'lost']);
const UNIVERSE_KEYS = new Set(Object.keys(UNIVERSES));
const BASIC_COPY_LIMIT = 5;
const CARD_COPY_LIMIT = 2;
const MAP_LAYOUT = [
  [{ kind: 'battle', label: '裂界伏擊', description: '普通敵人把旅人逼入第一條裂縫。' }],
  [
    { kind: 'battle', label: '宇宙交界戰', description: '迎戰混合敵群，取得新的接力牌。' },
    { kind: 'event', label: '裂界傳聞', description: '冒險者的傳聞帶來恢復或遺物的誘惑。' },
  ],
  [
    { kind: 'camp', label: '火堆營地', description: '恢復生命，或把一張牌鍛造成更高版本。' },
    { kind: 'elite', label: '菁英守門者', description: '高風險戰鬥，勝利可取得遺物。' },
  ],
  [
    { kind: 'battle', label: '裂界巷戰', description: '敵人的意圖開始交錯，牌組需要更精準。' },
    { kind: 'shop', label: '黑市攤位', description: '用金幣購買技能、遺物，或移除一張牌。' },
  ],
  [
    { kind: 'event', label: '跨界契約', description: '以生命換取遺物，或保守地回復生命。' },
    { kind: 'elite', label: '宇宙裂口', description: '最後一場菁英戰，獎勵豐厚但沒有退路。' },
  ],
  [
    { kind: 'camp', label: '終局營火', description: '首領前最後一次恢復或升級。' },
    { kind: 'shop', label: '終局商會', description: '用最後金幣整理牌組與遺物。' },
  ],
  [{ kind: 'boss', label: '裂界霸王', description: '穿越三種宇宙的首領，擊敗它即可完成登塔。' }],
];

const NORMAL_ENCOUNTERS = {
  0: [
    [{ id: 'paper_scout', name: '紙傘斥候', maxHp: 38, attack: 6 }, { id: 'cursed_mite', name: '咒靈小鬼', maxHp: 28, attack: 5 }],
    [{ id: 'leaf_raider', name: '木葉浪客', maxHp: 46, attack: 5 }],
  ],
  1: [
    [{ id: 'rogue_ninja', name: '流浪忍者', maxHp: 54, attack: 7 }, { id: 'street_curse', name: '街角咒靈', maxHp: 38, attack: 6 }],
    [{ id: 'ki_bandit', name: '氣功盜賊', maxHp: 68, attack: 8 }],
  ],
  3: [
    [{ id: 'rift_raider', name: '裂界掠奪者', maxHp: 82, attack: 9 }, { id: 'rift_medic', name: '裂界術士', maxHp: 48, attack: 7 }],
    [{ id: 'rift_raider', name: '裂界掠奪者', maxHp: 105, attack: 10 }],
  ],
};

const ELITE_ENCOUNTERS = {
  2: [
    [{ id: 'armored_samurai', name: '鎧甲武士', maxHp: 78, attack: 9 }, { id: 'mask_curse', name: '面具咒靈', maxHp: 54, attack: 7 }],
    [{ id: 'armored_samurai', name: '鎧甲武士', maxHp: 112, attack: 10 }],
  ],
  4: [
    [{ id: 'rift_raider_elite', name: '裂界掠奪者王', maxHp: 108, attack: 11 }, { id: 'rift_medic_elite', name: '裂界術士王', maxHp: 72, attack: 9 }],
    [{ id: 'rift_raider_elite', name: '裂界掠奪者王', maxHp: 145, attack: 12 }],
  ],
};

const BOSS_ENCOUNTER = [{ id: 'rift_overlord', name: '裂界霸王', maxHp: 205, attack: 12 }];

function hashSeed(seed) {
  let hash = 2166136261;
  for (const character of String(seed)) { hash ^= character.charCodeAt(0); hash = Math.imul(hash, 16777619); }
  return hash >>> 0 || 1;
}

function random(run) {
  let value = run._rng >>> 0;
  value ^= value << 13; value ^= value >>> 17; value ^= value << 5;
  run._rng = value >>> 0;
  return run._rng / 4294967296;
}

function randomIndex(run, length) { return Math.floor(random(run) * length); }

function shuffle(run, items) {
  for (let index = items.length - 1; index > 0; index -= 1) {
    const other = randomIndex(run, index + 1);
    [items[index], items[other]] = [items[other], items[index]];
  }
}

function result(ok, error) { return ok ? { ok: true } : { ok: false, error }; }
function addLog(run, text) { run.log.push(text); if (run.log.length > 150) run.log.splice(0, run.log.length - 150); }
function livingEnemies(run) { return run.enemies.filter((enemy) => enemy.hp > 0); }
function hasRelic(run, id) { return run.relics.includes(id); }
function cardCopies(deck) {
  const counts = new Map();
  for (const instance of deck) counts.set(instance.cardId, (counts.get(instance.cardId) ?? 0) + 1);
  return counts;
}

function validateDeckIds(deck, character, excludedCards = []) {
  if (!Array.isArray(deck) || deck.length !== 10) return '牌組必須正好有 10 張牌。';
  if (!Array.isArray(excludedCards)) return '排除牌必須是陣列。';
  const excluded = new Set();
  for (const id of excludedCards) {
    if (!CARD_BY_ID.has(id)) return `未知排除卡牌：${id}。`;
    if (excluded.has(id)) return '排除牌不可重複。';
    excluded.add(id);
  }
  const fixedCards = character?.fixedCards ?? [];
  if (fixedCards.some((id) => excluded.has(id))) return '角色固定牌不可排除。';
  if (fixedCards.some((id) => !deck.includes(id))) return '牌組必須包含角色的全部固定牌。';
  if (deck.some((id) => excluded.has(id))) return '牌組不可包含排除牌。';
  const counts = new Map();
  for (const id of deck) {
    if (!CARD_BY_ID.has(id)) return `未知卡牌：${id}。`;
    counts.set(id, (counts.get(id) ?? 0) + 1);
  }
  for (const [id, count] of counts) {
    const limit = isBasicCard(id) ? BASIC_COPY_LIMIT : CARD_COPY_LIMIT;
    if (count > limit) return `${getCard(id).name} 最多只能放 ${limit} 張。`;
  }
  if (CARDS.filter((card) => !isBasicCard(card.id) && !excluded.has(card.id)).length < 3) return '排除後至少需要 3 種非基礎獎勵牌。';
  return null;
}

function makeMap() {
  return MAP_LAYOUT.map((layer, step) => layer.map((node, index) => ({ ...node, id: `node-${step}-${index}`, visited: false })));
}

function makeDeck(deckIds, fixedCards = []) {
  const fixed = new Set(fixedCards); const seenFixed = new Set();
  return deckIds.map((cardId, index) => {
    const isFixed = fixed.has(cardId) && !seenFixed.has(cardId);
    if (isFixed) seenFixed.add(cardId);
    return { uid: `deck-${index + 1}`, cardId, upgraded: 0, fixed: isFixed };
  });
}
function cloneInstance(instance) { return { uid: instance.uid, cardId: instance.cardId, upgraded: instance.upgraded ? 1 : 0, fixed: !!instance.fixed }; }
function zoneCards(run) { return [run.hand, run.draw, run.discard, run.exile, run.resolving].flat(); }

function setIntent(run, enemy) {
  const roll = random(run);
  const boss = run.currentNode?.kind === 'boss';
  if ((boss && roll > 0.84) || (!boss && roll > 0.88)) {
    enemy.intent = { kind: 'buff', label: '強化攻勢', amount: boss ? 3 : 2, hits: 1 };
  } else if (roll < (boss ? 0.18 : 0.23)) {
    enemy.intent = { kind: 'defend', label: '防禦', amount: boss ? 12 : 7, hits: 1 };
  } else {
    const hits = roll > (boss ? 0.66 : 0.74) ? 2 : 1;
    enemy.intent = { kind: 'attack', label: hits === 2 ? '連續攻擊' : '攻擊', amount: enemy.attack, hits };
  }
}

export function getIntentDamage(enemy) {
  if (!enemy?.intent || enemy.intent.kind !== 'attack') return 0;
  return enemy.weak > 0 ? Math.floor(enemy.intent.amount * 0.75) : enemy.intent.amount;
}

function encounterTemplates(run) {
  if (run.currentNode?.kind === 'boss') return BOSS_ENCOUNTER;
  const table = run.currentNode?.kind === 'elite' ? ELITE_ENCOUNTERS : NORMAL_ENCOUNTERS;
  const options = table[run.step] ?? NORMAL_ENCOUNTERS[3];
  return options[randomIndex(run, options.length)];
}

function makeEnemies(run) {
  return encounterTemplates(run).map((base, index) => {
    const enemy = { ...base, id: `${base.id}-${run.step}-${index}`, hp: base.maxHp, block: 0, poison: 0, weak: 0, intent: null };
    setIntent(run, enemy);
    return enemy;
  });
}

function drawCards(run, count) {
  for (let drawn = 0; drawn < count && run.hand.length < 10; drawn += 1) {
    if (!run.draw.length) {
      if (!run.discard.length) break;
      run.draw.push(...run.discard.splice(0)); shuffle(run, run.draw); addLog(run, '棄牌堆已洗回抽牌堆。');
    }
    run.hand.push(run.draw.pop());
  }
}

function resetBattle(run) {
  run.phase = 'battle'; run.turn = 1; run.energy = 3;
  run.hand = []; run.draw = run.deck.map(cloneInstance); run.discard = []; run.exile = []; run.resolving = [];
  run._battleCardUids = run.draw.map((instance) => instance.uid); run._battleCardCount = run._battleCardUids.length;
  run.player.block = 0; run.player.strength = 0; run.player.thorns = 0; run.player.charge=0; run.player.exhaustGuard=0; resetTurnTraits(run);
  // The visual theme carries into the next encounter; the relay chain itself does not.
  run.lastUniverse = null; run.resonance = 0;
  run.enemies = makeEnemies(run); shuffle(run, run.draw); drawCards(run, 5);
  if (hasRelic(run, 'opening_guard')) { run.player.block += 8; addLog(run, '開界護符：戰鬥開始獲得 8 點格擋。'); }
  if(hasRelic(run,'ki_orb'))gainCharge(run,2);
  addLog(run, `第 ${run.step + 1} 層戰鬥開始。`);
}

function advanceToNextMap(run) {
  run.step += 1; run.phase = 'map'; run.currentNode = null; run.rewards = []; run.shop = null;
  if (run.step > 6) { run.phase = 'won'; addLog(run, '已完成裂界登塔。'); }
}

function targetEnemies(run, card, target) {
  if (card.target === 'all' || target?.target === 'all') return livingEnemies(run);
  return target ? [target] : [];
}

function dealEnemyDamage(run, enemy, amount, source) {
  if (!enemy || enemy.hp <= 0) return 0;
  const raw = Math.max(0, Math.floor(amount)); const absorbed = Math.min(enemy.block, raw); enemy.block -= absorbed;
  const hpLoss = Math.min(enemy.hp, raw - absorbed); enemy.hp -= hpLoss; run.metrics.damageDealt += hpLoss;
  addLog(run, `${source}對 ${enemy.name} 造成 ${raw} 點傷害${absorbed ? `（格擋吸收 ${absorbed}）` : ''}。`);
  if (enemy.hp <= 0) addLog(run, `${enemy.name} 被擊敗。`);
  return hpLoss;
}

function dealPlayerDamage(run, amount, source) {
  const raw = Math.max(0, Math.floor(amount)); const absorbed = Math.min(run.player.block, raw); run.player.block -= absorbed;
  const hpLoss = Math.min(run.player.hp, raw - absorbed); run.player.hp -= hpLoss; run.metrics.damageTaken += hpLoss;
  addLog(run, `${source}造成 ${raw} 點傷害${absorbed ? `（格擋吸收 ${absorbed}）` : ''}。`);
  if (run.player.hp <= 0) { run.player.hp = 0; run.phase = 'lost'; addLog(run, '裂界旅人生命歸零，冒險結束。'); }
  return hpLoss;
}

function applyPoison(run, enemy) {
  if (enemy.poison <= 0 || enemy.hp <= 0) return;
  const amount = enemy.poison; const hpLoss = Math.min(enemy.hp, amount); enemy.hp -= hpLoss; run.metrics.damageDealt += hpLoss;
  enemy.poison = Math.max(0, enemy.poison - 1);
  addLog(run, `${enemy.name} 的毒造成 ${hpLoss} 點傷害（無視格擋）。`);
  if (enemy.hp <= 0) addLog(run, `${enemy.name} 被毒擊敗。`);
}

function effectTargets(run, card, effect, target) {
  if (card.target === 'all' || effect.target === 'all') return livingEnemies(run);
  if (card.target === 'enemy') return target ? [target] : [];
  return [];
}

function resolveEffect(run, card, effect, target, context) {
  switch (effect.op) {
    case 'damage': {
      const enemies = effectTargets(run, card, effect, target);
      let chargeBonus=0;
      if(effect.spendCharge){context.chargeSpent=(context.chargeSpent||0)+run.player.charge;chargeBonus=run.player.charge*(effect.chargeMultiplier||0);addLog(run,`消耗${run.player.charge}蓄氣，傷害加成${chargeBonus}。`);run.player.charge=0;}
      for (const enemy of enemies) {
        for (let hit = 0; hit < (effect.hits ?? 1) && enemy.hp > 0; hit += 1) {
          const bonus = context.damageBonus > 0 && !context.damageBoostUsed ? context.damageBonus : 0; context.damageBoostUsed = true;
          dealEnemyDamage(run, enemy, effect.amount + run.player.strength + bonus + chargeBonus + run.player.block*(effect.blockMultiplier||0), '卡牌'); chargeBonus=0;
        }
      }
      break;
    }
    case 'block': {
      const bonus = context.blockBonus > 0 && !context.blockBoostUsed ? context.blockBonus : 0;
      context.blockBoostUsed = true; run.player.block += effect.amount + bonus;
      addLog(run, `裂界旅人獲得 ${effect.amount + bonus} 點格擋。`); break;
    }
    case 'draw': drawCards(run, effect.amount); addLog(run, `抽取 ${effect.amount} 張牌。`); break;
    case 'energy': run.energy += effect.amount; addLog(run, `獲得 ${effect.amount} 點能量。`); break;
    case 'weak': {
      for (const enemy of effectTargets(run, card, effect, target)) { enemy.weak += effect.amount; addLog(run, `${enemy.name} 虛弱 ${effect.amount} 層。`); }
      break;
    }
    case 'poison': {
      const poisonedTargets=effectTargets(run,card,effect,target).filter(e=>e.hp>0);if(!poisonedTargets.length)break;
      const bonus=hasRelic(run,'venom_fang')&&!run._turn.poison?2:0;run._turn.poison=true;
      for (const enemy of poisonedTargets) { enemy.poison += effect.amount+bonus; addLog(run, `${enemy.name} 中毒 ${effect.amount+bonus} 層${bonus?'（毒牙墜飾+2）':''}。`); }
      break;
    }
    case 'charge': gainCharge(run,effect.amount);break;
    case 'resonance': run.resonance=Math.min(3,run.resonance+effect.amount);addLog(run,`共鳴增加，目前${run.resonance}/3。`);break;
    case 'exhaust_guard': run.player.exhaustGuard+=effect.amount;addLog(run,`本場每次放逐獲得${run.player.exhaustGuard}格擋。`);break;
    case 'poison_multiply': for(const enemy of effectTargets(run,card,effect,target).filter(e=>e.hp>0)){enemy.poison*=effect.amount;addLog(run,`${enemy.name}的毒變為${enemy.poison}層。`);}break;
    case 'strength': run.player.strength += effect.amount; addLog(run, `力量提升 ${effect.amount}。`); break;
    case 'thorns': run.player.thorns += effect.amount; addLog(run, `荊棘提升 ${effect.amount}。`); break;
    case 'exhaust': run._exhaustResolving = true; addLog(run, '此牌本場戰鬥放逐。'); break;
    default: throw new Error(`未知效果：${effect.op}`);
  }
}

function registerUniverse(run, universe) {
  if (universe === 'neutral') return;
  const previous = run.lastUniverse;
  run.currentUniverse = universe;
  if (previous && previous !== universe) {
    run.resonance = Math.min(3, run.resonance + 1); run.metrics.relays += 1;
    if(hasRelic(run,'relay_scroll')&&!run._turn.relay){run._turn.relay=true;drawCards(run,1);addLog(run,'越界卷軸：本回合首次接力抽1張。');}
    addLog(run, `跨宇宙接力：${UNIVERSES[previous].name} → ${UNIVERSES[universe].name}，共鳴 ${run.resonance}/3。`);
  }
  run.lastUniverse = universe;
}

function finishBattle(run) {
  if (run.phase !== 'battle') return true;
  if (!run.player.hp) { run.phase = 'lost'; addLog(run, '裂界旅人生命歸零，冒險結束。'); return true; }
  if (livingEnemies(run).length) return false;
  run.metrics.battlesWon += 1;
  const isBoss = run.currentNode?.kind === 'boss';
  if (isBoss) { run.phase = 'won'; addLog(run, '裂界霸王已敗，冒險勝利！'); return true; }
  const isElite = run.currentNode?.kind === 'elite';
  const gold = isElite ? 40 : 25;
  run.gold += gold; addLog(run, `戰鬥勝利，獲得 ${gold} 金幣。`);
  if (hasRelic(run, 'healing_charm')) { run.player.hp = Math.min(run.player.maxHp, run.player.hp + 3); addLog(run, '回生御守：恢復 3 點生命。'); }
  if (hasRelic(run, 'bounty_seal')) { run.gold += 15; addLog(run, '賞金印記：戰利品額外獲得 15 金幣。'); }
  if (isElite) grantEliteRelic(run);
  if(isElite||random(run)<.4)dropPotion(run);
  run.rewards = randomRewards(run); run.phase = 'reward'; addLog(run, '選擇一張戰利品，或跳過。');
  return true;
}

function randomRewards(run) {
  const excluded = new Set(run.excludedCards ?? []);
  const pool=CARDS.filter(c=>!isBasicCard(c.id) && !excluded.has(c.id));const picked=[];
  const character=CHARACTERS.find(c=>c.id===run.characterId);
  const build=getBuildSummary(run)[0]?.id;
  const filters=[c=>c.tags.some(t=>character.builds.includes(t)),c=>c.tags.includes(build),c=>!picked.some(p=>p.universe===c.universe)];
  for(const [index,filter] of filters.entries()){
    const remaining=pool.filter(c=>!picked.includes(c));
    if(!remaining.length)break;
    const match=index===2&&random(run)<.25?remaining:remaining.filter(filter);
    picked.push(weightedPick(run,match.length?match:remaining,c=>({common:3,uncommon:2,rare:1}[c.rarity])));
  }
  return picked.map(c=>c.id);
}

function grantEliteRelic(run) {
  const pool = RELICS.filter((relic) => !run.relics.includes(relic.id));
  if (!pool.length) { run.gold += 30; addLog(run, '菁英獎勵：遺物已收集完畢，改得 30 金幣。'); return; }
  const relic = pickRelic(run,pool); run.relics.push(relic.id); run.metrics.relicsGained += 1; addLog(run, `菁英獎勵：獲得遺物「${relic.name}」。`);
}

function resolveEnemyIntent(run, enemy) {
  if (enemy.hp <= 0) return;
  if (enemy.block > 0) { addLog(run, `${enemy.name} 上回合的格擋消失。`); enemy.block = 0; }
  applyPoison(run, enemy);
  if (enemy.hp <= 0 || run.phase !== 'battle') return;
  const intent = enemy.intent;
  if (intent.kind === 'attack') {
    for (let hit = 0; hit < intent.hits && run.player.hp > 0 && enemy.hp > 0; hit += 1) {
      dealPlayerDamage(run, getIntentDamage(enemy), `${enemy.name} 的${intent.label}`);
      if (run.player.thorns > 0 && enemy.hp > 0) dealEnemyDamage(run, enemy, run.player.thorns, '荊棘反傷');
    }
  } else if (intent.kind === 'defend') {
    enemy.block += intent.amount; addLog(run, `${enemy.name} 獲得 ${intent.amount} 點格擋。`);
  } else if (intent.kind === 'buff') {
    enemy.attack += intent.amount; addLog(run, `${enemy.name} 的攻擊提升 ${intent.amount}。`);
  }
  enemy.weak = Math.max(0, enemy.weak - 1);
}

function makeShop(run) {
  const cards = randomRewards(run);
  const relics = RELICS.filter((relic) => !run.relics.includes(relic.id));
  return {
    cards: cards.slice(0, 3).map((id) => ({ id, price: 50, sold: false })),
    relic: relics.length ? { id: pickRelic(run,relics).id, price: 100, sold: false } : null,
    removalPrice: 60,
    removed: false,
  };
}

function addDeckCard(run, cardId) {
  const instance = { uid: `deck-${run._nextUid++}`, cardId, upgraded: 0, fixed: false }; run.deck.push(instance); run.metrics.cardsAdded += 1; return instance;
}

function resetTurnTraits(run) {
  run._turn = { attacks:0, heavy:false, guard:false, poison:false, relay:false, ashHeals:0 };
}
function gainCharge(run, amount) {
  const gained=Math.min(9-run.player.charge,amount); run.player.charge+=gained;
  addLog(run, `蓄氣 +${gained}，目前 ${run.player.charge}/9。`);
}
function afterCard(run,card,context,exiled) {
  const turn=run._turn;
  const trigger=text=>{run.metrics.traitTriggers++;addLog(run,`職業特性：${text}`);};
  if(card.type==='attack') {
    turn.attacks++;
    if(turn.attacks===3) {
      if(run.characterId==='shadow_ninja'){drawCards(run,1);trigger('影分身節奏，第三張攻擊抽1張。');}
      if(hasRelic(run,'combo_bracer')){run.player.block+=3;addLog(run,'連擊腕帶：第三張攻擊獲得3格擋。');}
    }
  }
  if(card.cost>=2&&!turn.heavy){turn.heavy=true;if(run.characterId==='ki_fighter'){gainCharge(run,2);trigger('氣息循環，首次重費出牌獲得2蓄氣。');}}
  if(card.effects.some(e=>e.op==='block')&&!turn.guard){
    turn.guard=true;
    if(run.characterId==='silver_ronin'){run.player.block+=3;trigger('萬事屋架勢，首次格擋牌額外獲得3格擋。');}
    if(hasRelic(run,'guard_knot')){run.player.block+=2;addLog(run,'守勢繩結：首次格擋牌額外獲得2格擋。');}
  }
  if(context.chargeSpent&&hasRelic(run,'ki_shell')){run.player.block+=context.chargeSpent;addLog(run,`氣甲碎片：獲得${context.chargeSpent}格擋。`);}
  if(exiled){
    if(run.player.exhaustGuard){run.player.block+=run.player.exhaustGuard;addLog(run,`灰燼護持：放逐獲得${run.player.exhaustGuard}格擋。`);}
    if(hasRelic(run,'ash_heart')&&turn.ashHeals<2){turn.ashHeals++;run.player.hp=Math.min(run.player.maxHp,run.player.hp+1);addLog(run,'餘燼之心：放逐恢復1生命。');}
  }
}
export function getBuildSummary(run) {
  return Object.entries(ARCHETYPES).map(([id,build])=>({id,...build,count:run.deck.filter(c=>getCard(c.cardId)?.tags.includes(id)).length}))
    .filter(b=>b.count>0).sort((a,b)=>b.count-a.count);
}
export function getLootHint(run,cardId){
  const card=getCard(cardId); if(!card)return '';
  const current=getBuildSummary(run).find(b=>card.tags.includes(b.id));
  if(current)return `牌組連動 · ${current.name} ${current.count}張：${current.payoff}`;
  const character=CHARACTERS.find(c=>c.id===run.characterId);
  const affinity=character.builds.find(id=>card.tags.includes(id));
  return affinity?`職業契合 · ${ARCHETYPES[affinity].payoff}`:`跨界新方向 · ${card.tags.map(id=>ARCHETYPES[id]?.name).filter(Boolean).join('／')||'通用攻防'}`;
}
function weightedPick(run,pool,weight){
  const total=pool.reduce((n,c)=>n+weight(c),0);let roll=random(run)*total;
  for(const item of pool){roll-=weight(item);if(roll<0)return item;}return pool.at(-1);
}
function pickRelic(run,pool){
  const tags=getBuildSummary(run).slice(0,2).map(b=>b.id);
  return weightedPick(run,pool,r=>1+(r.tags.some(t=>tags.includes(t))?2:0));
}
function dropPotion(run){
  if(run.potions.length>=2){run.gold+=10;addLog(run,'消耗品背包已滿，戰利品改為10金幣。');return;}
  const potion=POTIONS[randomIndex(run,POTIONS.length)];
  run.potions.push({uid:`potion-${run._nextPotionUid++}`,potionId:potion.id});addLog(run,`獲得消耗品「${potion.name}」。`);
}
export function usePotion(run,uid,targetId=null){
  if(run?.phase!=='battle')return result(false,'消耗品只能在戰鬥使用。');
  const instance=run.potions.find(p=>p.uid===uid);if(!instance)return result(false,'找不到這瓶消耗品。');
  const potion=POTIONS.find(p=>p.id===instance.potionId);
  const target=potion.target==='enemy'?run.enemies.find(e=>e.id===targetId&&e.hp>0):null;
  if(potion.target==='enemy'&&!target)return result(false,'請選擇存活敵人。');
  if(potion.target!=='enemy'&&targetId!==null)return result(false,'此消耗品不需要目標。');
  run.potions.splice(run.potions.indexOf(instance),1);run.metrics.potionsUsed++;
  addLog(run,`使用消耗品「${potion.name}」。`);
  for(const effect of potion.effects)resolveEffect(run,potion,effect,target,{damageBonus:0,blockBonus:0});
  finishBattle(run);assertInvariants(run);return result(true);
}

export function createRun({ deck, seed, characterId='shadow_ninja', excludedCards=[] } = {}) {
  const character=CHARACTERS.find(c=>c.id===characterId);if(!character)throw Error('未知角色。');
  const deckError = validateDeckIds(deck, character, excludedCards); if (deckError) throw new Error(deckError);
  if (typeof seed !== 'string') throw new Error('seed 必須是字串。');
  const persistentDeck = makeDeck(deck, character.fixedCards);
  const run = {
    phase: 'map', step: 0, seed, currentNode: null, map: makeMap(),
    characterId, excludedCards: [...excludedCards], player: { name: character.name, hp: character.maxHp, maxHp: character.maxHp, block: 0, strength: 0, thorns: 0, charge:0,exhaustGuard:0 }, gold: 70, relics: [],
    potions:[{uid:'potion-1',potionId:character.starterPotion}],_nextPotionUid:2,
    deck: persistentDeck, hand: [], draw: [], discard: [], exile: [], resolving: [], enemies: [],
    turn: 0, energy: 0, currentUniverse: character.universe, lastUniverse: null, resonance: 0,
    rewards: [], shop: null, log: [], metrics: { traitTriggers:0,potionsUsed:0,cardsPlayed: 0, damageDealt: 0, damageTaken: 0, battlesWon: 0, relays: 0, empowered: 0, cardsAdded: 0, cardsUpgraded: 0, cardsRemoved: 0, relicsGained: 0, nodesVisited: 0, rests: 0, events: 0, purchases: 0 },
    _rng: hashSeed(seed), _nextUid: persistentDeck.length + 1, _battleCardUids: [], _battleCardCount: 0, _battleNodeKind: null, _exhaustResolving: false,
  };
  resetTurnTraits(run);assertInvariants(run); return run;
}

export function visitNode(run, nodeId) {
  if (run?.phase !== 'map') return result(false, '目前不在地圖選路。');
  const layer = run.map[run.step]; const node = layer?.find((candidate) => candidate.id === nodeId);
  if (!node || node.visited) return result(false, '此節點不可選擇。');
  node.visited = true; run.currentNode = node; run.metrics.nodesVisited += 1; run._battleNodeKind = node.kind;
  if (node.kind === 'battle' || node.kind === 'elite' || node.kind === 'boss') resetBattle(run);
  else if (node.kind === 'camp') { run.phase = 'camp'; addLog(run, '抵達營火：選擇休息、升級或離開。'); }
  else if (node.kind === 'shop') { run.phase = 'shop'; run.shop = makeShop(run); addLog(run, '抵達商店：可購買卡牌、遺物或移除一張牌。'); }
  else { run.phase = 'event'; addLog(run, '抵達事件：選擇承擔風險或恢復生命。'); }
  assertInvariants(run); return result(true);
}

export function playCard(run, uid, targetId = null, empowered = false) {
  if (run?.phase !== 'battle') return result(false, '目前不在戰鬥中。');
  const instance = run.hand.find((card) => card.uid === uid); if (!instance) return result(false, '此牌不在手牌中。');
  const card = getCard(instance.cardId, instance.upgraded); if (!card) return result(false, '此牌資料不存在。');
  if (run.energy < card.cost) return result(false, '能量不足。');
  if (empowered !== true && empowered !== false) return result(false, '強化參數無效。');
  let target = null;
  if (card.target === 'enemy') { target = run.enemies.find((enemy) => enemy.id === targetId && enemy.hp > 0); if (!target) return result(false, '請選擇存活敵人。'); }
  else if (card.target === 'all') { if (targetId !== null) return result(false, '全體卡不需要目標。'); if (!livingEnemies(run).length) return result(false, '沒有可攻擊的敵人。'); }
  else if (targetId !== null) return result(false, '此牌不需要目標。');
  const empowerable = card.effects.some((effect) => effect.op === 'damage' || effect.op === 'block');
  if (empowered && (!empowerable || run.resonance < 3)) return result(false, empowerable ? '共鳴不足，無法強化。' : '此牌不能被接力強化。');

  run.hand.splice(run.hand.indexOf(instance), 1); run.resolving.push(instance); run.energy -= card.cost;
  if (empowered) { run.resonance -= 3; run.metrics.empowered += 1; addLog(run, `接力強化「${card.name}」，消耗 3 點共鳴。`); }
  run.metrics.cardsPlayed += 1; run._exhaustResolving = card.type === 'power';
  addLog(run, `使用「${card.name}」（消耗 ${card.cost} 能量）。`);
  const context = { damageBonus: empowered ? 4 + (hasRelic(run, 'relay_lens') ? 2 : 0) : 0, blockBonus: empowered ? 4 + (hasRelic(run, 'relay_lens') ? 2 : 0) : 0, damageBoostUsed: false, blockBoostUsed: false };
  for (const effect of card.effects) resolveEffect(run, card, effect, target, context);
  registerUniverse(run, card.universe);
  run.resolving.splice(run.resolving.indexOf(instance), 1); (run._exhaustResolving ? run.exile : run.discard).push(instance); const exiled=run._exhaustResolving; run._exhaustResolving = false;
  afterCard(run,card,context,exiled);
  finishBattle(run); assertInvariants(run); return result(true);
}

export function endTurn(run) {
  if (run?.phase !== 'battle') return result(false, '目前不在戰鬥中。');
  run.discard.push(...run.hand.splice(0));
  if (finishBattle(run)) { assertInvariants(run); return result(true); }
  if(hasRelic(run,'venom_incense')&&livingEnemies(run).some(e=>e.poison>0)){run.player.block+=3;addLog(run,'毒霧香爐：獲得3格擋。');}
  for (const enemy of [...run.enemies]) {
    if (enemy.hp <= 0) continue;
    resolveEnemyIntent(run, enemy);
    if (run.phase === 'lost' || finishBattle(run)) { assertInvariants(run); return result(true); }
  }
  if (run.phase !== 'battle') { assertInvariants(run); return result(true); }
  run.player.block = 0; run.turn += 1; run.energy = 3;resetTurnTraits(run);
  for (const enemy of livingEnemies(run)) setIntent(run, enemy);
  drawCards(run, 5); addLog(run, `第 ${run.turn} 回合開始：恢復 3 點能量並抽 5 張牌。`);
  assertInvariants(run); return result(true);
}

export function chooseReward(run, cardId = null) {
  if (run?.phase !== 'reward') return result(false, '目前沒有可選戰利品。');
  if (cardId !== null && !run.rewards.includes(cardId)) return result(false, '此卡不在戰利品中。');
  if (cardId !== null && run.excludedCards.includes(cardId)) return result(false, '此卡已被排除。');
  if (cardId !== null && !CARD_BY_ID.has(cardId)) return result(false, '此卡資料不存在。');
  if (cardId !== null) { addDeckCard(run, cardId); addLog(run, `獲得本局技能「${getCard(cardId).name}」。`); }
  else addLog(run, '略過戰利品。');
  advanceToNextMap(run); assertInvariants(run); return result(true);
}

export function rest(run) {
  if (run?.phase !== 'camp') return result(false, '目前不在營火。');
  const heal = Math.ceil(run.player.maxHp * 0.25); const before = run.player.hp; run.player.hp = Math.min(run.player.maxHp, run.player.hp + heal); run.metrics.rests += 1;
  addLog(run, `營火休息：恢復 ${run.player.hp - before} 點生命。`); advanceToNextMap(run); assertInvariants(run); return result(true);
}

export function upgradeCard(run, uid) {
  if (run?.phase !== 'camp') return result(false, '目前不在營火。');
  const instance = run.deck.find((card) => card.uid === uid); if (!instance) return result(false, '找不到這張牌。');
  if (instance.upgraded) return result(false, '這張牌已經升級。');
  instance.upgraded = 1; run.metrics.cardsUpgraded += 1; addLog(run, `升級「${getCard(instance.cardId).name}」。`); advanceToNextMap(run); assertInvariants(run); return result(true);
}

export function buyCard(run, cardId) {
  if (run?.phase !== 'shop' || !run.shop) return result(false, '目前不在商店。');
  const offer = run.shop.cards.find((card) => card.id === cardId); if (!offer || offer.sold) return result(false, '此卡已售出或不在商店。');
  if (run.excludedCards.includes(cardId)) return result(false, '此卡已被排除。');
  if (!CARD_BY_ID.has(cardId)) return result(false, '此卡資料不存在。');
  if (run.gold < offer.price) return result(false, '金幣不足。');
  run.gold -= offer.price; offer.sold = true; addDeckCard(run, cardId); run.metrics.purchases += 1; addLog(run, `購買「${getCard(cardId).name}」。`); assertInvariants(run); return result(true);
}

export function buyRelic(run, relicId) {
  if (run?.phase !== 'shop' || !run.shop) return result(false, '目前不在商店。');
  const offer = run.shop.relic; if (!offer || offer.id !== relicId || offer.sold) return result(false, '此遺物已售出或不在商店。');
  if (run.relics.includes(relicId)) return result(false, '已持有此遺物。');
  if (run.gold < offer.price) return result(false, '金幣不足。');
  run.gold -= offer.price; offer.sold = true; run.relics.push(relicId); run.metrics.relicsGained += 1; run.metrics.purchases += 1; addLog(run, `購買遺物「${RELIC_BY_ID.get(relicId).name}」。`); assertInvariants(run); return result(true);
}

export function removeCard(run, uid) {
  if (run?.phase !== 'shop' || !run.shop) return result(false, '目前不在商店。');
  if (run.shop.removed) return result(false, '移除服務已使用。');
  if (run.deck.length <= 1) return result(false, '牌組至少要保留一張牌。');
  const index = run.deck.findIndex((card) => card.uid === uid); if (index < 0) return result(false, '找不到這張牌。');
  if (run.deck[index].fixed) return result(false, '角色固定牌不可移除。');
  if (run.gold < run.shop.removalPrice) return result(false, '金幣不足。');
  const [removed] = run.deck.splice(index, 1); run.gold -= run.shop.removalPrice; run.shop.removed = true; run.metrics.cardsRemoved += 1; addLog(run, `移除「${getCard(removed.cardId).name}」。`); assertInvariants(run); return result(true);
}

export function leaveNode(run) {
  if (run?.phase !== 'camp' && run?.phase !== 'shop') return result(false, '目前不能離開節點。');
  addLog(run, run.phase === 'shop' ? '離開商店。' : '離開營火。'); advanceToNextMap(run); assertInvariants(run); return result(true);
}

export function chooseEvent(run, choice) {
  if (run?.phase !== 'event') return result(false, '目前沒有事件。');
  if (choice !== 'risk' && choice !== 'heal') return result(false, '事件選擇無效。');
  if (choice === 'risk') {
    if (run.player.hp <= 8) return result(false, '生命必須大於 8 才能承擔風險。');
    run.player.hp -= 8; const pool = RELICS.filter((relic) => !run.relics.includes(relic.id));
    if (!pool.length) { run.gold += 30; addLog(run, '風險事件：遺物已收集完畢，改得 30 金幣。'); }
    else { const relic=pickRelic(run,pool);run.relics.push(relic.id); run.metrics.relicsGained += 1; addLog(run, `風險事件：以 8 點生命取得「${relic.name}」。`); }
  } else { const before = run.player.hp; run.player.hp = Math.min(run.player.maxHp, run.player.hp + 6); addLog(run, `事件療癒：恢復 ${run.player.hp - before} 點生命。`); }
  run.metrics.events += 1; advanceToNextMap(run); assertInvariants(run); return result(true);
}

export function assertInvariants(run) {
  if (!run || !PHASES.has(run.phase)) throw new Error('無效 phase。');
  const character = CHARACTERS.find((item) => item.id === run.characterId);
  if (!character) throw Error('無效角色。');
  if (!Array.isArray(run.excludedCards)) throw Error('無效排除牌。');
  const excluded = new Set(run.excludedCards);
  if (excluded.size !== run.excludedCards.length || run.excludedCards.some((id) => !CARD_BY_ID.has(id))) throw Error('無效排除牌。');
  if (character.fixedCards.some((id) => excluded.has(id))) throw Error('固定牌不可排除。');
  if (CARDS.filter((card) => !isBasicCard(card.id) && !excluded.has(card.id)).length < 3) throw Error('排除後可獲得卡牌不足。');
  if(!run.player || !Number.isInteger(run.player.charge)||run.player.charge<0||run.player.charge>9||!Number.isFinite(run.player.exhaustGuard)||run.player.exhaustGuard<0)throw Error('無效職業資源。');
  if(!Array.isArray(run.potions)||run.potions.length>2||new Set(run.potions.map(p=>p.uid)).size!==run.potions.length||run.potions.some(p=>!POTIONS.some(d=>d.id===p.potionId)))throw Error('無效消耗品。');
  if (!Number.isInteger(run.step) || run.step < 0 || run.step > 6) throw new Error('無效地圖層數。');
  if (!Array.isArray(run.map) || run.map.length !== 7) throw new Error('無效地圖。');
  const nodeIds = run.map.flat().map((node) => node.id); if (new Set(nodeIds).size !== nodeIds.length) throw new Error('地圖節點重複。');
  if (run.currentNode && !nodeIds.includes(run.currentNode.id)) throw new Error('目前節點不存在。');
  if (!run.player || !Number.isFinite(run.player.hp) || !Number.isFinite(run.player.maxHp) || run.player.hp < 0 || run.player.hp > run.player.maxHp || run.player.block < 0 || run.player.strength < 0 || run.player.thorns < 0) throw new Error('無效玩家數值。');
  if (!Number.isFinite(run.gold) || run.gold < 0 || !Number.isFinite(run.energy) || run.energy < 0 || !Number.isInteger(run.resonance) || run.resonance < 0 || run.resonance > 3) throw new Error('無效資源數值。');
  if (!UNIVERSE_KEYS.has(run.currentUniverse) || (run.lastUniverse !== null && !UNIVERSE_KEYS.has(run.lastUniverse))) throw new Error('無效宇宙狀態。');
  if (!Array.isArray(run.relics) || new Set(run.relics).size !== run.relics.length || run.relics.some((id) => !RELIC_BY_ID.has(id))) throw new Error('無效遺物。');
  if (!Array.isArray(run.deck) || run.deck.length < 1) throw new Error('牌組不可為空。');
  const fixedSet = new Set(character.fixedCards); const fixedSeen = new Set();
  const deckUids = run.deck.map((card) => card.uid);
  if (new Set(deckUids).size !== deckUids.length || run.deck.some((card) => !CARD_BY_ID.has(card.cardId) || ![0, 1].includes(card.upgraded) || typeof card.fixed !== 'boolean' || excluded.has(card.cardId))) throw new Error('牌組實例不一致。');
  for (const card of run.deck) {
    if (fixedSet.has(card.cardId)) {
      const expected = !fixedSeen.has(card.cardId); fixedSeen.add(card.cardId);
      if (card.fixed !== expected) throw new Error('固定牌實例順序不一致。');
    } else if (card.fixed) throw new Error('非固定牌不可標記固定。');
  }
  if ([...fixedSet].some((id) => !fixedSeen.has(id))) throw new Error('牌組缺少角色固定牌。');
  const zones = [run.hand, run.draw, run.discard, run.exile, run.resolving]; if (zones.some((zone) => !Array.isArray(zone))) throw new Error('卡牌區域不存在。');
  const activeCards = zones.flat(); const activeUids = activeCards.map((card) => card.uid); const registered = Array.isArray(run._battleCardUids) ? new Set(run._battleCardUids) : null;
  const deckByUid = new Map(run.deck.map((card) => [card.uid, card]));
  if (!Number.isInteger(run._battleCardCount) || run._battleCardCount < 0 || !registered || registered.size !== run._battleCardCount || run._battleCardUids.length !== run._battleCardCount || activeCards.length !== run._battleCardCount || new Set(activeUids).size !== activeUids.length || activeUids.some((uid) => !registered.has(uid)) || activeCards.some((card) => !CARD_BY_ID.has(card.cardId) || ![0, 1].includes(card.upgraded) || typeof card.fixed !== 'boolean')) throw new Error('卡牌區域不一致。');
  for (const card of activeCards) {
    const persistent = deckByUid.get(card.uid);
    // 營火升級發生在上一場戰鬥的區域快照之後；下一場 resetBattle
    // 會刷新 upgraded，當下仍須維持 UID、卡牌與 fixed 身分一致。
    if (persistent && (persistent.cardId !== card.cardId || persistent.fixed !== card.fixed)) throw new Error('卡牌實例不一致。');
  }
  if (!Array.isArray(run.enemies)) throw new Error('敵人資料不存在。');
  for (const enemy of run.enemies) if (!Number.isFinite(enemy.hp) || !Number.isFinite(enemy.maxHp) || enemy.hp < 0 || enemy.hp > enemy.maxHp || enemy.block < 0 || enemy.poison < 0 || enemy.weak < 0 || !enemy.intent) throw new Error('無效敵人數值。');
  if (run.phase === 'battle' && (!run.currentNode || !['battle', 'elite', 'boss'].includes(run.currentNode.kind) || run.turn < 1 || run.enemies.length < 1)) throw new Error('戰鬥狀態不一致。');
  if (run.phase === 'reward' && (!run.currentNode || !['battle', 'elite'].includes(run.currentNode.kind) || run.rewards.length !== 3 || new Set(run.rewards).size !== 3 || run.rewards.some((id) => !CARD_BY_ID.has(id) || isBasicCard(id) || excluded.has(id)))) throw new Error('戰利品狀態不一致。');
  if (run.phase === 'shop' && (!run.shop || new Set(run.shop.cards.map((card) => card.id)).size !== run.shop.cards.length || run.shop.cards.some((card) => !CARD_BY_ID.has(card.id) || isBasicCard(card.id) || excluded.has(card.id)))) throw new Error('商店狀態不一致。');
}
