export const UNIVERSES = {
  neutral: { name: '旅人', label: '裂界' },
  ninja: { name: '火影', label: '忍術' },
  dragon: { name: '七龍珠', label: '氣功' },
  samurai: { name: '銀魂', label: '武士' },
};

const BASIC_IDS = new Set(['strike', 'defend']);

export const CARDS = [
  { id: 'strike', name: '裂界斬', type: 'attack', universe: 'neutral', cost: 1, target: 'enemy', text: '對一名敵人造成 6 點傷害。', effects: [{ op: 'damage', amount: 6 }], upgrade: { text: '對一名敵人造成 9 點傷害。', effects: [{ op: 'damage', amount: 9 }] } },
  { id: 'defend', name: '旅人防禦', type: 'skill', universe: 'neutral', cost: 1, target: 'self', text: '獲得 5 點格擋。', effects: [{ op: 'block', amount: 5 }], upgrade: { text: '獲得 8 點格擋。', effects: [{ op: 'block', amount: 8 }] } },
  { id: 'kunai_barrage', name: '苦無連投', type: 'attack', universe: 'ninja', cost: 1, target: 'enemy', text: '對一名敵人造成 3 段、每段 3 點傷害。', effects: [{ op: 'damage', amount: 3, hits: 3 }], upgrade: { text: '對一名敵人造成 3 段、每段 4 點傷害。', effects: [{ op: 'damage', amount: 4, hits: 3 }] } },
  { id: 'shadow_rush', name: '影分身突擊', type: 'attack', universe: 'ninja', cost: 2, target: 'enemy', text: '對一名敵人造成 4 段、每段 4 點傷害。', effects: [{ op: 'damage', amount: 4, hits: 4 }], upgrade: { text: '對一名敵人造成 4 段、每段 5 點傷害。', effects: [{ op: 'damage', amount: 5, hits: 4 }] } },
  { id: 'spiral_strike', name: '螺旋衝擊', type: 'attack', universe: 'ninja', cost: 2, target: 'enemy', text: '對一名敵人造成 18 點傷害。', effects: [{ op: 'damage', amount: 18 }], upgrade: { text: '對一名敵人造成 24 點傷害。', effects: [{ op: 'damage', amount: 24 }] } },
  { id: 'ki_blast', name: '氣功彈', type: 'attack', universe: 'dragon', cost: 1, target: 'enemy', text: '對一名敵人造成 10 點傷害。', effects: [{ op: 'damage', amount: 10 }], upgrade: { text: '對一名敵人造成 14 點傷害。', effects: [{ op: 'damage', amount: 14 }] } },
  { id: 'pressure_point', name: '點穴破綻', type: 'skill', universe: 'dragon', cost: 1, target: 'enemy', text: '對一名敵人造成 3 點傷害並施加 2 層虛弱。', effects: [{ op: 'damage', amount: 3 }, { op: 'weak', amount: 2 }], upgrade: { text: '對一名敵人造成 6 點傷害並施加 3 層虛弱。', effects: [{ op: 'damage', amount: 6 }, { op: 'weak', amount: 3 }] } },
  { id: 'kame_wave', name: '龜派氣功', type: 'attack', universe: 'dragon', cost: 3, target: 'all', text: '對所有敵人造成 17 點傷害。', effects: [{ op: 'damage', amount: 17, target: 'all' }], upgrade: { text: '對所有敵人造成 24 點傷害。', effects: [{ op: 'damage', amount: 24, target: 'all' }] } },
  { id: 'wooden_guard', name: '木刀格擋', type: 'skill', universe: 'samurai', cost: 1, target: 'self', text: '獲得 8 點格擋。', effects: [{ op: 'block', amount: 8 }], upgrade: { text: '獲得 12 點格擋。', effects: [{ op: 'block', amount: 12 }] } },
  { id: 'sarcastic_counter', name: '吐槽反擊', type: 'skill', universe: 'samurai', cost: 1, target: 'self', text: '獲得 6 點格擋與 3 點荊棘；荊棘在本場戰鬥持續，每次受擊反傷。', effects: [{ op: 'block', amount: 6 }, { op: 'thorns', amount: 3 }], upgrade: { text: '獲得 9 點格擋與 5 點荊棘；荊棘在本場戰鬥持續，每次受擊反傷。', effects: [{ op: 'block', amount: 9 }, { op: 'thorns', amount: 5 }] } },
  { id: 'spirit_barrier', name: '銀魂護幕', type: 'skill', universe: 'samurai', cost: 2, target: 'self', text: '獲得 15 點格擋。', effects: [{ op: 'block', amount: 15 }], upgrade: { text: '獲得 20 點格擋。', effects: [{ op: 'block', amount: 20 }] } },
  { id: 'rift_assault', name: '裂界合擊', type: 'attack', universe: 'neutral', cost: 2, target: 'enemy', text: '對一名敵人造成 10 點傷害，並獲得 6 點格擋。', effects: [{ op: 'damage', amount: 10 }, { op: 'block', amount: 6 }], upgrade: { text: '對一名敵人造成 14 點傷害，並獲得 8 點格擋。', effects: [{ op: 'damage', amount: 14 }, { op: 'block', amount: 8 }] } },
  { id: 'ninja_smoke', name: '忍法煙幕', type: 'skill', universe: 'ninja', cost: 1, target: 'enemy', text: '獲得 5 點格擋，並使一名敵人虛弱 2 層。', effects: [{ op: 'block', amount: 5 }, { op: 'weak', amount: 2 }], upgrade: { text: '獲得 8 點格擋，並使一名敵人虛弱 3 層。', effects: [{ op: 'block', amount: 8 }, { op: 'weak', amount: 3 }] } },
  { id: 'team_tactics', name: '跨界戰術', type: 'skill', universe: 'neutral', cost: 0, target: 'none', text: '抽 2 張牌、獲得 1 點能量，並放逐此牌。', effects: [{ op: 'draw', amount: 2 }, { op: 'energy', amount: 1 }, { op: 'exhaust' }], upgrade: { text: '抽 3 張牌、獲得 1 點能量，並放逐此牌。', effects: [{ op: 'draw', amount: 3 }, { op: 'energy', amount: 1 }, { op: 'exhaust' }] } },
  { id: 'leaf_stance', name: '木葉架勢', type: 'power', universe: 'ninja', cost: 1, target: 'none', text: '本場戰鬥獲得 2 點力量。', effects: [{ op: 'strength', amount: 2 }], upgrade: { text: '本場戰鬥獲得 3 點力量。', effects: [{ op: 'strength', amount: 3 }] } },
  { id: 'shadow_insight', name: '影之洞察', type: 'power', universe: 'ninja', cost: 1, target: 'none', text: '抽 2 張牌並獲得 4 點格擋；此牌本場戰鬥放逐。', effects: [{ op: 'draw', amount: 2 }, { op: 'block', amount: 4 }], upgrade: { text: '抽 3 張牌並獲得 6 點格擋；此牌本場戰鬥放逐。', effects: [{ op: 'draw', amount: 3 }, { op: 'block', amount: 6 }] } },
  { id: 'turtle_guard', name: '龜派守勢', type: 'power', universe: 'dragon', cost: 2, target: 'none', text: '本場戰鬥獲得 2 點荊棘與 6 點格擋。', effects: [{ op: 'thorns', amount: 2 }, { op: 'block', amount: 6 }], upgrade: { text: '本場戰鬥獲得 3 點荊棘與 10 點格擋。', effects: [{ op: 'thorns', amount: 3 }, { op: 'block', amount: 10 }] } },
  { id: 'saiyan_spirit', name: '賽亞人意志', type: 'power', universe: 'dragon', cost: 2, target: 'none', text: '本場戰鬥獲得 3 點力量。', effects: [{ op: 'strength', amount: 3 }], upgrade: { text: '本場戰鬥獲得 5 點力量。', effects: [{ op: 'strength', amount: 5 }] } },
  { id: 'silver_resolve', name: '銀魂覺悟', type: 'power', universe: 'samurai', cost: 1, target: 'none', text: '本場戰鬥獲得 3 點荊棘。', effects: [{ op: 'thorns', amount: 3 }], upgrade: { text: '本場戰鬥獲得 5 點荊棘。', effects: [{ op: 'thorns', amount: 5 }] } },
  { id: 'umbrella_strike', name: '傘下突擊', type: 'attack', universe: 'samurai', cost: 1, target: 'enemy', text: '對一名敵人造成 7 點傷害，並使其虛弱 1 層。', effects: [{ op: 'damage', amount: 7 }, { op: 'weak', amount: 1 }], upgrade: { text: '對一名敵人造成 10 點傷害，並使其虛弱 2 層。', effects: [{ op: 'damage', amount: 10 }, { op: 'weak', amount: 2 }] } },
];

