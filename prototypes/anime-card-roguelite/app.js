import { UNIVERSES, CARDS, PRESETS, RELICS, CHARACTERS, ARCHETYPES, POTIONS, getCard } from './data.js';
import {
  createRun, visitNode, playCard, endTurn, getIntentDamage, chooseReward, rest, upgradeCard,
  buyCard, buyRelic, removeCard, leaveNode, chooseEvent, usePotion, getBuildSummary, getLootHint
} from './engine.js';
import {
  loadProfile, saveProfile, openPack, grantCard, addTestCoins, setLoadout,
  applyPreset, applyCharacter, recordResult
} from './profile.js';
import { BATTLE_ASSETS, playBattleArt, clearBattleArt, playEnemyArt, preloadBattleAssets } from './battle-art.js';

import { menuView } from './menu-views.js';
import { loadCampaign, saveCampaign, checkpoint, configuredDeck, buildExclusions } from './campaign.js';

const app = document.querySelector('#app');
preloadBattleAssets();
const memoryStorage = (() => {
  const values = new Map();
  return { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) };
})();

let storage = memoryStorage;
let storageNotice = '本機儲存不可用：收藏只保留在此頁，重新整理會遺失。';
let seed = '裂界-001';
try {
  localStorage.setItem('__rift_probe', '1');
  localStorage.removeItem('__rift_probe');
  storage = localStorage;
  storageNotice = '';
} catch (_) {}
try { seed = sessionStorage.getItem('rift-seed') || seed; } catch (_) {}

let profile = loadProfile(storage);
const loadedCampaign = loadCampaign(storage, profile.stats);
let campaign = loadedCampaign.campaign;
let campaignNotice = loadedCampaign.notice;
let campaignPersistenceBlocked = Boolean(loadedCampaign.notice && !campaign.run);
let runId = null;
let run = null;
let tab = 'title';
let screens = [];
let excludedBuilds = [];
let appliedBuildCards = [];
let replaceReady = false;
let feedback = '';
let selectedUid = null;
let selectedPotion = null;
let empowerChoice = false;
let pile = null;
let modalReturnFocus = null;
let pendingFocus = null;
let battleOverlay = null;
let battleOverlayReturnFocus = null;
let inputMode = 'mouse';
let rulesOpen = false;
let recorded = false;
let lastRelay = { from: 'neutral', to: 'neutral', reason: '' };
let draftDeck = [...(profile.deck || PRESETS[0]?.deck || [])];
let draftExcludedCards = [...(profile.excludedCards || [])];
let tutorialOpen = false;
let tutorialTab = 'relay';
let tutorialStep = 0;
let tutorialResonance = 0;
let tutorialNeutralUsed = false;
let tutorialEmpowerArmed = false;
let tutorialEmpowered = false;
let tutorialCharge = 0;
let tutorialChargeSpent = 0;
let tutorialReturnFocus = null;

