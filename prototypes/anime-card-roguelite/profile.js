import { CARDS, PRESETS, CHARACTERS, isBasicCard } from './data.js';

export const STORAGE_KEY = 'rift-cards.profile.v3';
const V2_KEY = 'rift-cards.profile.v2';
const LEGACY_KEY = 'rift-cards.profile.v1';
const LEGACY_IDS = {
  cursed_bolt: 'ki_blast', fault_seal: 'pressure_point', domain_crush: 'kame_wave',
  mirror_ward: 'ninja_smoke', leaf_ninja: 'leaf_stance', copy_ninja: 'shadow_insight',
  barrier_sorcerer: 'turtle_guard', cursed_striker: 'saiyan_spirit',
  silver_samurai: 'silver_resolve', umbrella_hunter: 'umbrella_strike',
};
const CARD_BY_ID = new Map(CARDS.map((card) => [card.id, card]));
const cap = id => ['strike', 'defend'].includes(id) ? 5 : 2;
const known = id => typeof id === 'string' && CARD_BY_ID.has(id);
const fail = error => ({ ok: false, error });
const count = ids => ids.reduce((result, id) => {
  result[id] = (result[id] || 0) + 1;
  return result;
}, Object.create(null));

function characterFor(characterId) { return CHARACTERS.find((character) => character.id === characterId); }

function mapId(id, version) {
  return version === 1 && Object.hasOwn(LEGACY_IDS, id) ? LEGACY_IDS[id] : id;
}

function validateLoadout(profile, deck, excludedCards, characterId = profile?.characterId) {
  if (!profile || !profile.collection || typeof profile.collection !== 'object' || Array.isArray(profile.collection)) {
    return '收藏資料無效。';
  }
  if (!Array.isArray(deck) || deck.length !== 10 || deck.some((id) => !known(id))) {
    return '起始牌組必須剛好十張已知卡牌。';
  }
  if (!Array.isArray(excludedCards)) return '排除牌必須是陣列。';
  const excluded = new Set();
  for (const id of excludedCards) {
    if (!known(id)) return `未知排除卡牌：${id}。`;
    if (excluded.has(id)) return '排除牌不可重複。';
    excluded.add(id);
  }
  const character = characterFor(characterId);
  if (!character) return '找不到這名角色。';
  if (character.fixedCards.some((id) => excluded.has(id))) return '角色固定牌不可排除。';
  if (character.fixedCards.some((id) => !deck.includes(id))) return '牌組必須包含角色的全部固定牌。';
  if (deck.some((id) => excluded.has(id))) return '牌組不可包含排除牌。';
  for (const [id, amount] of Object.entries(count(deck))) {
    if (amount > cap(id) || amount > (profile.collection[id] || 0)) {
      return '基礎牌最多五張，其他同名牌最多兩張，且不可超過收藏數量。';
    }
  }
  if (CARDS.filter((card) => !isBasicCard(card.id) && !excluded.has(card.id)).length < 3) {
    return '排除後至少需要 3 種非基礎獎勵牌。';
  }
  return null;
}

export function createProfile() {
  const collection = {};
  for (const preset of [...PRESETS, ...CHARACTERS]) {
    for (const [id, amount] of Object.entries(count(preset.deck))) {
      collection[id] = Math.max(collection[id] || 0, amount);
    }
  }
  return {
    version: 3,
    coins: 1000,
    collection,
    characterId: CHARACTERS[0].id,
    deck: [...CHARACTERS[0].deck],
    excludedCards: [],
    stats: { runs: 0, wins: 0 },
    lastPack: [],
  };
}

export function setLoadout(profile, deck, excludedCards = profile?.excludedCards || []) {
  const error = validateLoadout(profile, deck, excludedCards);
  if (error) return fail(error);
  profile.deck = [...deck];
  profile.excludedCards = [...excludedCards];
  return { ok: true };
}

export function applyCharacter(profile, characterId) {
  const character = characterFor(characterId);
  if (!character) return fail('找不到這名角色。');
  const error = validateLoadout(profile, character.deck, [], characterId);
  if (error) return fail(error);
  profile.characterId = characterId;
  profile.deck = [...character.deck];
  profile.excludedCards = [];
  return { ok: true };
}