export const RELICS = [
  { id: 'opening_guard', name: '開界護符', text: '每場戰鬥開始時獲得 8 點格擋。' },
  { id: 'healing_charm', name: '回生御守', text: '每場非首領戰鬥勝利後恢復 3 點生命。' },
  { id: 'relay_lens', name: '接力透鏡', text: '接力強化的第一段傷害或第一個格擋額外 +2。' },
  { id: 'bounty_seal', name: '賞金印記', text: '獲得卡牌戰利品時額外取得 15 金幣。' },
];

export const ARCHETYPES = {
  combo: { name: '連擊力量', description: '多段攻擊搭配力量，每段都獲得加成。', payoff: '力量 → 多段攻擊 → 連擊收益' },
  poison: { name: '毒術消耗', description: '疊毒、弱化拖延，再將毒層翻倍。', payoff: '施毒 → 格擋拖延 → 毒層翻倍' },
  charge: { name: '蓄氣爆發', description: '蓄氣跨回合保留，上限9，選時機消耗爆發。', payoff: '蓄氣 → 保留到下回合 → 氣功終結' },
  guard: { name: '格擋反擊', description: '格擋換取生存，荊棘或盾擊轉為傷害。', payoff: '疊格擋 → 盾擊／荊棘反傷' },
  exhaust: { name: '放逐循環', description: '放逐牌縮小抽牌循環，觸發格擋與遺物。', payoff: '放逐護持 → 放逐抽牌 → 精簡循環' },
  relay: { name: '跨界共鳴', description: '交替宇宙累積共鳴，強化關鍵的攻防牌。', payoff: '跨宇宙接力 → 3共鳴 → 雙效強化' },
};
const extra = (id,name,type,universe,cost,target,tags,text,effects,upgradeText,upEffects,rarity='uncommon') =>
  ({id,name,type,universe,cost,target,tags,rarity,text,effects,upgrade:{text:upgradeText,effects:upEffects}});
