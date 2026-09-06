import test from 'node:test';
import assert from 'node:assert/strict';
import { CARDS, PRESETS, CHARACTERS } from './data.js';
import { createRun } from './engine.js';
import {
  createProfile, setLoadout, applyPreset, applyCharacter, grantCard, openPack, addTestCoins,
  loadProfile, saveProfile, recordResult, STORAGE_KEY,
} from './profile.js';
const memoryStorage = () => {
  const values = new Map();
  return { getItem: key => values.get(key), setItem: (key, value) => values.set(key, value) };
};

test('new profile owns both legal ten-card presets', () => {
  const profile = createProfile();
  for (const preset of PRESETS) {
    assert.equal(applyPreset(profile, preset.id).ok, true);
    assert.equal(profile.deck.length, 10);
    assert.equal('roster' in profile, false);
  }
});

test('invalid, excessive and unowned loadouts fail without changing the deck', () => {
  const profile = createProfile();
  const before = structuredClone(profile);
  for (const deck of [[], profile.deck.slice(1), Array(10).fill('strike'), [...profile.deck.slice(1), '__proto__']]) {
    assert.equal(setLoadout(profile, deck).ok, false);
    assert.deepEqual(profile, before);
  }
  profile.collection.strike = 0;
  assert.equal(setLoadout(profile, profile.deck).ok, false);
});

test('排除驗證以全非基礎卡池計算，固定牌加八張基礎牌仍可使用', () => {
  const profile = createProfile(); profile.collection.strike = 5; profile.collection.defend = 5;
  const deck = ['kunai_barrage', 'venom_needle', ...Array(5).fill('strike'), ...Array(3).fill('defend')];
  assert.equal(setLoadout(profile, deck, ['ki_blast']).ok, true);
  assert.deepEqual(profile.excludedCards, ['ki_blast']); assert.deepEqual(profile.deck, deck);
  const before = structuredClone(profile);
  assert.equal(setLoadout(profile, deck, ['kunai_barrage']).ok, false);
  assert.deepEqual(profile, before);

  const allButTwo = CARDS.filter((card) => !['strike', 'defend', 'kunai_barrage', 'venom_needle'].includes(card.id)).map((card) => card.id);
  assert.equal(setLoadout(profile, deck, allButTwo).ok, false);
  assert.deepEqual(profile, before);
  assert.throws(() => createRun({ deck, seed: 'only-two-candidates', excludedCards: allButTwo }), /排除後至少需要 3 種/);
});

test('預組保留角色固定牌、避開排除，角色切換清空排除', () => {
  const profile = createProfile(); profile.collection.strike = 5; profile.collection.defend = 5;
  assert.equal(setLoadout(profile, profile.deck, ['ki_blast']).ok, true);
  assert.equal(applyPreset(profile, 'adaptive').ok, true);
  assert.deepEqual(profile.deck.slice(0, 2), CHARACTERS[0].fixedCards);
  assert.equal(profile.deck.includes('ki_blast'), false);
  assert.deepEqual(profile.excludedCards, ['ki_blast']);
  assert.equal(applyCharacter(profile, 'ki_fighter').ok, true);
  assert.deepEqual(profile.excludedCards, []);
  assert.deepEqual(profile.deck, CHARACTERS[1].deck);
});

test('packs cost 100 with 20 refunds per capped duplicate; basic cards are excluded', () => {
  const profile = createProfile();
  for (const card of CARDS) profile.collection[card.id] = ['strike', 'defend'].includes(card.id) ? 5 : 2;
  const result = openPack(profile);
  assert.equal(result.ok, true);
  assert.equal(result.cards.length, 3);
  assert.equal(result.duplicates, 3);
  assert.equal(profile.coins, 960);
  assert.deepEqual(profile.lastPack, result.cards);
  assert.ok(result.cards.every(id => !['strike', 'defend'].includes(id)));
  profile.coins = 99;
  const before = structuredClone(profile);
  assert.equal(openPack(profile).ok, false);
  assert.deepEqual(profile, before);
  addTestCoins(profile);
  assert.equal(profile.coins, 599);
});

test('direct acquisition respects basic and special card caps', () => {
  const profile = createProfile();
  profile.collection.strike = 4;
  assert.equal(grantCard(profile, 'strike').ok, true);
  assert.equal(grantCard(profile, 'strike').ok, false);
  profile.collection.ki_blast = 1;
  assert.equal(grantCard(profile, 'ki_blast').ok, true);
  assert.equal(grantCard(profile, 'ki_blast').ok, false);
  assert.equal(grantCard(profile, '__proto__').ok, false);
});