export function applyPreset(profile, presetId) {
  const preset = PRESETS.find((item) => item.id === presetId);
  if (!preset) return fail('找不到這組預組牌。');
  const character = characterFor(profile?.characterId);
  if (!character) return fail('找不到這名角色。');
  const excludedCards = profile?.excludedCards;
  if (!Array.isArray(excludedCards)) return fail('排除牌資料無效。');
  const excluded = new Set(excludedCards);
  const selected = [];
  const amounts = new Map();
  const fixed = new Set(character.fixedCards);
  const add = (id) => {
    if (selected.length >= 10 || !known(id) || excluded.has(id) || fixed.has(id)) return false;
    const amount = amounts.get(id) || 0;
    if (amount >= cap(id) || amount >= (profile.collection[id] || 0)) return false;
    selected.push(id); amounts.set(id, amount + 1); return true;
  };
  // Profile decks do not carry instance flags. Put the character's fixed
  // cards first so createRun can mark the first copy of each one as fixed.
  for (const id of character.fixedCards) {
    const amount = amounts.get(id) || 0;
    if (amount >= cap(id) || amount >= (profile.collection[id] || 0)) return fail('角色固定牌不在收藏中。');
    selected.push(id); amounts.set(id, amount + 1);
  }
  for (const id of preset.deck) add(id);
  for (const id of character.deck) add(id);
  for (const card of CARDS) add(card.id);
  if (selected.length !== 10) return fail('無法在收藏與排除條件下組成十張牌。');
  const error = validateLoadout(profile, selected, excludedCards, character.id);
  if (error) return fail(error);
  profile.deck = selected;
  return { ok: true };
}

export function grantCard(profile, id) {
  if (!known(id)) return fail('找不到這張卡牌。');
  if ((profile.collection[id] || 0) >= cap(id)) return fail('已達收藏上限。');
  profile.collection[id] = (profile.collection[id] || 0) + 1;
  return { ok: true };
}

export function addTestCoins(profile) {
  profile.coins = Math.min(1_000_000, profile.coins + 500);
  return { ok: true };
}

export function openPack(profile) {
  if (profile.coins < 100) return fail('測試幣不足，可免費領取測試幣。');
  // Exclusions belong to run/loadout selection, not collection acquisition.
  const pool = CARDS.filter((card) => !isBasicCard(card.id));
  const cards = Array.from({ length: 3 }, () => pool[Math.floor(Math.random() * pool.length)].id);
  profile.coins -= 100;
  let duplicates = 0;
  for (const id of cards) {
    if ((profile.collection[id] || 0) >= cap(id)) {
      duplicates += 1;
      profile.coins += 20;
    } else profile.collection[id] = (profile.collection[id] || 0) + 1;
  }
  profile.lastPack = cards;
  return { ok: true, cards: [...cards], duplicates };
}

export function recordResult(profile, won) {
  profile.stats.runs += 1;
  if (won) profile.stats.wins += 1;
}

const boundedInt = (value, fallback, max = 1_000_000) =>
  Number.isSafeInteger(value) && value >= 0 && value <= max ? value : fallback;
const read = (storage, key) => {
  try {
    const value = JSON.parse(storage?.getItem(key) || 'null');
    return value && typeof value === 'object' && !Array.isArray(value) ? value : null;
  } catch { return null; }
};

function cleanExcluded(rawExcluded, character) {
  const source = Array.isArray(rawExcluded) ? rawExcluded : [];
  const excluded = [];
  const seen = new Set();
  for (const id of source) {
    if (!known(id) || seen.has(id) || character.fixedCards.includes(id)) continue;
    seen.add(id); excluded.push(id);
  }
  // Keep a save startable even if an old client wrote too many exclusions.
  while (CARDS.filter((card) => !isBasicCard(card.id) && !seen.has(card.id)).length < 3 && excluded.length) {
    const id = excluded.pop(); seen.delete(id);
  }
  return excluded;
}

