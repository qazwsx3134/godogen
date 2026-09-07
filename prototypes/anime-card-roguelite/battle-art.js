const ROOT = './assets/visual-v1/';
const ACTION_ROOT = './assets/visual-v2/';
export const HERO_ACTIONS = Object.freeze(Object.fromEntries(['shadow_ninja','ki_fighter','silver_ronin'].map(id => [id, Object.freeze({attack: `${ACTION_ROOT}hero-${id}-attack.png`, hurt: `${ACTION_ROOT}hero-${id}-hurt.png`})])));

export const BATTLE_ASSETS = Object.freeze({
  heroes: Object.freeze({
    shadow_ninja: `${ACTION_ROOT}hero-shadow_ninja-idle.png`,
    ki_fighter: `${ACTION_ROOT}hero-ki_fighter-idle.png`,
    silver_ronin: `${ACTION_ROOT}hero-silver_ronin-idle.png`,
  }),
  cameo: `${ROOT}cameo-shinpachi.png`,
  enemies: Object.freeze({
    raider: `${ROOT}enemy-raider.png`,
    boss: `${ROOT}enemy-boss.png`,
  }),
  backgrounds: Object.freeze({
    ninja: `${ACTION_ROOT}bg-ninja-wide.png`,
    dragon: `${ROOT}bg-dragon.png`,
    samurai: `${ROOT}bg-samurai.png`,
  }),
  fx: `${ROOT}fx-energy.png`,
  beam: `${ROOT}fx-beam.png`,
});

const timers = new Set();
const cleanups = new Set();

function later(callback, delay) {
  const timer = setTimeout(() => {
    timers.delete(timer);
    callback();
  }, delay);
  timers.add(timer);
  return timer;
}

function remember(cleanup, delay) {
  cleanups.add(cleanup);
  later(() => {
    cleanup();
    cleanups.delete(cleanup);
  }, delay);
}

function temporaryClass(element, className, delay) {
  if (!element) return;
  element.classList.add(className);
  remember(() => element.classList.remove(className), delay);
}

function sprite(className, image) {
  const element = document.createElement('span');
  element.className = className;
  element.dataset.battleArt = className;
  element.style.setProperty('--sprite-image', `url("${image}")`);
  return element;
}

function temporaryNode(parent, element, delay) {
  if (!parent || !element) return;
  parent.append(element);
  remember(() => element.remove(), delay);
}

function enemyTarget(stage, targetId) {
  if (!targetId) return null;
  return [...stage.querySelectorAll('[data-enemy]')].find(node => node.dataset.enemy === String(targetId)) || null;
}

function enemyTargets(stage, targetId) {
  const target = enemyTarget(stage, targetId);
  if (target) return [target];
  return [...stage.querySelectorAll('[data-enemy]:not(.dead)')];
}

export function clearBattleArt() {
  for (const timer of timers) clearTimeout(timer);
  timers.clear();
  for (const cleanup of cleanups) cleanup();
  cleanups.clear();
}

export function playBattleArt(stage, action = {}) {
  if (!stage || !stage.isConnected) return;
  const hero = stage.querySelector('[data-hero-actor]');
  const fxLayer = stage.querySelector('[data-fx-layer]');
  const targets = enemyTargets(stage, action.targetId);
  const hasDamage = Boolean(action.hasDamage);
  if (hasDamage) playHeroAction(stage, action.characterId, 'attack');
  const hasBlock = Boolean(action.hasBlock);
  const isWide = action.cardId === 'kame_wave' || action.target === 'all';

  if (hasDamage) {
    temporaryClass(hero, 'art-lunge', 520);
    if (isWide && fxLayer) {
      temporaryNode(fxLayer, sprite('fx-sprite widebeam-fx', BATTLE_ASSETS.beam), 640);
    }
    for (const target of targets) {
      const targetLayer = target.querySelector('.enemy-art-wrap') || target;
      temporaryNode(targetLayer, sprite('fx-sprite impact-fx', BATTLE_ASSETS.fx), 520);
      temporaryClass(target, 'art-hit', 420);
    }
  }

  if (hasBlock && hero) {
    temporaryNode(hero, sprite('fx-sprite shield-fx', BATTLE_ASSETS.fx), 660);
    temporaryClass(hero, 'art-shield', 660);
  }

  if (action.cardId === 'sarcastic_counter' && fxLayer) {
    const cameo = sprite('cameo-sprite', BATTLE_ASSETS.cameo);
    const caption = document.createElement('span');
    caption.className = 'comic-caption';
    caption.dataset.battleArt = 'counter-caption';
    caption.textContent = '吐槽！';
    const group = document.createElement('span');
    group.className = 'counter-cameo';
    group.append(cameo, caption);
    temporaryNode(fxLayer, group, 900);
  }
}


function playHeroAction(stage, characterId, action) {
  const node = stage.querySelector('.actor-art-wrap .hero-sprite');
  const sheet = HERO_ACTIONS[characterId]?.[action];
  if (!node || !sheet) return;
  const original = node.style.getPropertyValue('--sprite-image');
  node.classList.remove('sprite-idle');
  node.dataset.action = action;
  node.style.setProperty('--sprite-image', `url("${sheet}")`);
  node.classList.add('sprite-action');
  remember(() => {
    node.style.setProperty('--sprite-image', original);
    node.classList.remove('sprite-action');
    node.classList.add('sprite-idle');
    delete node.dataset.action;
  }, 620);
}

export function playEnemyArt(stage, { characterId, attackers = [] } = {}) {
  if (!stage?.isConnected || !attackers.length) return;
  playHeroAction(stage, characterId, 'hurt');
  const hero = stage.querySelector('[data-hero-actor]');
  temporaryClass(hero, 'art-recoil', 620);
  for (const id of attackers) temporaryClass(enemyTarget(stage, id), 'enemy-lunge', 480);
}

export function preloadBattleAssets() {
  const sources = [...Object.values(BATTLE_ASSETS.heroes), ...Object.values(BATTLE_ASSETS.backgrounds),
    ...Object.values(BATTLE_ASSETS.enemies), BATTLE_ASSETS.cameo, BATTLE_ASSETS.fx, BATTLE_ASSETS.beam,
    ...Object.values(HERO_ACTIONS).flatMap(Object.values)];
  for (const src of sources) { const img = new Image(); img.src = src; }
}