CARDS.push(
  extra('venom_needle','毒針','attack','ninja',1,'enemy',['poison','combo'],'造成4傷害，施加3毒。',[{op:'damage',amount:4},{op:'poison',amount:3}],'造成6傷害，施加4毒。',[{op:'damage',amount:6},{op:'poison',amount:4}],'common'),
  extra('toxic_mist','毒霧結界','skill','samurai',1,'enemy',['poison','guard'],'獲得6格擋，施加2毒。',[{op:'block',amount:6},{op:'poison',amount:2}],'獲得9格擋，施加3毒。',[{op:'block',amount:9},{op:'poison',amount:3}]),
  extra('venom_bloom','毒華綻放','skill','ninja',2,'enemy',['poison'],'使目標目前的毒層翻倍。',[{op:'poison_multiply',amount:2}],'使目標目前的毒層變為3倍。',[{op:'poison_multiply',amount:3}],'rare'),
  extra('ki_focus','凝氣','skill','dragon',1,'self',['charge','guard'],'獲得3蓄氣與5格擋。',[{op:'charge',amount:3},{op:'block',amount:5}],'獲得4蓄氣與7格擋。',[{op:'charge',amount:4},{op:'block',amount:7}],'common'),
  extra('meteor_release','流星氣功','attack','dragon',2,'enemy',['charge'],'造成8傷害；消耗全部蓄氣，每點額外造成3傷害。',[{op:'damage',amount:8,chargeMultiplier:3,spendCharge:true}],'造成12傷害；消耗全部蓄氣，每點額外造成4傷害。',[{op:'damage',amount:12,chargeMultiplier:4,spendCharge:true}],'rare'),
  extra('charged_blade','氣刃守勢','attack','samurai',1,'enemy',['charge','guard'],'造成7傷害，獲得1蓄氣與4格擋。',[{op:'damage',amount:7},{op:'charge',amount:1},{op:'block',amount:4}],'造成10傷害，獲得2蓄氣與6格擋。',[{op:'damage',amount:10},{op:'charge',amount:2},{op:'block',amount:6}]),
  extra('shield_bash','木刀盾擊','attack','samurai',1,'enemy',['guard'],'造成3加上目前格擋值的傷害；不消耗格擋。',[{op:'damage',amount:3,blockMultiplier:1}],'造成6加上目前格擋值的傷害；不消耗格擋。',[{op:'damage',amount:6,blockMultiplier:1}]),
  extra('iron_wall','鐵壁之誓','skill','dragon',2,'self',['guard','charge'],'獲得16格擋與2蓄氣。',[{op:'block',amount:16},{op:'charge',amount:2}],'獲得22格擋與3蓄氣。',[{op:'block',amount:22},{op:'charge',amount:3}]),
  extra('thorn_oath','棘刃誓言','power','samurai',1,'self',['guard','exhaust'],'本場獲得2荊棘，並獲得7格擋；放逐。',[{op:'thorns',amount:2},{op:'block',amount:7}],'本場獲得3荊棘，並獲得10格擋；放逐。',[{op:'thorns',amount:3},{op:'block',amount:10}]),
  extra('ash_aegis','灰燼護持','power','samurai',1,'self',['exhaust','guard'],'本場每有卡進入放逐就獲得3格擋，包含此牌。',[{op:'exhaust_guard',amount:3}],'本場每有卡進入放逐就獲得5格擋，包含此牌。',[{op:'exhaust_guard',amount:5}],'rare'),
  extra('burning_notes','燃燼手札','skill','ninja',0,'none',['exhaust','combo'],'抽2張牌，放逐。',[{op:'draw',amount:2},{op:'exhaust'}],'抽3張牌，放逐。',[{op:'draw',amount:3},{op:'exhaust'}],'common'),
  extra('last_stand','捨身一閃','attack','samurai',1,'enemy',['exhaust','relay'],'造成13傷害，獲得1共鳴，放逐。',[{op:'damage',amount:13},{op:'resonance',amount:1},{op:'exhaust'}],'造成18傷害，獲得1共鳴，放逐。',[{op:'damage',amount:18},{op:'resonance',amount:1},{op:'exhaust'}]),
  extra('flash_jab','瞬身拳','attack','ninja',0,'enemy',['combo','exhaust'],'造成5傷害，放逐。',[{op:'damage',amount:5},{op:'exhaust'}],'造成8傷害，放逐。',[{op:'damage',amount:8},{op:'exhaust'}],'common'),
  extra('battle_rhythm','戰鬥律動','skill','dragon',1,'self',['combo','charge'],'本場力量+1，獲得2蓄氣，放逐。',[{op:'strength',amount:1},{op:'charge',amount:2},{op:'exhaust'}],'本場力量+2，獲得3蓄氣，放逐。',[{op:'strength',amount:2},{op:'charge',amount:3},{op:'exhaust'}]),
  extra('blade_flurry','亂刃四連','attack','samurai',1,'enemy',['combo'],'造成4段、每段2傷害。',[{op:'damage',amount:2,hits:4}],'造成4段、每段3傷害。',[{op:'damage',amount:3,hits:4}],'common'),
  extra('rift_spark','裂界火種','skill','dragon',1,'self',['relay','charge'],'獲得1共鳴、2蓄氣與4格擋。',[{op:'resonance',amount:1},{op:'charge',amount:2},{op:'block',amount:4}],'獲得1共鳴、3蓄氣與7格擋。',[{op:'resonance',amount:1},{op:'charge',amount:3},{op:'block',amount:7}]),
  extra('echo_guard','迴響護身','skill','ninja',1,'self',['relay','guard'],'獲得7格擋與1共鳴。',[{op:'block',amount:7},{op:'resonance',amount:1}],'獲得10格擋與1共鳴。',[{op:'block',amount:10},{op:'resonance',amount:1}],'common'),
  extra('world_step','越界步法','skill','samurai',0,'none',['relay','exhaust'],'抽1張牌、獲得1共鳴，放逐。',[{op:'draw',amount:1},{op:'resonance',amount:1},{op:'exhaust'}],'抽2張牌、獲得1共鳴，放逐。',[{op:'draw',amount:2},{op:'resonance',amount:1},{op:'exhaust'}])
);
const oldTags={kunai_barrage:['combo'],shadow_rush:['combo'],spiral_strike:['charge'],ki_blast:['charge'],pressure_point:['poison'],kame_wave:['charge'],wooden_guard:['guard'],sarcastic_counter:['guard'],spirit_barrier:['guard'],rift_assault:['relay','guard'],ninja_smoke:['poison','guard'],team_tactics:['exhaust','combo'],leaf_stance:['combo'],shadow_insight:['exhaust'],turtle_guard:['guard'],saiyan_spirit:['combo','charge'],silver_resolve:['guard'],umbrella_strike:['combo','poison']};
for(const card of CARDS) { card.tags ??= oldTags[card.id] || []; card.rarity ??= card.type==='power' ? 'uncommon' : 'common'; }
RELICS.push(
  {id:'combo_bracer',name:'連擊腕帶',tags:['combo','guard'],text:'每回合第三張攻擊牌結算後獲得3格擋。'},
  {id:'venom_fang',name:'毒牙墜飾',tags:['poison'],text:'每回合第一次施毒額外增加2毒（翻倍不算施毒）。'},
  {id:'ki_orb',name:'氣息寶珠',tags:['charge'],text:'每場戰鬥開始獲得2蓄氣。'},
  {id:'guard_knot',name:'守勢繩結',tags:['guard'],text:'每回合第一張含格擋效果的牌結算後額外獲得2格擋。'},
  {id:'ash_heart',name:'餘燼之心',tags:['exhaust'],text:'卡牌放逐時恢復1生命，每回合最多觸發2次。'},
  {id:'relay_scroll',name:'越界卷軸',tags:['relay','combo'],text:'每回合第一次跨宇宙接力後抽1張牌。'},
  {id:'venom_incense',name:'毒霧香爐',tags:['poison','guard'],text:'敵方回合開始時，若仍有中毒敵人，獲得3格擋。'},
  {id:'ki_shell',name:'氣甲碎片',tags:['charge','guard'],text:'消耗蓄氣的卡結算後，每消耗1蓄氣獲得1格擋。'}
);
const relicTags={opening_guard:['guard'],healing_charm:['exhaust'],relay_lens:['relay'],bounty_seal:[]};
for(const relic of RELICS) relic.tags ??= relicTags[relic.id] || [];
export const POTIONS=[
  {id:'venom_flask',name:'毒霧瓶',text:'對一名敵人施加6毒。',target:'enemy',effects:[{op:'poison',amount:6}]},
  {id:'energy_tonic',name:'氣力藥',text:'獲得1能量。',target:'self',effects:[{op:'energy',amount:1}]},
  {id:'guard_tonic',name:'護身藥',text:'獲得12格擋。',target:'self',effects:[{op:'block',amount:12}]},
];
export const CHARACTERS=[
  {id:'shadow_ninja',name:'影丸',job:'忍者',universe:'ninja',maxHp:72,traitName:'影分身節奏',traitText:'每回合第三張攻擊牌結算後抽1張（每回合限一次）。',builds:['combo','poison'],fixedCards:['kunai_barrage','venom_needle'],deck:['strike','strike','strike','defend','defend','defend','kunai_barrage','venom_needle','flash_jab','toxic_mist'],starterPotion:'venom_flask'},
  {id:'ki_fighter',name:'空悟',job:'武鬥家',universe:'dragon',maxHp:76,traitName:'氣息循環',traitText:'每回合第一張費用至少2的牌結算後獲得2蓄氣。',builds:['charge','combo'],fixedCards:['ki_focus','meteor_release'],deck:['strike','strike','strike','defend','defend','defend','ki_focus','meteor_release','ki_blast','kunai_barrage'],starterPotion:'energy_tonic'},
  {id:'silver_ronin',name:'銀桑',job:'浪人',universe:'samurai',maxHp:80,traitName:'萬事屋架勢',traitText:'每回合第一張含格擋效果的牌結算後額外獲得3格擋。',builds:['guard','exhaust'],fixedCards:['wooden_guard','shield_bash'],deck:['strike','strike','strike','defend','defend','defend','wooden_guard','shield_bash','ash_aegis','burning_notes'],starterPotion:'guard_tonic'},
];