const esc = value => String(value ?? '').replace(/[&<>"']/g, character => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}[character]));
const card = (id, upgraded = 0) => getCard(id, upgraded) || CARDS.find(item => item.id === id);
const universe = key => UNIVERSES[key] || UNIVERSES.neutral || { name: key, label: key };
const kindLabel = kind => ({ battle: '戰鬥', elite: '菁英', camp: '營火', shop: '商店', event: '事件', boss: '首領' }[kind] || kind);
const owned = id => profile.collection?.[id] || 0;
const basic = id => id === 'strike' || id === 'defend';
const activeCharacter = () => CHARACTERS.find(character => character.id === (run?.characterId || profile.characterId)) || CHARACTERS[0];
const fixedCardIds = (character = activeCharacter()) => [...(character?.fixedCards || character?.deck?.filter(id => !basic(id)).slice(0, 2) || [])];
const capFor = id => basic(id) ? 5 : 2;
const isExcluded = id => draftExcludedCards.includes(id);
const isDraftFixedAt = index => {
  const id = draftDeck[index];
  return fixedCardIds().includes(id) && draftDeck.slice(0, index).filter(cardId => cardId === id).length === 0;
};
const draftFixedCount = () => fixedCardIds().filter(id => draftDeck.includes(id)).length;
function loadoutCheck() {
  const fixed = fixedCardIds();
  if (draftDeck.length !== 10) return { ok: false, text: `需要剛好 10 張，現在 ${draftDeck.length} 張。` };
  if (draftDeck.some(id => !card(id))) return { ok: false, text: '牌組含有未知卡牌。' };
  if (fixed.some(id => !draftDeck.includes(id))) return { ok: false, text: '每張角色固定牌至少需要 1 張。' };
  if (draftExcludedCards.some(id => fixed.includes(id))) return { ok: false, text: '角色固定牌不可排除。' };
  if (draftDeck.some(id => isExcluded(id))) return { ok: false, text: '起始牌組不可包含排除牌。' };
  const counts = draftDeck.reduce((result, id) => { result[id] = (result[id] || 0) + 1; return result; }, {});
  if (Object.entries(counts).some(([id, amount]) => amount > capFor(id) || amount > owned(id))) return { ok: false, text: '牌組超過收藏數量或同名牌上限。' };
  const rewardPool = new Set(CARDS.filter(item => !basic(item.id) && !draftExcludedCards.includes(item.id)).map(item => item.id));
  if (rewardPool.size < 3) return { ok: false, text: '排除後至少要保留 3 種非基礎戰利品候選牌。' };
  return { ok: true, text: '起始牌組合法，可開始冒險。' };
}
const say = text => { feedback = text; };

const icon = (name, className = '') => {
  const paths = {
    menu: '<path d="M4 7h16M4 12h16M4 17h16"></path>',
    log: '<path d="M6 4.5h12v15H6z"></path><path d="M9 8h6M9 12h6M9 16h4"></path>',
    build: '<path d="M5 4h14v16H5z"></path><path d="m8 9 2 2 4-4M8 15h8"></path>',
    rules: '<circle cx="12" cy="12" r="8.5"></circle><path d="M12 10v5M12 7.5v.2"></path>',
    close: '<path d="m6 6 12 12M18 6 6 18"></path>',
    cancel: '<circle cx="12" cy="12" r="8.5"></circle><path d="m8.5 8.5 7 7M15.5 8.5l-7 7"></path>',
    confirm: '<path d="m5 12 4.2 4.2L19 6.5"></path>',
    energy: '<path d="m13.2 2.8-7 10h5.2l-.6 8.4 7-10h-5.2l.6-8.4Z"></path>',
    draw: '<path d="M7 5h10v14H7z"></path><path d="M4.5 7.5v11h10"></path>',
    discard: '<path d="M5 7h14M9 7V4h6v3M7 7l1 13h8l1-13M10 11v5M14 11v5"></path>',
    exile: '<path d="M12 3v12M7.5 10.5 12 15l4.5-4.5M5 20h14"></path>',
    potion: '<path d="M9 3h6M10 3v4l-3.5 5.3a5 5 0 0 0 4.2 7.7h2.6a5 5 0 0 0 4.2-7.7L14 7V3"></path><path d="M8 13h8"></path>',
    empower: '<path d="m12 3 1.7 5.3H19l-4.3 3.2 1.6 5.2-4.3-3.1-4.3 3.1 1.6-5.2L5 8.3h5.3L12 3Z"></path>',
    gold: '<circle cx="12" cy="12" r="8.5"></circle><path d="M9 9.5h4.3a1.7 1.7 0 1 1 0 3.4H10.7a1.7 1.7 0 1 0 0 3.4H15M12 7.5v9"></path>',
    back: '<path d="M19 12H5M11 6l-6 6 6 6"></path>',
  };
  return `<svg class="ui-icon ${className}" viewBox="0 0 24 24" aria-hidden="true" focusable="false">${paths[name] || paths.rules}</svg>`;
};

function save() {
  persistProgress();
  if (saveProfile(profile, storage)) return true;
  storageNotice = '本機儲存失敗：收藏只保留在此頁，重新整理可能遺失。';
  say('無法儲存收藏；本次瀏覽仍可繼續。');
  return false;
}

function act(fn) {
  try {
    const result = fn();
    if (result?.error) say(result.error);
    return result;
  } catch (error) {
    say(error?.message || '無效操作。');
    return { ok: false, error: error?.message || '無效操作。' };
  }
}

function saveSeed(value) {
  seed = String(value ?? '');
  try { sessionStorage.setItem('rift-seed', seed); } catch (_) {}
}

function setTheme() {
  document.documentElement.dataset.universe = tab === 'run' ? run?.currentUniverse || 'neutral' : 'neutral';
  document.documentElement.dataset.input = inputMode;
  app.dataset.screen = tab;
}

function focusRef(element) {
  if (!element || element === document.body || !app.contains(element)) return null;
  if (element.id) return { type: 'id', value: element.id };
  for (const key of ['menu', 'build', 'tab', 'preset', 'node', 'play', 'enemy', 'reward', 'pile', 'upgrade', 'buyCard', 'buyRelic', 'remove', 'event', 'addDeck', 'character', 'potion', 'removeDeck', 'exclude', 'include', 'tutorialOpen', 'tutorialStep', 'tutorialTab', 'tutorialAction', 'battleOverlay']) {
    if (element.dataset[key] !== undefined) return { type: 'data', key, value: element.dataset[key] };
  }
  return null;
}

function findFocus(reference) {
  if (!reference) return null;
  if (reference.type === 'id') return document.getElementById(reference.value);
  const attribute = `data-${reference.key.replace(/[A-Z]/g, character => `-${character.toLowerCase()}`)}`;
  return [...app.querySelectorAll(`[${attribute}]`)].find(element => element.dataset[reference.key] === reference.value) || null;
}

function cardInstance(instance) {
  return instance ? card(instance.cardId, instance.upgraded || 0) : undefined;
}

function upgradePreview(instance) {
  const item = cardInstance(instance);
  return item?.upgrade?.text ? `升級：${item.upgrade.text}` : '升級後效果提升';
}

function hasDamageOrBlock(item) {
  return Boolean(item?.effects?.some(effect => effect.op === 'damage' || effect.op === 'block'));
}

function canEmpower(instance) {
  return Boolean(run && run.resonance >= 3 && hasDamageOrBlock(cardInstance(instance)));
}

function cardArtAction(item, targetId = null) {
  if (!item) return null;
  return {
    cardId: item.id,
    characterId: run?.characterId,
    targetId,
    target: item.target,
    hasDamage: Boolean(item.effects?.some(effect => effect.op === 'damage')),
    hasBlock: Boolean(item.effects?.some(effect => effect.op === 'block')),
  };
}

function cardHtml(instanceOrCard, options = {}) {
  const item = instanceOrCard?.cardId ? cardInstance(instanceOrCard) : instanceOrCard;
  if (!item) return '<div class="card invalid-card"><strong>未知卡牌</strong><span class="desc">此卡牌資料無法使用。</span></div>';
  const upgraded = instanceOrCard?.cardId && instanceOrCard.upgraded ? '<span class="upgrade-badge">+</span>' : '';
  const status = options.status ? `<span class="card-status">${esc(options.status)}</span>` : '';
  const preview = options.previewUpgrade ? `<span class="upgrade-preview">${esc(upgradePreview(instanceOrCard))}</span>` : '';
  const label = options.ariaLabel ? `aria-label="${esc(options.ariaLabel)}"` : '';
  const title = options.title ? `title="${esc(options.title)}"` : '';
  const tags=(item.tags||[]).map(t=>ARCHETYPES[t]?.name).filter(Boolean);
  const loot=run&&/data-reward|data-buy-card/.test(options.action||'')?`<span class="loot-hint">${esc(getLootHint(run,item.id))}</span>`:'';
  const rarity={common:'普通',uncommon:'進階',rare:'稀有'}[item.rarity]||'';
  const typeLabel = { attack: '攻擊', skill: '技能', power: '能力' }[item.type] || item.type;
  const artUniverse = item.universe === 'neutral' ? (activeCharacter()?.universe || 'ninja') : item.universe;
  const artHero = {ninja:'shadow_ninja',dragon:'ki_fighter',samurai:'silver_ronin'}[artUniverse];
  const illustration = `<span class="card-illustration" aria-hidden="true" style="--card-scene:url('${BATTLE_ASSETS.backgrounds[artUniverse]}')"><span class="sprite-sheet" style="--sprite-image:url('${BATTLE_ASSETS.heroes[artHero]}')"></span></span>`;
  return `<button class="card${options.selected ? ' selected' : ''}${options.disabled ? ' disabled-card' : ''}" ${options.action || ''} ${options.extra || ''} ${label} ${title} ${options.disabled ? 'disabled' : ''}><span class="eyebrow">${esc(universe(item.universe).name)} · ${esc(typeLabel)} · ${rarity}</span><strong>${esc(item.name)}${upgraded} <span class="cost">${item.cost}</span></strong>${illustration}<span class="desc">${esc(item.text)}</span>${tags.length?`<span class="build-tags">${tags.map(t=>`<i>${esc(t)}</i>`).join('')}</span>`:''}${preview}${loot}${status}</button>`;
}

function header() {
  if (tab === 'run' && run?.phase === 'battle') return '';
  const current = run?.currentUniverse || 'neutral';
  return `<header class="masthead"><div class="masthead-copy"><div class="eyebrow">single-player relay deckbuilder</div><h1>${tab === 'home' ? '選擇你的旅人' : '裂界牌局'}</h1><p class="subtitle">${tab === 'home' ? '02 / 角色與起始牌' : '跨宇宙接力 · 七層登塔'}</p></div><nav class="tabs" aria-label="主選單"><button data-tab="home" aria-current="${tab === 'home' ? 'page' : 'false'}">角色／配置</button><button data-menu="title">主選單</button><button data-tab="collection" aria-current="${tab === 'collection' ? 'page' : 'false'}">收藏／起始配置</button>${run ? `<button data-tab="run" aria-current="${tab === 'run' ? 'page' : 'false'}">當局</button>` : ''}<button id="tutorial-open" data-tutorial-open>接力／蓄氣教學</button></nav></header><p class="global-status" role="status" aria-live="polite">${esc(feedback)}</p>${storageNotice||campaignNotice ? `<p class="storage-notice" role="status">${esc(storageNotice||campaignNotice)}</p>` : ''}<details class="rules" id="rules" ${rulesOpen ? 'open' : ''}><summary>規則摘要</summary><p>每回合 3 能量、抽 5 張；玩家只靠出牌攻擊，結束回合後敵人依意圖行動。格擋會在下回合清除；荊棘、力量等本場效果持續到戰鬥結束。普通勝利不自動回血；失敗只重置當局，收藏保留。非中立牌成功出牌會接力；3 共鳴可手動強化攻擊或格擋牌。</p></details><div class="theme-chip" data-current-universe="${esc(current)}">目前畫風：${esc(universe(current).name)}</div>`;
}

function presetDeck() {
  return [...(profile.deck?.length ? profile.deck : PRESETS[0]?.deck || [])];
}

function characterPicker() {
  const selected=activeCharacter();
  const counts=selected.deck.reduce((a,id)=>(a[id]=(a[id]||0)+1,a),{});
  return `<section class="panel character-picker"><div class="split"><div><span class="eyebrow">選擇冒險角色</span><h2>職業決定特性，戰利品決定流派</h2></div><span class="help">${run ? '冒險進行中，角色與起始配置已鎖定。' : '所有宇宙的卡牌皆可混搭'}</span></div><div class="character-options">${CHARACTERS.map(c=>`<button data-character="${c.id}" class="character-choice ${c.id===selected.id?'active':''}" aria-pressed="${c.id===selected.id}" ${run ? 'disabled' : ''}><span class="character-portrait">${heroSpriteMarkup('choice-sprite', c.id)}</span><span class="eyebrow">${esc(universe(c.universe).name)} · ${esc(c.job)}</span><strong>${esc(c.name)} <small>${c.maxHp} HP</small></strong><b>${esc(c.traitName)}</b><span>${esc(c.traitText)}</span><span class="build-tags">${c.builds.map(t=>`<i>${esc(ARCHETYPES[t]?.name || t)}</i>`).join('')}</span><small class="fixed-preview">固定牌：${fixedCardIds(c).map(id=>esc(card(id)?.name || id)).join('、')}</small></button>`).join('')}</div><details class="starter-preview"><summary>${esc(selected.name)}的起始牌 · 10張</summary><div class="starter-grid">${Object.entries(counts).map(([id,n])=>`<div class="mini"><b>${esc(card(id)?.name || id)} ×${n}</b><br>${esc(card(id)?.text || '')}</div>`).join('')}</div></details></section>`;
}
function buildView({ open = true } = {}) {
  const builds=getBuildSummary(run);
  return `<details class="build-summary" ${open ? 'open' : ''}><summary>目前構築 · ${run.deck.length}張牌</summary><div class="build-lines">${builds.map(b=>`<div><b>${esc(b.name)} ×${b.count}</b><span>${esc(b.description || b.payoff || '')}</span></div>`).join('')||'<p class="help">選擇戰利品，開始形成流派。</p>'}</div></details>`;
}
function potionView({ compact = false } = {}) {
  const label = compact ? '藥' : '消耗品';
  return `<section class="potion-bar${compact ? ' compact-potion-bar' : ''}" aria-label="戰鬥消耗品"><span class="potion-label">${icon('potion')}<b>${label} ${run.potions.length}/2</b></span>${run.potions.map(p=>{const d=POTIONS.find(x=>x.id===p.potionId);return `<button data-potion="${p.uid}" class="${selectedPotion===p.uid?'selected':''}" aria-pressed="${selectedPotion===p.uid}" ${run.phase==='battle'?'':'disabled'} aria-label="${esc(d?.name || '消耗品')}：${esc(d?.text || '')}" title="${esc(d?.text || '')}"><strong>${esc(d?.name || '未知消耗品')}</strong><small>${esc(d?.text || '')}</small></button>`;}).join('')}${!compact && run.potions.length<2?'<span class="help">戰鬥可掉落補充；背包滿則換10金。</span>':''}</section>`;
}

function homeView() {
  const check=loadoutCheck(), protectedCards=buildExclusions(excludedBuilds,profile.characterId).protectedCards;
  return `<section class="character-screen"><div class="character-screen-top"><button data-menu="setup-back">← 冒險設定</button><span>${excludedBuilds.length?'本局排除：'+excludedBuilds.map(id=>ARCHETYPES[id].name).join('、'):'全部流派開放'}</span></div>${characterPicker()}<aside class="character-launch panel"><span class="eyebrow">準備出發</span><h2>${esc(activeCharacter().name)} · ${esc(activeCharacter().job)}</h2><p>${esc(activeCharacter().traitText)}</p>${protectedCards.length?`<p class="fixed-rule">固定牌保留：${protectedCards.map(id=>esc(card(id).name)).join('、')}</p>`:''}<div class="loadout-check ${check.ok?'valid':'invalid'}" data-loadout-check="${check.ok?'valid':'invalid'}"><strong>固定 ${draftFixedCount()}/2 · 自選 ${Math.max(0,draftDeck.length-draftFixedCount())}/8 · 總計 ${draftDeck.length}/10</strong><span>${esc(check.text)}</span></div><label class="field">冒險種子<input id="seed" value="${esc(seed)}" maxlength="48"></label><button class="primary start-button" id="start" ${run||!check.ok?'disabled':''}>開始登塔 · ${draftDeck.length}/10</button><button data-tab="collection">調整起始牌／個別排除</button><div class="draft-exclusions" data-draft-excluded><b>本局排除 ${draftExcludedCards.length} 張卡</b><span>${draftExcludedCards.length?draftExcludedCards.map(id=>esc(card(id).name)).join('、'):'尚未排除卡牌'}</span></div><details><summary>套用推薦牌組</summary>${PRESETS.map(p=>`<button class="preset" data-preset="${p.id}"><strong>${p.name}</strong><span>${p.description}</span></button>`).join('')}</details></aside></section>`;
}

function collectionView() {
  const locked = Boolean(run);
  const acquire = item => cardHtml(item, { action: `data-grant="${esc(item.id)}"`, disabled: owned(item.id) >= capFor(item.id), extra: `aria-label="免費指定取得 ${esc(item.name)}"` });
  const collectionCard = item => {
    const fixed = fixedCardIds().includes(item.id);
    const excluded = isExcluded(item.id);
    const count = draftDeck.filter(id => id === item.id).length;
    const addDisabled = locked || excluded || draftDeck.length >= 10 || count >= Math.min(capFor(item.id), owned(item.id));
    const exclusionControl = fixed
      ? '<span class="locked-label">角色固定牌 · 不可排除</span>'
      : `<button class="secondary exclusion-toggle" data-exclude="${esc(item.id)}" aria-pressed="${excluded}" ${locked ? 'disabled' : ''}>${excluded ? '取消本局排除' : '本局排除'}</button>`;
    return `<div class="collection-card" data-card-id="${esc(item.id)}">${cardHtml(item, { action: `data-add-deck="${esc(item.id)}"`, disabled: addDisabled, status: excluded ? '已排除 · 先取消排除' : owned(item.id) ? '加入起始牌組' : '尚未收藏', title: excluded ? '此牌已排除，取消排除後才能加入' : locked ? '冒險進行中，起始配置已鎖定' : undefined })}${exclusionControl}${acquire(item)}<span class="owned">持有 ${owned(item.id)}/${capFor(item.id)}</span></div>`;
  };
  const check = loadoutCheck();
  const deckCards = draftDeck.map((id, index) => {
    const fixed = isDraftFixedAt(index);
    const status = fixed ? '角色固定牌 · 鎖定' : locked ? '冒險進行中 · 鎖定' : '點擊移除此副本';
    return cardHtml(card(id), { action: `data-remove-deck="${index}"`, disabled: fixed || locked, status, title: fixed ? '每種角色固定牌的第一份不可移除' : locked ? '冒險進行中，起始配置已鎖定' : undefined, extra: `aria-label="${fixed ? '角色固定牌不可移除' : `移除第 ${index + 1} 張`}"` });
  }).join('');
  const exclusions = draftExcludedCards.map(id => `<span class="exclusion-chip" data-excluded-card="${esc(id)}"><span>${esc(card(id)?.name || id)}</span>${fixedCardIds().includes(id) ? '<b>固定牌不可排除</b>' : `<button data-include="${esc(id)}" aria-pressed="true" ${locked ? 'disabled' : ''}>取消</button>`}</span>`).join('');
  return `<section class="collection-layout"><section class="panel collection-summary"><span class="eyebrow">卡包與組牌</span><h2>裂界收藏</h2><strong class="big-gold">${profile.coins} 測試幣</strong><p class="help">收藏${storageNotice ? '只在此頁暫存' : '存於本機'}；局內新增牌與升級不會加入收藏。</p><button class="primary" id="pack">開啟卡包 · 100 測試幣</button><button id="coins">取得 500 測試幣</button><div class="mini"><b>測試幣</b>只用於收藏開包；<b>冒險金幣</b>只在當局使用。</div>${profile.lastPack?.length ? `<div class="mini"><b>最近卡包</b><br>${profile.lastPack.map(id => esc(card(id)?.name || '未知卡牌')).join('、')}</div>` : ''}</section><section class="panel deck-editor"><div class="split"><div><span class="eyebrow">自訂起始牌組</span><h2>${draftDeck.length}/10</h2></div><button id="save-loadout" ${!locked && check.ok ? '' : 'disabled'}>儲存</button></div><div class="loadout-check ${check.ok ? 'valid' : 'invalid'}" data-loadout-check="${check.ok ? 'valid' : 'invalid'}"><strong>固定 ${draftFixedCount()}/${fixedCardIds().length} · 自選 ${Math.max(0, draftDeck.length - draftFixedCount())}/8</strong><span>${esc(locked ? '冒險進行中，配置已鎖定。' : check.text)}</span></div><div class="card-grid">${deckCards || '<p class="empty">尚未加入牌。</p>'}</div><div class="draft-exclusions"><b>本局排除</b><span>${exclusions || '尚未排除卡牌'}</span></div><p class="help">每張角色固定牌的第一份不可移除；額外同名副本可移除。本局排除非固定牌會移除草稿中的所有副本，並從戰利品／商店候選排除，請補滿 10 張。</p></section><section class="panel collection-cards"><span class="eyebrow">可用卡牌</span><h2>收藏、加入與排除</h2><div class="card-grid">${CARDS.map(collectionCard).join('')}</div></section></section>`;
}

function mapView() {
  const layers = Array.isArray(run.map) ? run.map : [];
  return `<section class="map-layout"><section class="panel map-panel"><div class="map-heading"><div><span class="eyebrow">七層登塔 · 第 ${run.step + 1}/7 層</span><h2>選擇下一個節點</h2></div><span class="gold-chip">${run.gold} 冒險金幣</span></div><div class="map-route">${layers.map((layer, layerIndex) => `<section class="map-layer ${layerIndex === run.step ? 'current-layer' : ''}" aria-label="第 ${layerIndex + 1} 層"><span class="layer-label">${layerIndex + 1}</span><div class="node-list">${layer.map(node => { const selectable = layerIndex === run.step && !node.visited; return `<button class="map-node node-${esc(node.kind)} ${node.visited ? 'visited' : ''}" data-node="${esc(node.id)}" ${selectable ? '' : 'disabled'}><span class="node-kind">${esc(kindLabel(node.kind))}</span><strong>${esc(node.label)}</strong><span>${esc(node.description)}</span></button>`; }).join('')}</div></section>`).join('')}</div></section><aside class="panel route-sidebar"><h2>旅人狀態</h2>${playerHtml()}<button data-pile="deck">查看牌組 ${run.deck.length}</button>${buildView()}<h3>遺物</h3>${relicList()}${potionView()}<div class="mini">目前宇宙：${esc(universe(run.currentUniverse || 'neutral').name)}<br>上一個非中立宇宙：${esc(universe(run.lastUniverse || 'neutral').name)}<br>共鳴 ${run.resonance}/3</div></aside></section>`;
}

function playerHtml() {
  const player = run?.player || {};
  const character=CHARACTERS.find(c=>c.id===run?.characterId);
  const hp = Math.max(0, player.hp || 0);
  const maxHp = player.maxHp || 70;
  return `<section class="player-card"><div class="player-identity"><span class="eyebrow">角色身份 · ${esc(character?.job || '旅人')}</span><strong>${esc(player.name || character?.name || '旅人')}</strong><span class="trait-name">${esc(character?.traitName || '')}</span></div><div class="player-vitals"><span class="hp">生命 ${hp}/${maxHp}</span><span>格擋 ${player.block || 0}</span><span>力量 ${player.strength || 0}</span><span>荊棘 ${player.thorns || 0}</span><span>蓄氣 ${player.charge || 0}/9</span><span>放逐格擋 ${player.exhaustGuard || 0}</span></div><div class="hp-bar" aria-label="生命 ${hp}/${maxHp}"><span style="width:${Math.max(0, Math.min(100, hp / maxHp * 100))}%"></span></div><p class="trait-help">${esc(character?.traitText || '跨宇宙卡牌皆可加入構築。')}</p></section>`;
}

function heroSpriteMarkup(className = '', characterId = run?.characterId) {
  const hero = BATTLE_ASSETS.heroes[characterId];
  return hero ? `<span class="sprite-sheet sprite-idle hero-sprite ${className}" style="--sprite-image:url('${esc(hero)}')" aria-hidden="true"></span>` : '';
}

function shieldIcon() {
  return '<svg class="shield-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 2.5 19 5v5.25c0 4.55-2.85 8.48-7 10.75-4.15-2.27-7-6.2-7-10.75V5l7-2.5Z"></path><path d="m8.8 11.9 2.05 2.05 4.45-4.45"></path></svg>';
}

function combatantVitals({ current, max, block, statuses = [], className = '', label = '生命' }) {
  const currentValue = Math.max(0, Number(current) || 0);
  const maxValue = Math.max(1, Number(max) || 1);
  const blockValue = Math.max(0, Number(block) || 0);
  const percentage = Math.max(0, Math.min(100, currentValue / maxValue * 100));
  const statusMarkup = statuses.filter(Boolean).join('') || '<span class="status-empty">無狀態</span>';
  return `<div class="combatant-vitals ${className}" aria-label="${esc(label)} ${currentValue}/${maxValue}"><div class="combatant-hp-row"><span class="combatant-hp"><span class="hp-bar combatant-hp-bar" role="progressbar" aria-label="${esc(label)} ${currentValue}/${maxValue}" aria-valuemin="0" aria-valuemax="${maxValue}" aria-valuenow="${currentValue}"><span style="width:${percentage}%"></span></span><strong class="combatant-hp-value">${currentValue}/${maxValue}</strong></span><span class="combatant-block" aria-label="格擋 ${blockValue}">${shieldIcon()}<span>${blockValue}</span></span></div><div class="combatant-statuses" aria-label="狀態">${statusMarkup}</div></div>`;
}

function battleHud(className = '') {
  const player = run?.player || {};
  const character = CHARACTERS.find(item => item.id === run?.characterId);
  const current = run?.currentUniverse || 'neutral';
  return `<div class="battle-hud ${className}" data-battle-hud><div class="hud-identity"><span class="hud-portrait">${heroSpriteMarkup('hud-sprite')}</span><span><small class="eyebrow">角色 · ${esc(character?.job || '旅人')}</small><strong>${esc(player.name || character?.name || '旅人')}</strong><small>${esc(character?.traitName || '')}</small></span></div><div class="hud-round"><span>回合</span><b>${run?.turn || 1}</b></div><div class="hud-resources"><span class="hud-resonance" data-resonance="${run?.resonance || 0}">共鳴 <b>${run?.resonance || 0}/3</b></span><span class="hud-universe" data-current-universe="${esc(current)}">${esc(universe(current).name)}</span></div></div>`;
}

function relicList() {
  if (!run?.relics?.length) return '<p class="help">尚無遺物。</p>';
  return `<div class="relic-list">${run.relics.map(id => { const item = RELICS.find(relic => relic.id === id); return `<div class="relic"><b>${esc(item?.name || id)}</b><span>${esc(item?.text || '遺物效果')}</span></div>`; }).join('')}</div>`;
}

function relayPanel() {
  const current = run?.currentUniverse || 'neutral';
  const transition = lastRelay.to === current && lastRelay.from !== current ? lastRelay : null;
  const previous = transition?.from || run?.lastUniverse || 'neutral';
  const logReason = [...(run?.log || [])].reverse().find(entry => /跨宇宙接力/.test(entry));
  const reason = transition?.reason || logReason || (current === 'neutral' ? '中立牌不累積也不中斷接力。' : `目前 ${universe(current).name} 牌路；上一個非中立宇宙：${universe(previous).name}`);
  return `<section class="relay-panel panel" data-last-nonneutral="${esc(previous)}" data-resonance="${run.resonance}" data-relay-reason="${esc(reason)}"><div class="relay-top"><div><span class="eyebrow">CROSS-UNIVERSE RELAY</span><h2 data-current-universe="${esc(current)}">${esc(universe(current).name)} <small>／${esc(universe(current).label)}</small></h2></div><div class="resonance" aria-label="共鳴 ${run.resonance}/3">${[0, 1, 2].map(index => `<span class="resonance-dot ${index < run.resonance ? 'filled' : ''}">${index + 1}</span>`).join('')}</div></div><p class="relay-reason">${esc(reason)}</p><p class="relay-history">上一個非中立：${esc(universe(previous).name)} · 共鳴 ${run.resonance}/3</p></section>`;
}

function intentHtml(enemy) {
  const intent = enemy.intent || {};
  const damage = intent.kind === 'attack' ? getIntentDamage(enemy) : 0;
  const amount = intent.kind === 'attack' ? `${damage} ×${intent.hits || 1}` : intent.amount || '';
  const label = intent.kind === 'buff' && intent.label === '蓄力' ? '強化攻勢' : intent.label || intent.kind || '未知';
  return `<span class="intent-kind">${esc(label)}</span> ${esc(amount)}`;
}

function intentSummary(enemy) {
  const intent = enemy.intent || {};
  const damage = intent.kind === 'attack' ? getIntentDamage(enemy) : 0;
  const amount = intent.kind === 'attack' ? `${damage} ×${intent.hits || 1}` : intent.amount || '';
  const label = intent.kind === 'buff' && intent.label === '蓄力' ? '強化攻勢' : intent.label || intent.kind || '未知';
  return `${label}${amount ? ` ${amount}` : ''}`;
}

function enemyHtml(enemy) {
  const dead = enemy.hp <= 0;
  const boss = run?.currentNode?.kind === 'boss' || enemy.boss === true || /boss/i.test(enemy.id || '');
  const sprite = boss ? BATTLE_ASSETS.enemies.boss : BATTLE_ASSETS.enemies.raider;
  const intent = intentSummary(enemy);
  const tooltip = `${enemy.name}；生命 ${enemy.hp}/${enemy.maxHp}；格擋 ${enemy.block || 0}；意圖：${intent}${enemy.poison ? `；毒 ${enemy.poison}` : ''}${enemy.weak ? `；虛弱 ${enemy.weak}` : ''}`;
  const vitals = combatantVitals({
    current: enemy.hp,
    max: enemy.maxHp,
    block: enemy.block,
    className: 'enemy-stats',
    statuses: [
      enemy.poison ? `<span class="poison">毒 ${esc(enemy.poison)}</span>` : '',
      enemy.weak ? `<span class="weak">虛弱 ${esc(enemy.weak)}</span>` : '',
    ],
  });
  return `<button class="enemy ${dead ? 'dead' : ''} ${selectedPotion || cardInstance(run.hand.find(instance => instance.uid === selectedUid))?.target === 'enemy' ? 'targetable' : ''}" data-enemy="${esc(enemy.id)}" data-combatant="enemy" aria-label="${esc(tooltip)}" title="${esc(tooltip)}" ${dead ? 'disabled' : ''}><span class="enemy-intent-bubble">${intentHtml(enemy)}</span><span class="enemy-head"><span class="eyebrow">敵方</span><strong>${esc(enemy.name)}</strong></span><span class="enemy-art-wrap"><span class="sprite-sheet sprite-idle enemy-sprite" style="--sprite-image:url('${esc(sprite)}')" aria-hidden="true"></span></span>${vitals}<span class="enemy-tooltip" role="tooltip">${esc(tooltip)}</span></button>`;
}

function pileItems(kind) {
  const source = kind === 'deck' ? run?.deck : run?.[kind];
  const items = source || [];
  if (kind === 'draw') {
    const grouped = items.reduce((counts, instance) => {
      const key = `${instance.cardId}:${Number(instance.upgraded || 0) ? 'upgraded' : 'base'}`;
      counts[key] ||= { instance, count: 0 };
      counts[key].count += 1;
      return counts;
    }, {});
    return Object.values(grouped).map(group => { const item = cardInstance(group.instance); const version = Number(group.instance.upgraded || 0) ? '已升級' : '基礎'; return `<div class="mini"><b>${esc(item?.name || '未知卡牌')} · ${version}</b> ×${group.count}<br>${esc(item?.text || '')}</div>`; }).join('');
  }
  return items.map(instance => { const item = cardInstance(instance); const version = Number(instance.upgraded || 0) ? ' · 已升級' : ' · 基礎'; return `<div class="mini"><b>${esc(item?.name || '未知卡牌')}${version}</b><br>${esc(item?.text || '')}</div>`; }).join('');
}

function battleOverlayButton(name, label) {
  return `<button class="battle-overlay-trigger" data-battle-overlay="${name}" aria-label="${label}" title="${label}">${icon(name)}<span>${label}</span></button>`;
}

function battleTopbar() {
  const current = run?.currentUniverse || 'neutral';
  const node = run?.currentNode;
  const notices = [...new Set([storageNotice, campaignNotice, feedback].filter(Boolean))];
  const noticeMarkup = notices.length ? `<div class="battle-notices" role="status" aria-live="polite">${notices.map(notice => `<p>${esc(notice)}</p>`).join('')}</div>` : '';
  return `<header class="battle-topbar" aria-label="戰鬥資訊"><div class="battle-location"><span class="eyebrow">第 ${run.step + 1}/7 層 · ${esc(kindLabel(node?.kind || 'battle'))}</span><strong data-current-universe="${esc(current)}">${esc(universe(current).name)}戰線</strong><span>回合 ${run.turn} · ${run.gold} 金</span></div><div class="battle-top-resources"><span class="top-resource top-resonance" data-resonance="${run.resonance}">${icon('empower')}<b>${run.resonance}/3</b><span>共鳴</span></span><span class="top-resource top-enemies"><b>${run.enemies.filter(enemy => enemy.hp > 0).length}</b><span>敵人</span></span></div><nav class="battle-top-actions" aria-label="戰鬥資訊入口">${battleOverlayButton('menu', '選單')}${battleOverlayButton('log', '戰報')}${battleOverlayButton('build', '構築')}${battleOverlayButton('rules', '規則')}</nav>${noticeMarkup}</header>`;
}

function battleOverlayView() {
  if (!battleOverlay || tab !== 'run' || run?.phase !== 'battle') return '';
  const titles = { menu: '戰鬥選單', log: '即時戰報', build: '構築與遺物', rules: '戰鬥規則' };
  let content = '';
  if (battleOverlay === 'menu') {
    content = `<div class="overlay-menu-actions"><button data-battle-overlay="close" class="primary">${icon('back')}<span>繼續戰鬥</span></button><button data-tutorial-open>${icon('rules')}<span>玩法教學</span></button><button data-menu="title">${icon('menu')}<span>回到主選單</span></button></div><p class="help">離開戰鬥不會重置存檔；從主選單可繼續目前冒險。</p>`;
  } else if (battleOverlay === 'log') {
    content = `<ol class="log overlay-log">${(run.log || []).slice().reverse().map(entry => `<li>${esc(entry)}</li>`).join('') || '<li>尚無戰報。</li>'}</ol>`;
  } else if (battleOverlay === 'build') {
    content = `${buildView({ open: true })}<section class="overlay-section"><h3>遺物</h3>${relicList()}</section><section class="overlay-section"><h3>資源</h3><p class="help">冒險金幣 ${run.gold} · 共鳴 ${run.resonance}/3 · 手牌 ${run.hand.length}/10 · 抽牌堆 ${run.draw.length}</p><p class="help">${run.potions.length ? `持有消耗品：${run.potions.map(p => POTIONS.find(item => item.id === p.potionId)?.name || '未知').join('、')}` : '尚無消耗品。'}</p></section>`;
  } else if (battleOverlay === 'rules') {
    content = `<details class="overlay-rules" id="rules" open><summary>戰鬥規則</summary><p>每回合 3 能量、抽 5 張；回合結束時手牌棄置，敵人依頭頂意圖行動。格擋在下一回合開始清除；力量、荊棘、蓄氣與放逐護持持續到本場戰鬥結束。</p><p>中立牌不累積也不中斷接力；跨宇宙出牌可累積共鳴，3 共鳴可在出牌前手動強化攻擊或格擋牌。強化的首段傷害與首個格擋各增加 4。</p><p>生命、格擋與狀態數值會顯示在各自角色附近；點擊敵人可在指定牌或敵方消耗品選取目標。</p></details>`;
  }
  return `<div id="battle-overlay" role="dialog" aria-modal="true" aria-labelledby="battle-overlay-title" aria-describedby="battle-overlay-description"><section class="battle-overlay-panel" tabindex="-1"><div class="battle-overlay-heading"><div><span class="eyebrow">戰鬥資訊</span><h2 id="battle-overlay-title">${titles[battleOverlay] || '戰鬥資訊'}</h2></div><button id="battle-overlay-close" class="icon-only" aria-label="關閉戰鬥資訊" title="關閉">${icon('close')}</button></div><p id="battle-overlay-description" class="sr-only">只在此浮層中操作；關閉後返回原本的戰鬥控制。</p><div class="battle-overlay-content">${content}</div></section></div>`;
}

function battleView() {
  const selected = run.hand.find(instance => instance.uid === selectedUid);
  const selectedCard = cardInstance(selected);
  const empowermentAvailable = run.resonance >= 3;
  const hand = (run.hand || []).map(instance => {
    const item = cardInstance(instance);
    const unaffordable = Boolean(item && run.energy < item.cost);
    return cardHtml(instance, { action: `data-play="${esc(instance.uid)}"`, selected: instance.uid === selectedUid, disabled: unaffordable, status: unaffordable ? '能量不足' : '', title: unaffordable ? `需要 ${item.cost} 能量，目前 ${run.energy}` : '', ariaLabel: unaffordable ? `${item?.name || '未知牌'}，能量不足` : undefined });
  }).join('');
  const targetHint = selectedPotion ? '選擇敵人使用消耗品；不消耗能量。' : selectedCard ? (selectedCard.target === 'enemy' ? '選擇一名存活敵人。' : inputMode === 'touch' ? '按「出牌」確認；目前不消耗能量。' : '此牌將作用於旅人。') : '選擇一張牌查看目標。';
  const currentUniverse = run.currentUniverse || 'neutral';
  const background = BATTLE_ASSETS.backgrounds[currentUniverse];
  const backgroundStyle = background ? `style="--battle-bg-image:url('${esc(background)}')"` : '';
  const player = run.player || {};
  const character = CHARACTERS.find(item => item.id === run.characterId);
  const heroVitals = combatantVitals({
    current: player.hp,
    max: player.maxHp,
    block: player.block,
    className: 'actor-stats',
    statuses: [
      player.strength ? `<span>力量 ${player.strength}</span>` : '',
      player.thorns ? `<span>荊棘 ${player.thorns}</span>` : '',
      player.charge ? `<span>蓄氣 ${player.charge}/9</span>` : '',
      player.exhaustGuard ? `<span>放逐格擋 ${player.exhaustGuard}</span>` : '',
    ],
  });
  const selectedPotionData = selectedPotion ? POTIONS.find(item => item.id === run.potions.find(potion => potion.uid === selectedPotion)?.potionId) : null;
  const selection = selectedCard || selectedPotionData ? `<section class="card-selection" aria-live="polite"><div class="selection-copy"><span class="eyebrow">${selectedPotionData ? '選擇目標' : selectedCard.target === 'enemy' ? '選擇目標' : '已選卡牌'}</span><strong>${esc(selectedPotionData?.name || selectedCard.name)}${selectedCard ? ` <span class="cost">${selectedCard.cost}</span>` : ''}</strong><span>${esc(selectedPotionData?.text || selectedCard.text)}</span></div><div class="selection-actions"><button id="cancel-card" class="secondary">${icon('cancel')}<span>取消</span></button>${inputMode === 'touch' && selectedCard && selectedCard.target !== 'enemy' ? `<button id="confirm-card" class="primary">${icon('confirm')}<span>出牌</span></button>` : ''}</div></section>` : '';
  return `<section class="battle-page" data-battle-root aria-label="戰鬥畫面">${battleTopbar()}<section class="battle-layout battle-layout-art"><section class="battle-main"><section class="battle-stage enemies-panel" data-battle-stage data-battle-universe="${esc(currentUniverse)}" ${backgroundStyle}><div class="stage-heading"><div><span class="eyebrow">CROSS-UNIVERSE BATTLEFIELD</span><h2 data-current-universe="${esc(currentUniverse)}">${esc(universe(currentUniverse).name)}戰線</h2></div><span class="stage-help">${selectedPotion || selectedCard?.target === 'enemy' ? '點擊敵人選擇目標' : '選牌預覽；敵人意圖在頭頂'}</span></div><div class="stage-lanes"><div class="hero-lane"><div class="hero-combatant player-card" data-hero-actor data-combatant="player"><span class="actor-label">我方 · ${esc(player.name || '旅人')}<small class="actor-trait">${esc(character?.traitName || '')}</small></span><span class="actor-art-wrap">${heroSpriteMarkup()}</span>${heroVitals}</div></div><div class="stage-bridge" data-fx-layer aria-hidden="true"><span class="bridge-mark">接力</span></div><div class="enemy-lane"><div class="enemy-lane-heading"><h2>敵方意圖</h2><span class="help">${(run.enemies || []).length} 名敵人</span></div><div class="enemy-list">${(run.enemies || []).map(enemyHtml).join('')}</div></div></div></section><section class="battle-bottom-dock" aria-label="戰鬥操作"><div class="battle-command battle-command-left"><div class="battle-resource" aria-label="目前能量">${icon('energy', 'resource-icon resource-icon-energy')}<span><small>能量</small><strong>${run.energy || 0}/3</strong></span></div><div class="quick-actions"><div class="piles pile-cluster"><button class="pile-button" data-pile="draw" aria-label="查看抽牌堆">${icon('draw')}<span>抽牌</span><b>${run.draw.length}</b></button><button class="pile-button" data-pile="deck" aria-label="查看牌組">${icon('build')}<span>牌組</span><b>${run.deck.length}</b></button></div><button class="pile-button empower-button" id="empower" aria-pressed="${empowerChoice}" ${empowermentAvailable ? '' : 'disabled'} aria-label="${empowerChoice ? '取消手動強化' : '手動強化；需要 3 共鳴'}" title="${empowermentAvailable ? '出牌前消耗 3 共鳴強化攻擊或格擋牌' : '需要 3 共鳴'}">${icon('empower')}<span>${empowerChoice ? '強化中' : '強化'}</span><b>3</b></button></div></div><section class="hand-panel" id="hand-section"><div class="hand-heading"><div class="hand-heading-copy"><h2>手牌 · ${run.hand.length}/10</h2><span class="hand-target-hint">${esc(targetHint)}</span></div></div><p class="notice">${empowerChoice ? '3 共鳴已準備；符合條件的牌會強化首段傷害與首個格擋。' : ''}</p><div class="hand-scroll"><div class="card-grid hand-grid">${hand || '<p class="empty">手牌已空。</p>'}</div></div>${selection}</section><div class="battle-command battle-command-right">${potionView({ compact: true })}<div class="quick-actions"><div class="piles pile-cluster"><button class="pile-button" data-pile="discard" aria-label="查看棄牌堆">${icon('discard')}<span>棄牌</span><b>${run.discard.length}</b></button><button class="pile-button" data-pile="exile" aria-label="查看放逐區">${icon('exile')}<span>放逐</span><b>${run.exile.length}</b></button></div></div><button class="primary end-turn" id="end"><span>結束回合</span></button></div></section></section></section></section>`;
}

function rewardView() {
  return `<section class="single-view panel stack"><div class="split"><div><span class="eyebrow">戰鬥勝利</span><h2>選一張牌加入牌組</h2><button data-pile="deck">查看當局牌組 ${run.deck.length}</button></div><span class="gold-chip">${run.gold} 冒險金幣</span></div><p class="help">新牌只屬於本次冒險，會在下一場戰鬥進入牌組。</p>${buildView()}${potionView()}<div class="card-grid reward-grid">${(run.rewards || []).map(id => cardHtml(card(id), { action: `data-reward="${esc(id)}"` })).join('')}</div><button id="skip">跳過獎勵</button></section>`;
}

function campView() {
  const upgrades = (run.deck || []).filter(instance => !instance.upgraded);
  return `<section class="single-view panel stack"><span class="eyebrow">營火</span><h2>恢復或升級</h2>${playerHtml()}<p class="help">生命跨節點保留；每張牌只能升級一次。也可以跳過。</p><div class="camp-actions"><button class="primary" id="rest">休息：恢復 ${Math.min(run.player.maxHp - run.player.hp, Math.ceil(run.player.maxHp * .25))} HP</button><button id="leave">跳過營火</button></div><h3>升級一張牌</h3><div class="card-grid upgrade-grid">${upgrades.map(instance => cardHtml(instance, { action: `data-upgrade="${esc(instance.uid)}"`, previewUpgrade: true, extra: `aria-label="升級 ${esc(cardInstance(instance)?.name || '未知卡牌')}"` })).join('') || '<p class="empty">沒有可升級的牌。</p>'}</div></section>`;
}

function shopView() {
  const shop = run.shop || { cards: [], relic: null, removalPrice: 60 };
  return `<section class="shop-layout"><section class="panel shop-main"><div class="split"><div><span class="eyebrow">商店</span><h2>裂界補給</h2></div><span class="gold-chip">${run.gold} 冒險金幣</span></div><div class="shop-section"><h3>技能牌 · 每張限購一次</h3><div class="card-grid">${(shop.cards || []).map(entry => cardHtml(card(entry.id), { action: `data-buy-card="${esc(entry.id)}"`, disabled: entry.sold || run.gold < entry.price, status: entry.sold ? '已售出' : `${entry.price} 冒險金幣`, title: entry.sold ? '已售出' : `購買需要 ${entry.price} 冒險金幣` })).join('')}</div></div><div class="shop-section"><h3>遺物</h3>${shop.relic ? `<div class="shop-relic"><div><strong>${esc(RELICS.find(item => item.id === shop.relic.id)?.name || shop.relic.id)}</strong><p>${esc(RELICS.find(item => item.id === shop.relic.id)?.text || '')}</p></div><button data-buy-relic="${esc(shop.relic.id)}" ${shop.relic.sold || run.gold < shop.relic.price ? 'disabled' : ''}>${shop.relic.sold ? '已售出' : `購買 ${shop.relic.price} 冒險金幣`}</button></div>` : '<p class="help">本店沒有遺物。</p>'}</div><div class="shop-section"><h3>移除牌</h3><p class="help">${shop.removalPrice} 冒險金幣；角色固定牌鎖定，牌組至少保留一張。</p><div class="card-grid removal-grid">${(run.deck || []).map(instance => { const fixed = instance.fixed === true; const disabled = fixed || shop.removed || run.gold < shop.removalPrice || run.deck.length <= 1; const status = fixed ? '角色固定牌 · 鎖定' : shop.removed ? '本店已移除一張牌' : run.deck.length <= 1 ? '至少保留一張' : `${shop.removalPrice} 冒險金幣`; return cardHtml(instance, { action: `data-remove="${esc(instance.uid)}"`, disabled, status, title: fixed ? '角色固定牌不可移除' : shop.removed ? '本店已移除一張牌' : `移除需要 ${shop.removalPrice} 冒險金幣` }); }).join('')}</div></div><button id="leave" class="primary">離開商店</button></section><aside class="panel shop-side"><h2>遺物欄</h2>${relicList()}${playerHtml()}</aside></section>`;
}

function eventView() {
  return `<section class="single-view panel stack event-panel"><span class="eyebrow">事件</span><h2>${esc(run.currentNode?.label || '未知事件')}</h2>${playerHtml()}<p class="lede">${esc(run.currentNode?.description || '裂界中的選擇會改變本次冒險。')}</p><div class="event-options"><button data-event="risk" ${run.player.hp > 8 ? '' : 'disabled'}><strong>承受 8 傷害</strong><span>取得一個尚未持有的遺物；若沒有可用遺物，改得 30 冒險金幣。</span></button><button data-event="heal"><strong>尋找療癒</strong><span>恢復 6 HP，安全前進。</span></button></div></section>`;
}

const tutorialRelaySequence = [
  { id: 'kunai_barrage', resonance: 0, label: '忍術' },
  { id: 'ki_focus', resonance: 1, label: '氣功' },
  { id: 'wooden_guard', resonance: 2, label: '武士' },
  { id: 'venom_needle', resonance: 3, label: '忍術' },
];

function tutorialView() {
  const relayCard = tutorialRelaySequence[tutorialStep] || tutorialRelaySequence[0];
  const relayName = card(relayCard.id)?.name || relayCard.id;
  const kiName = card('ki_focus')?.name || '氣功卡';
  const meteorName = card('meteor_release')?.name || '流星卡';
  const canEmpowerTutorial = tutorialResonance >= 3;
  const relayStatus = tutorialEmpowered
    ? '已結算：出牌前先有 3 共鳴；若牌有傷害，首段傷害 +4；若牌有格擋，首個格擋也 +4（兩者可同時），並消耗 3 共鳴。'
    : tutorialEmpowerArmed
      ? '已勾選準備強化，但尚未出牌；目前仍保留 3 共鳴，出牌時才會扣除。'
    : tutorialNeutralUsed
      ? `中立牌不打斷接力；目前仍為 ${tutorialResonance}/3 共鳴。`
      : `目前示範：${relayCard.label}「${relayName}」後為 ${tutorialResonance}/3 共鳴。`;
  const chargeStatus = tutorialChargeSpent
    ? `${meteorName} 已示範消耗 ${tutorialChargeSpent} 蓄氣：8 + 3 × ${tutorialChargeSpent} = ${8 + 3 * tutorialChargeSpent} 傷害，蓄氣歸零。`
    : `示範資源：蓄氣 ${tutorialCharge}/9。`;
  return `<div class="modal tutorial-modal" id="tutorial-modal" data-tutorial="modal" ${tutorialOpen ? '' : 'hidden'} aria-hidden="${tutorialOpen ? 'false' : 'true'}"><section class="panel stack" role="dialog" aria-modal="true" aria-labelledby="tutorial-title" tabindex="-1"><div class="split"><div><span class="eyebrow">可重開 · 不改實戰</span><h2 id="tutorial-title">接力與蓄氣教學</h2></div><button id="tutorial-close" data-tutorial="close">關閉</button></div><div class="tutorial-tabs" aria-label="教學主題"><button data-tutorial-tab="relay" aria-pressed="${tutorialTab === 'relay'}">共鳴接力</button><button data-tutorial-tab="charge" aria-pressed="${tutorialTab === 'charge'}">蓄氣（蓄力）資源</button></div>${tutorialTab === 'relay' ? `<section class="tutorial-section" data-tutorial="relay-panel"><p class="help">依序點選四張牌，觀察共鳴如何累積：忍術 0 → 氣功 1 → 武士 2 → 忍術 3；中立牌不打斷。共鳴最多 3，跨回合保留、每場戰鬥重置。</p><div class="tutorial-steps" role="list" aria-label="共鳴四步示範">${tutorialRelaySequence.map((step, index) => `<button data-tutorial-step="${index}" data-tutorial-card="${esc(step.id)}" aria-current="${index === tutorialStep ? 'step' : 'false'}"><span>${index + 1}</span><b>${esc(step.label)}</b><small>${esc(card(step.id)?.name || step.id)} · ${step.resonance}</small></button>`).join('')}</div><div class="tutorial-demo" data-tutorial="relay-state"><strong>練習結果：${tutorialResonance}/3 共鳴</strong><p>${esc(relayStatus)}</p><div class="row"><button data-tutorial-action="neutral" aria-pressed="${tutorialNeutralUsed}">模擬中立牌（不打斷）</button><button data-tutorial-action="empower" aria-pressed="${tutorialEmpowerArmed}" ${canEmpowerTutorial ? '' : 'disabled'}>${tutorialEmpowerArmed ? '已勾選強化（等待出牌）' : '先勾手動強化'}</button><button data-tutorial-action="play" data-tutorial-card="${esc(relayCard.id)}" ${tutorialEmpowerArmed ? '' : 'disabled'}>模擬出牌：${esc(relayName)}</button></div></div><p class="notice">強化必須在出牌前已有 3 共鳴；同一張牌不能用自己產生的共鳴湊滿再強化。若同一張牌同時有攻擊與格擋，首段傷害與首個格擋各 +4，並非二選一。</p></section>` : `<section class="tutorial-section" data-tutorial="charge-panel"><p class="help">「蓄力」在本遊戲稱為「蓄氣」，上限 9，跨回合保留、每場戰鬥重置。不是每張攻擊牌都會自動消耗蓄氣。</p><div class="tutorial-demo" data-tutorial="charge-state"><strong>練習結果：${esc(chargeStatus)}</strong><p><b>${esc(kiName)}</b>：獲得 3 蓄氣；<b>${esc(meteorName)}</b>：基礎 8 傷害，消耗已有蓄氣後每點 +3。蓄氣 n 點時為 8 + 3 × n，耗完。</p><div class="row"><button data-tutorial-action="charge" ${tutorialCharge >= 9 ? 'disabled' : ''}>模擬${esc(kiName)} +3</button><button data-tutorial-action="meteor" ${tutorialCharge < 3 ? 'disabled' : ''}>模擬${esc(meteorName)}（消耗目前蓄氣）</button></div></div><p class="notice">空悟本回合首次費用至少 2 的牌結算後才獲得 2 蓄氣；其他角色沒有這個被動。蓄氣消耗只由有明確消耗文字的牌觸發。</p></section>`}</section></div>`;
}

function runView() {
  if (!run) return homeView();
  if (run.phase === 'map') return mapView();
  if (run.phase === 'battle') return battleView();
  if (run.phase === 'reward') return rewardView();
  if (run.phase === 'camp') return campView();
  if (run.phase === 'shop') return shopView();
  if (run.phase === 'event') return eventView();
  const won = run.phase === 'won';
  return `<section class="terminal panel stack"><span class="eyebrow">冒險結算</span><h2>${won ? '裂界已平定' : '旅人倒下'}</h2><p class="lede">${won ? '七層路線完成，跨宇宙接力留下了新的牌路。' : '本次冒險結束；收藏、冒險金幣與永久牌組不受影響。'}</p><div class="terminal-stats"><span>出牌 ${run.metrics?.cardsPlayed || 0}</span><span>造成 ${run.metrics?.damageDealt || 0}</span><span>接力 ${run.metrics?.relays || 0}</span><span>強化 ${run.metrics?.empowered || 0}</span></div><button class="primary" id="return">返回主選單</button></section>`;
}

function render(options = {}) {
  const rules = document.querySelector('#rules');
  if (rules) rulesOpen = rules.open;
  if (options.focus === undefined) pendingFocus = focusRef(document.activeElement);
  clearBattleArt();
  setTheme();
  const menuScreens = ['title', 'play', 'setup', 'achievements', 'replace'];
  const page = menuScreens.includes(tab) ? menuView({screen:tab,campaign,profile,builds:excludedBuilds,notice:storageNotice||campaignNotice,feedback,seed}) : tab === 'collection' ? collectionView() : tab === 'run' ? runView() : homeView();
  app.innerHTML = `${menuScreens.includes(tab) ? '' : header()}<div class="view-root">${page}</div><div class="modal" id="modal" ${pile ? '' : 'hidden'} aria-hidden="${pile ? 'false' : 'true'}"><section class="panel stack" role="dialog" aria-modal="true" aria-labelledby="pile-title" tabindex="-1"><div class="split"><h2 id="pile-title">${pile ? esc({ deck: '牌組', draw: '抽牌堆（僅顯示組成）', discard: '棄牌堆', exile: '放逐區' }[pile] || '牌堆') : ''}</h2><button id="close-modal">關閉</button></div><div class="pile-list">${pile ? (pileItems(pile) || '<p class="empty">此牌堆為空。</p>') : ''}</div></section></div>${battleOverlayView()}${tutorialView()}`;
  const battleRoot = app.querySelector('[data-battle-root]');
  if (battleOverlay && battleRoot) {
    battleRoot.setAttribute('inert', '');
    battleRoot.setAttribute('aria-hidden', 'true');
  }
  const activeModal = battleOverlay ? '#battle-overlay' : tutorialOpen ? '#tutorial-modal' : pile ? '#modal' : null;
  if (activeModal) {
    for (const child of [...app.children]) {
      if (child.matches(activeModal)) continue;
      child.setAttribute('inert', '');
      child.setAttribute('aria-hidden', 'true');
    }
  }
  const focus = options.focus === undefined ? pendingFocus : options.focus;
  queueMicrotask(() => {
    if (battleOverlay) {
      const overlay = document.querySelector('#battle-overlay');
      const restored = findFocus(focus);
      if (restored && !restored.disabled && overlay?.contains(restored)) restored.focus({ preventScroll: true });
      else overlay?.querySelector('#battle-overlay-close')?.focus({ preventScroll: true });
    } else if (tutorialOpen) {
      const restored = findFocus(focus);
      if (restored && !restored.disabled && document.querySelector('#tutorial-modal')?.contains(restored)) restored.focus({ preventScroll: true });
      else document.querySelector('#tutorial-close')?.focus();
    }
    else if (pile) document.querySelector('#close-modal')?.focus();
    else { const target=findFocus(focus); if(target) target.focus({preventScroll:true}); else app.querySelector('button:not(:disabled)')?.focus({preventScroll:true}); }
    pendingFocus = null;
  });
}

function openPile(kind) {
  if (!['deck', 'draw', 'discard', 'exile'].includes(kind)) { say('未知牌堆。'); render(); return; }
  modalReturnFocus = focusRef(document.activeElement);
  pile = kind;
  render({ focus: null });
}

function closeModal() {
  const focus = modalReturnFocus;
  modalReturnFocus = null;
  pile = null;
  render({ focus });
}

function openBattleOverlay(kind) {
  if (!['menu', 'log', 'build', 'rules'].includes(kind) || tab !== 'run' || run?.phase !== 'battle') return;
  battleOverlayReturnFocus = focusRef(document.activeElement);
  battleOverlay = kind;
  pile = null;
  modalReturnFocus = null;
  tutorialOpen = false;
  render({ focus: null });
}

function closeBattleOverlay() {
  const focus = battleOverlayReturnFocus;
  battleOverlayReturnFocus = null;
  battleOverlay = null;
  render({ focus });
}

function openTutorial() {
  tutorialReturnFocus = battleOverlayReturnFocus || focusRef(document.activeElement);
  battleOverlayReturnFocus = null;
  battleOverlay = null;
  pile = null;
  modalReturnFocus = null;
  tutorialOpen = true;
  render({ focus: null });
}

function closeTutorial() {
  const focus = tutorialReturnFocus;
  tutorialReturnFocus = null;
  tutorialOpen = false;
  render({ focus });
}

function persistProgress() {
  campaign=checkpoint(campaign,run||campaign.run,run?runId:campaign.runId,profile);
  profile.stats={...campaign.stats};
  if(!campaignPersistenceBlocked && !saveCampaign(storage,campaign)) campaignNotice='無法寫入冒險存檔；本次可繼續遊玩，重新整理可能回到較早進度。';
}
function finish() {
  persistProgress();
  if(run && ['won','lost'].includes(run.phase)) { saveProfile(profile,storage); recorded=true; }
}
function navigate(next, push=true) {
  if(push) screens.push({tab,focus:focusRef(document.activeElement)});
  tab=next; selectedUid=null;selectedPotion=null;battleOverlay=null;battleOverlayReturnFocus=null;pile=null;
  render({focus:null});window.scrollTo(0,0);
}
function applyBuildFilters() {
  const manualCards=draftExcludedCards.filter(id=>!appliedBuildCards.includes(id));
  const configured=configuredDeck({...profile,deck:draftDeck,excludedCards:manualCards},excludedBuilds);
  appliedBuildCards=buildExclusions(excludedBuilds,profile.characterId).excludedCards.filter(id=>!manualCards.includes(id));
  draftDeck=configured.deck;draftExcludedCards=configured.excludedCards;
}
function menuAction(action) {
  if(action==='back') {const previous=screens.pop();tab=previous?.tab||'title';render({focus:previous?.focus||null});return;}
  if(action==='title') {persistProgress();screens=[];navigate('title',false);return;}
  if(action==='play') {navigate('play');return;}
  if(action==='achievements') {persistProgress();navigate('achievements');return;}
  if(action==='collection') {navigate('collection');return;}
  if(action==='new') {run=null;runId=null;excludedBuilds=[];appliedBuildCards=[];replaceReady=false;draftDeck=[...profile.deck];draftExcludedCards=profile.excludedCards.filter(id=>!(campaign.buildExcludedCards||[]).includes(id));navigate('setup');return;}
  if(action==='continue') {
    if(!campaign.run)return;
    run=structuredClone(campaign.run);runId=campaign.runId;excludedBuilds=[...(run.excludedBuilds||[])];recorded=false;screens=[];say('已恢復上次冒險。');navigate('run',false);return;
  }
  if(action==='reset-builds') {excludedBuilds=[];render();return;}
  if(action==='choose-character') {applyBuildFilters();navigate('home');return;}
  if(action==='setup-back') {navigate('setup');return;}
  if(action==='cancel-replace') {navigate('home',false);return;}
  if(action==='confirm-replace') {replaceReady=true;startAdventure();return;}
}
function startAdventure() {
  if(run) {say('冒險進行中，請從「當局」繼續挑戰。');render();return;}
  if(campaign.run&&!replaceReady) {navigate('replace');return;}
  saveSeed((document.querySelector('#seed')?.value||seed).trim()||'裂界-001');
  const candidate=structuredClone(profile);
  const valid=act(()=>setLoadout(candidate,[...draftDeck],[...draftExcludedCards]));
  if(!valid?.ok){render();return;}
  const filters=buildExclusions(excludedBuilds,profile.characterId);
  const result=act(()=>createRun({deck:[...draftDeck],seed,characterId:profile.characterId,excludedCards:[...draftExcludedCards],excludedBuilds:[...excludedBuilds],excludedRelics:filters.excludedRelics}));
  if(!result?.phase){render();return;}
  campaignPersistenceBlocked=false;campaign.buildExcludedCards=[...appliedBuildCards];profile=candidate;run=result;runId=crypto.randomUUID();tab='run';screens=[];recorded=false;replaceReady=false;selectedUid=null;selectedPotion=null;empowerChoice=false;
  lastRelay={from:'neutral',to:'neutral',reason:''};save();say('登塔開始：先選擇第一層節點。');render({focus:null});window.scrollTo(0,0);
}

function update(fn, relayFrom = null, artAction = null) {
  const beforeUniverse = run?.currentUniverse || 'neutral';
  const beforeLogLength = run?.log?.length || 0;
  const result = act(fn);
  if(result?.ok) say(run?.log?.at(-1)||'');
  if (result?.ok && run) {
    const to = run.currentUniverse || 'neutral';
    if (to !== beforeUniverse && to !== 'neutral') {
      const newLog = (run.log || []).slice(beforeLogLength);
      const reason = [...newLog].reverse().find(entry => /跨宇宙接力/.test(entry)) || `跨宇宙接力：${universe(beforeUniverse || relayFrom || 'neutral').name} → ${universe(to).name}`;
      lastRelay = { from: beforeUniverse || relayFrom || 'neutral', to, reason };
    }
  }
  selectedUid = null; selectedPotion=null;
  empowerChoice = false;
  finish();
  render();
  if (result?.ok && artAction) queueMicrotask(() => playBattleArt(document.querySelector('[data-battle-stage]'), artAction));
  return result;
}

function selectCard(instance, item) {
  selectedUid = instance.uid;
  selectedPotion = null;
  say(item.target === 'enemy' ? `已選擇「${item.name}」；請點擊存活敵人。` : `已預覽「${item.name}」；按「出牌」確認。`);
  render({ focus: { type: 'data', key: 'play', value: instance.uid } });
}

function cancelCardSelection() {
  const selected = selectedUid;
  const potion = selectedPotion;
  selectedUid = null;
  selectedPotion = null;
  empowerChoice = false;
  say('已取消選牌。');
  const focus = selected ? { type: 'data', key: 'play', value: selected } : potion ? { type: 'data', key: 'potion', value: potion } : null;
  render({ focus });
}

function confirmSelectedCard() {
  const instance = run?.hand.find(item => item.uid === selectedUid);
  const item = cardInstance(instance);
  if (!instance || !item) { selectedUid = null; say('找不到這張牌。'); render(); return; }
  if (item.target === 'enemy') { say('請選擇存活敵人。'); render({ focus: { type: 'data', key: 'play', value: instance.uid } }); return; }
  update(() => playCard(run, instance.uid, null, empowerChoice && canEmpower(instance)), run.currentUniverse || 'neutral', cardArtAction(item));
}

app.addEventListener('click', event => {
  const button = event.target.closest('button');
  if (!button || !app.contains(button)) return;
  if (button.dataset.pile) { modalReturnFocus = focusRef(button); return; }
  if (button.id === 'close-modal') { event.stopImmediatePropagation(); closeModal(); }
}, true);

const setInputMode = mode => {
  inputMode = mode;
  document.documentElement.dataset.input = mode;
};

app.addEventListener('pointerdown', event => {
  setInputMode(event.pointerType === 'touch' ? 'touch' : 'mouse');
}, true);

app.addEventListener('touchstart', () => setInputMode('touch'), { capture: true, passive: true });

app.addEventListener('click', event => {
  const button = event.target.closest('button');
  if (!button || !app.contains(button) || button.disabled) return;
  const data = button.dataset;
  if(data.menu) {menuAction(data.menu);return;}
  if(data.build) {excludedBuilds=excludedBuilds.includes(data.build)?excludedBuilds.filter(id=>id!==data.build):[...excludedBuilds,data.build];render();return;}
  if (data.battleOverlay) {
    if (data.battleOverlay === 'close') closeBattleOverlay();
    else openBattleOverlay(data.battleOverlay);
    return;
  }
  if (button.id === 'battle-overlay-close') { closeBattleOverlay(); return; }
  if (data.tutorialOpen !== undefined) { openTutorial(); return; }
  if (button.id === 'tutorial-close') { closeTutorial(); return; }
  if (data.tutorialTab) { tutorialTab = data.tutorialTab; render(); return; }
  if (data.tutorialStep !== undefined) {
    const step = Number(data.tutorialStep);
    if (Number.isInteger(step) && tutorialRelaySequence[step]) {
      tutorialStep = step;
      tutorialResonance = tutorialRelaySequence[step].resonance;
      tutorialNeutralUsed = false;
      tutorialEmpowerArmed = false;
      tutorialEmpowered = false;
    }
    render();
    return;
  }
  if (data.tutorialAction) {
    if (data.tutorialAction === 'neutral') tutorialNeutralUsed = true;
    if (data.tutorialAction === 'empower' && tutorialResonance >= 3) tutorialEmpowerArmed = !tutorialEmpowerArmed;
    if (data.tutorialAction === 'play' && tutorialEmpowerArmed) { tutorialEmpowerArmed = false; tutorialEmpowered = true; tutorialResonance = 0; }
    if (data.tutorialAction === 'charge') { tutorialCharge = Math.min(9, tutorialCharge + 3); tutorialChargeSpent = 0; }
    if (data.tutorialAction === 'meteor' && tutorialCharge >= 3) { tutorialChargeSpent = tutorialCharge; tutorialCharge = 0; }
    render();
    return;
  }
  if (data.tab) { navigate(data.tab); return; }
  if (button.id === 'close-modal') { closeModal(); return; }
  if (data.pile) { openPile(data.pile); return; }
  if (data.character) {
    if (run) { say('冒險進行中，角色與起始配置已鎖定。'); render(); return; }
    const result=act(()=>applyCharacter(profile,data.character));
    if(result?.ok){ profile.excludedCards=[]; draftDeck=[...profile.deck]; draftExcludedCards=[]; applyBuildFilters(); save(); say('已選擇角色並載入專屬起始牌。'); }
    render();
    return;
  }
  if (data.preset) {
    if (run) { say('冒險進行中，起始配置已鎖定。'); render(); return; }
    const candidate = { ...profile, excludedCards: [...draftExcludedCards] };
    const result = act(() => applyPreset(candidate, data.preset));
    if (result?.ok) { profile = candidate; draftDeck = [...profile.deck]; draftExcludedCards = [...profile.excludedCards]; save(); say('已載入起始牌組，保留角色固定牌與本局排除。'); }
    render();
    return;
  }
  if (button.id === 'start') {startAdventure();return;}
  if (button.id === 'save-loadout') {
    if (run) { say('冒險進行中，起始配置已鎖定。'); render(); return; }
    const result = act(() => setLoadout(profile, [...draftDeck], [...draftExcludedCards]));
    if (result?.ok) { profile.excludedCards = [...draftExcludedCards]; save(); say('起始牌組與本局排除已儲存。'); }
    render();
    return;
  }
  if ((data.exclude||data.include) && buildExclusions(excludedBuilds,profile.characterId).excludedCards.includes(data.exclude||data.include)) {say('此卡屬於已排除流派，請回冒險設定重新開放該流派。');render();return;}
  if (data.exclude) {
    if (run) { say('冒險進行中，本局排除已鎖定。'); render(); return; }
    if (fixedCardIds().includes(data.exclude)) { say('角色固定牌不可排除。'); render(); return; }
    if (isExcluded(data.exclude)) {
      draftExcludedCards = draftExcludedCards.filter(id => id !== data.exclude);
      say(`已取消本局排除「${card(data.exclude)?.name || data.exclude}」；需要時可重新加入草稿。`);
      render();
      return;
    }
    draftExcludedCards = [...new Set([...draftExcludedCards, data.exclude])];
    const removed = draftDeck.filter(id => id === data.exclude).length;
    draftDeck = draftDeck.filter(id => id !== data.exclude);
    say(`本局排除「${card(data.exclude)?.name || data.exclude}」${removed ? `，已移除 ${removed} 張草稿副本` : ''}；請補滿 10 張。`);
    render();
    return;
  }
  if (data.include) {
    if (run) { say('冒險進行中，本局排除已鎖定。'); render(); return; }
    draftExcludedCards = draftExcludedCards.filter(id => id !== data.include);
    say(`已取消本局排除「${card(data.include)?.name || data.include}」；需要時可重新加入草稿。`);
    render();
    return;
  }
  if (data.addDeck) {
    if (run) { say('冒險進行中，起始配置已鎖定。'); render(); return; }
    if (isExcluded(data.addDeck)) { say('這張牌已本局排除，請先取消排除。'); render(); return; }
    const item = card(data.addDeck);
    const limit = item ? capFor(item.id) : 0;
    const count = draftDeck.filter(id => id === data.addDeck).length;
    if (item && owned(item.id) > count && count < limit && draftDeck.length < 10) {
      draftDeck.push(data.addDeck);
      say(`已加入 ${item.name}；牌組 ${draftDeck.length}/10。`);
    } else say('此牌未收藏、已達持有上限，或牌組已滿。');
    render();
    return;
  }
  if (data.removeDeck !== undefined) {
    if (run) { say('冒險進行中，起始配置已鎖定。'); render(); return; }
    const index = Number(data.removeDeck);
    if (Number.isInteger(index) && index >= 0 && index < draftDeck.length) {
      if (isDraftFixedAt(index)) say('角色固定牌的第一份不可移除；可移除額外同名副本。');
      else { draftDeck.splice(index, 1); say(`自訂牌組 ${draftDeck.length}/10。`); }
    }
    render();
    return;
  }
  if (button.id === 'pack') {
    const result = act(() => openPack(profile));
    if (result?.ok) { save(); say(`獲得：${result.cards.map(id => card(id)?.name || '未知卡牌').join('、')}`); }
    render();
    return;
  }
  if (button.id === 'coins') { addTestCoins(profile); save(); say('已取得 500 測試金。'); render(); return; }
  if (data.grant) {
    const result = act(() => grantCard(profile, data.grant));
    if (result?.ok) { save(); say(`已取得 ${card(data.grant)?.name || '未知卡牌'}。`); }
    render();
    return;
  }
  if (!run) return;
  if (data.node) { update(() => visitNode(run, data.node)); return; }
  if (button.id === 'empower') { empowerChoice = !empowerChoice; say(empowerChoice ? '已開啟手動共鳴強化。' : '已關閉手動共鳴強化。'); render(); return; }
  if (button.id === 'cancel-card') { cancelCardSelection(); return; }
  if (button.id === 'confirm-card') { confirmSelectedCard(); return; }
  if(data.potion){const instance=run.potions.find(p=>p.uid===data.potion);const potion=POTIONS.find(p=>p.id===instance?.potionId);if(!potion)return;selectedUid=null;empowerChoice=false;if(potion.target==='enemy'){selectedPotion=instance.uid;say('選擇存活敵人使用消耗品。');render();}else update(()=>usePotion(run,instance.uid));return;}
  if (data.play) {
    selectedPotion=null;
    const instance = run.hand.find(item => item.uid === data.play);
    const item = cardInstance(instance);
    if (!instance || !item) { selectedUid = null; say('找不到這張牌。'); render(); return; }
    if (run.energy < item.cost) { say(`能量不足：需要 ${item.cost}，目前 ${run.energy}。`); render(); return; }
    if (inputMode === 'touch') { selectCard(instance, item); return; }
    if (item.target === 'enemy') { selectedUid = instance.uid; say('請選擇存活敵人。'); render({ focus: { type: 'data', key: 'play', value: instance.uid } }); return; }
    update(() => playCard(run, instance.uid, null, empowerChoice && canEmpower(instance)), run.currentUniverse || 'neutral', cardArtAction(item));
    return;
  }
  if(data.enemy&&selectedPotion){update(()=>usePotion(run,selectedPotion,data.enemy));return;}
  if (data.enemy && selectedUid) {
    const instance = run.hand.find(item => item.uid === selectedUid);
    const item = cardInstance(instance);
    if (!item || item.target !== 'enemy') { selectedUid = null; say('此牌不能指定敵人。'); render(); return; }
    update(() => playCard(run, selectedUid, data.enemy, empowerChoice && canEmpower(instance)), run.currentUniverse || 'neutral', cardArtAction(item, data.enemy));
    return;
  }
  if (button.id === 'end') {
    const attackers = run.enemies.filter(e => e.hp > e.poison && e.intent?.kind === 'attack').map(e => e.id);
    const result = update(() => endTurn(run));
    if (result?.ok) playEnemyArt(document.querySelector('[data-battle-stage]'), {characterId:run.characterId, attackers});
    return;
  }
  if (data.reward) { update(() => chooseReward(run, data.reward)); return; }
  if (button.id === 'skip') { update(() => chooseReward(run, null)); return; }
  if (button.id === 'rest') { update(() => rest(run)); return; }
  if (data.upgrade) { update(() => upgradeCard(run, data.upgrade)); return; }
  if (data.buyCard) { update(() => buyCard(run, data.buyCard)); return; }
  if (data.buyRelic) { update(() => buyRelic(run, data.buyRelic)); return; }
  if (data.remove) { update(() => removeCard(run, data.remove)); return; }
  if (button.id === 'leave') { update(() => leaveNode(run)); return; }
  if (data.event) { update(() => chooseEvent(run, data.event)); return; }
  if (button.id === 'return') { run = null; runId=null; tab = 'title'; screens=[]; draftDeck = presetDeck(); render({focus:null}); }
});

app.addEventListener('input', event => {
  if (event.target.id === 'seed') saveSeed(event.target.value);
});

app.addEventListener('toggle', event => {
  if (event.target.id === 'rules') rulesOpen = event.target.open;
});

document.addEventListener('keydown', event => {
  if (battleOverlay) {
    if (event.key === 'Escape') { event.preventDefault(); event.stopImmediatePropagation(); closeBattleOverlay(); return; }
    if (event.key !== 'Tab') return;
    const overlay = document.querySelector('#battle-overlay');
    const focusable = [...(overlay?.querySelectorAll('button,[href],input,select,textarea,[tabindex]:not([tabindex="-1"])') || [])].filter(node => !node.disabled && node.offsetParent !== null);
    if (!focusable.length) { event.preventDefault(); return; }
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (!overlay.contains(document.activeElement)) { event.preventDefault(); (event.shiftKey ? last : first).focus(); }
    else if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    return;
  }
  if (!pile && !tutorialOpen) {
    if (event.key === 'Escape' && tab === 'run' && run?.phase === 'battle' && (selectedUid || selectedPotion)) {
      event.preventDefault();
      cancelCardSelection();
      return;
    }
    if(tab==='title' && ['ArrowDown','ArrowUp','Home','End'].includes(event.key)) {
      const options=[...app.querySelectorAll('.title-options button')];
      const index=options.indexOf(document.activeElement);
      const next=event.key==='Home'?0:event.key==='End'?options.length-1:(index+(event.key==='ArrowDown'?1:-1)+options.length)%options.length;
      event.preventDefault();options[next]?.focus();return;
    }
    if(event.key==='Escape' && !['INPUT','TEXTAREA'].includes(event.target.tagName)) {event.preventDefault();if(tab==='run')menuAction('title');else if(tab!=='title')menuAction('back');}
    return;
  }
  if (event.key === 'Escape') { event.preventDefault(); event.stopImmediatePropagation(); if (tutorialOpen) closeTutorial(); else closeModal(); return; }
  if (event.key !== 'Tab') return;
  const modal = document.querySelector(tutorialOpen ? '#tutorial-modal' : '#modal');
  const focusable = [...modal.querySelectorAll('button,[href],input,select,textarea,[tabindex]:not([tabindex="-1"])')].filter(node => !node.disabled && node.offsetParent !== null);
  if (!focusable.length) { event.preventDefault(); return; }
  const first = focusable[0];
  const last = focusable[focusable.length - 1];
  if (!modal.contains(document.activeElement)) { event.preventDefault(); (event.shiftKey ? last : first).focus(); }
  else if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
  else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
}, true);

profile.stats={...campaign.stats};
persistProgress();
render();