function repairDeck(profile, rawDeck, character, excludedCards) {
  const excluded = new Set(excludedCards);
  const fixed = new Set(character.fixedCards);
  const deck = [];
  const amounts = new Map();
  const add = (id) => {
    if (deck.length >= 10 || !known(id) || excluded.has(id) || fixed.has(id)) return false;
    const amount = amounts.get(id) || 0;
    if (amount >= cap(id) || amount >= (profile.collection[id] || 0)) return false;
    deck.push(id); amounts.set(id, amount + 1); return true;
  };
  for (const id of character.fixedCards) {
    const amount = amounts.get(id) || 0;
    if (amount >= cap(id) || amount >= (profile.collection[id] || 0)) return null;
    deck.push(id); amounts.set(id, amount + 1);
  }
  const mapped = Array.isArray(rawDeck) ? rawDeck.map((id) => mapId(id, 1)).filter(known) : [];
  // Keep old flexible cards first, then use the character starter and the
  // global card table as deterministic fallbacks.
  for (const id of mapped) add(id);
  for (const id of character.deck) add(id);
  for (const card of CARDS) add(card.id);
  if (deck.length !== 10) return null;
  return deck;
}

export function loadProfile(storage) {
  const fresh = createProfile();
  try {
    const source = storage === undefined ? globalThis.localStorage : storage;
    const usable = (raw, version) => raw?.version === version && raw.collection &&
      typeof raw.collection === 'object' && !Array.isArray(raw.collection);
    const raw = [[STORAGE_KEY, 3], [V2_KEY, 2], [LEGACY_KEY, 1]]
      .map(([key, version]) => { const value = read(source, key); return usable(value, version) ? value : null; }).find(Boolean);
    if (!raw) return fresh;
    const collection = { ...fresh.collection };
    for (const [oldId, value] of Object.entries(raw.collection)) {
      const id = mapId(oldId, raw.version);
      if (!known(id)) continue;
      collection[id] = Math.max(collection[id] || 0, boundedInt(value, 0, cap(id)));
    }
    const characterId = characterFor(raw.characterId) ? raw.characterId : fresh.characterId;
    const character = characterFor(characterId);
    const profile = {
      ...fresh,
      collection,
      characterId,
      coins: boundedInt(raw.coins, fresh.coins),
      stats: { runs: boundedInt(raw.stats?.runs, 0), wins: boundedInt(raw.stats?.wins, 0) },
      lastPack: raw.version >= 2 && Array.isArray(raw.lastPack)
        ? raw.lastPack.map((id) => mapId(id, raw.version)).filter(known).slice(0, 3) : [],
    };
    profile.stats.wins = Math.min(profile.stats.wins, profile.stats.runs);
    const cleanedExcluded = cleanExcluded(raw.version >= 3 ? raw.excludedCards : [], character);
    const rawDeck = Array.isArray(raw.deck) ? raw.deck.map((id) => mapId(id, raw.version)) : [];
    const rawDeckIsComplete = Array.isArray(raw.deck) && raw.deck.length === 10 && rawDeck.every(known);
    let finalDeck = null;
    let finalExcluded = [...cleanedExcluded];
    // Try to preserve every cleaned exclusion first. If the old collection
    // cannot form ten legal cards under that set, relax only enough entries
    // (starting from the least durable tail) and retry atomically.
    while (!finalDeck) {
      if (rawDeckIsComplete && !validateLoadout(profile, rawDeck, finalExcluded, characterId)) {
        finalDeck = [...rawDeck];
        break;
      }
      const repaired = repairDeck(profile, rawDeck, character, finalExcluded);
      if (repaired && !validateLoadout(profile, repaired, finalExcluded, characterId)) {
        finalDeck = repaired;
        break;
      }
      if (!finalExcluded.length) break;
      finalExcluded = finalExcluded.slice(0, -1);
    }
    if (!finalDeck) {
      finalExcluded = [];
      finalDeck = repairDeck(profile, rawDeck, character, finalExcluded) || [...character.deck];
    }
    // Do not expose a partially repaired profile. This final call is the
    // single mutation point for deck and exclusions and must succeed.
    if (!setLoadout(profile, finalDeck, finalExcluded).ok) throw Error('無法修復保存的牌組。');
    return profile;
  } catch { return fresh; }
}

export function saveProfile(profile, storage) {
  try {
    const destination = storage === undefined ? globalThis.localStorage : storage;
    if (!destination?.setItem) return false;
    destination.setItem(STORAGE_KEY, JSON.stringify(profile));
    return true;
  } catch { return false; }
}