const CARD_BY_ID = new Map(CARDS.map((card) => [card.id, card]));

function copyEffects(effects) { return effects.map((effect) => ({ ...effect })); }

export function getCard(id, upgraded = 0) {
  const card = CARD_BY_ID.get(id);
  if (!card) return undefined;
  const result = { ...card, tags:[...card.tags], effects: copyEffects(card.effects), upgrade: { ...card.upgrade, effects: copyEffects(card.upgrade.effects) }, upgraded: upgraded ? 1 : 0 };
  if (upgraded) {
    result.cost = card.upgrade.cost ?? card.cost;
    result.text = card.upgrade.text;
    result.effects = copyEffects(card.upgrade.effects);
  }
  return result;
}

export const PRESETS = [
  { id: 'relay', name: '跨界接力', description: '以火影多段與七龍珠爆發交替累積共鳴，主動強化關鍵攻擊。', deck: ['strike', 'strike', 'strike', 'defend', 'defend', 'defend', 'kunai_barrage', 'kunai_barrage', 'ki_blast', 'ki_blast'] },
  { id: 'adaptive', name: '適應架勢', description: '用多段攻擊、虛弱與格擋穩住局面，再以接力尋找反攻窗口。', deck: ['strike', 'strike', 'strike', 'defend', 'defend', 'defend', 'kunai_barrage', 'ki_blast', 'wooden_guard', 'pressure_point'] },
];

export function isBasicCard(id) { return BASIC_IDS.has(id); }