test('storage failures, invalid saves, and partial corruption recover safely', () => {
  const throwing = { getItem() { throw Error('blocked'); }, setItem() { throw Error('quota'); } };
  assert.deepEqual(loadProfile(throwing), createProfile());
  assert.equal(saveProfile(createProfile(), throwing), false);
  for (const raw of ['{oops', 'null', '{"version":2}', '{"version":2,"collection":[]}']) {
    assert.deepEqual(loadProfile({ getItem: () => raw }), createProfile());
  }
  const memory = memoryStorage();
  const profile = createProfile();
  recordResult(profile, true);
  recordResult(profile, false);
  assert.equal(saveProfile(profile, memory), true);
  assert.deepEqual(loadProfile(memory), profile);
  memory.setItem(STORAGE_KEY, JSON.stringify({ ...profile, coins: -4, deck: [], stats: { runs: 2, wins: 99 } }));
  const repaired = loadProfile(memory);
  assert.equal(repaired.coins, 1000);
  assert.equal(repaired.stats.wins, 2);
  assert.equal(setLoadout(repaired, repaired.deck).ok, true);
});

test('v1 migration preserves economy and maps legacy cards without overwriting the old save', () => {
  const memory = memoryStorage();
  const legacy = JSON.stringify({ version: 1, coins: 742, stats: { runs: 4, wins: 2 },
    roster: ['silver_samurai'], deck: Array(9).fill('cursed_bolt'),
    collection: { cursed_bolt: 2, silver_samurai: 1, domain_crush: 2, leaf_ninja: 1, unknown: 99 } });
  memory.setItem('rift-cards.profile.v1', legacy);
  memory.setItem(STORAGE_KEY, '{broken');
  const profile = loadProfile(memory);
  assert.equal(profile.version, 3);
  assert.equal(profile.coins, 742);
  assert.deepEqual(profile.stats, { runs: 4, wins: 2 });
  assert.equal(profile.collection.ki_blast, 2);
  assert.equal(profile.collection.silver_resolve, 1);
  assert.equal(profile.collection.kame_wave, 2);
  assert.equal(profile.collection.leaf_stance, 1);
  assert.equal(profile.collection.unknown, undefined);
  assert.deepEqual(profile.deck.slice(0, 2), CHARACTERS[0].fixedCards);
  assert.equal(profile.deck.length, 10);
  assert.equal(profile.deck.filter((id) => id === 'ki_blast').length, 2);
  assert.deepEqual(profile.excludedCards, []);
  assert.equal(saveProfile(profile, memory), true);
  assert.equal(memory.getItem('rift-cards.profile.v1'), legacy);
  profile.coins = 321;
  saveProfile(profile, memory);
  assert.equal(loadProfile(memory).coins, 321);
});


test('all three character starters are free, selection persists and invalid choice is atomic',()=>{
  const p=createProfile();const memory=memoryStorage();
  for(const c of CHARACTERS){assert.equal(applyCharacter(p,c.id).ok,true);assert.equal(p.characterId,c.id);assert.deepEqual(p.deck,c.deck);saveProfile(p,memory);assert.deepEqual(loadProfile(memory),p);}
  const before=structuredClone(p);assert.equal(applyCharacter(p,'unknown').ok,false);assert.deepEqual(p,before);
});
test('v2 migration keeps custom deck, collection and coins while selecting a valid default character',()=>{
  const memory=memoryStorage();const old={version:2,coins:444,collection:createProfile().collection,deck:PRESETS[1].deck,stats:{runs:7,wins:3}};
  memory.setItem('rift-cards.profile.v2',JSON.stringify(old));const migrated=loadProfile(memory);
  assert.equal(migrated.characterId,CHARACTERS[0].id);assert.deepEqual(migrated.deck.slice(0,2),CHARACTERS[0].fixedCards);assert.equal(migrated.deck.length,10);assert.equal(migrated.deck.slice(2).filter(id=>old.deck.includes(id)).length,8);assert.equal(migrated.excludedCards.length,0);assert.equal(migrated.coins,444);saveProfile(migrated,memory);assert.deepEqual(JSON.parse(memory.getItem('rift-cards.profile.v2')),old);
});

test('v3 migration relaxes unusable exclusions before committing a legal deck',()=>{
  const memory=memoryStorage(); const fixed=CHARACTERS[0].fixedCards;
  const excluded=CARDS.filter(card=>!['strike','defend',...fixed,'kame_wave'].includes(card.id)).map(card=>card.id).concat(['strike','defend']);
  memory.setItem(STORAGE_KEY,JSON.stringify({version:3,coins:777,collection:createProfile().collection,characterId:'shadow_ninja',deck:[],excludedCards:excluded,stats:{runs:3,wins:1}}));
  const migrated=loadProfile(memory);
  assert.equal(migrated.coins,777);assert.equal(migrated.deck.length,10);assert.deepEqual(migrated.deck.slice(0,2),fixed);
  assert.equal(setLoadout(migrated,migrated.deck,migrated.excludedCards).ok,true);
  assert.equal(migrated.excludedCards.includes('strike'),false);assert.equal(migrated.excludedCards.includes('defend'),false);
});
