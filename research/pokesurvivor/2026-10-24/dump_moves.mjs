// 把兩個快照的 js/data/moves.js 在 stub G 裡直接執行，傾印招式表（不手抄）。
// 用法：node dump_moves.mjs   （輸出到 generated/，該資料夾被 .gitignore 排除）
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SNAPS = {
  old: path.join(HERE, '..', '2026-10-15', 'upstream', 'js', 'data'),
  new: path.join(HERE, 'upstream', 'js', 'data'),
};

function load(dir, files) {
  const dict = {};
  const G = { I18n: { add: d => Object.assign(dict, d) }, U: { TYPE_COLOR: {}, TYPE_NAME: {} } };
  const win = { PS_LANG_Q: [] };
  const ctx = vm.createContext({ G, console, Math, window: win });
  for (const f of files) {
    const p = path.join(dir, f);
    if (fs.existsSync(p)) vm.runInContext(fs.readFileSync(p, 'utf8'), ctx, { filename: p });
  }
  // 新版把部分翻譯放在 js/lang/<locale>.js（以 PS_LANG_Q 佇列載入）
  for (const q of win.PS_LANG_Q) if (q && q[0] && typeof q[0] === 'object') Object.assign(dict, q[0]);
  return { G, dict, win };
}

function loadLang(dir, file) {
  const win = { PS_LANG_Q: [] };
  const ctx = vm.createContext({ G: { I18n: { add() {} } }, console, window: win });
  const p = path.join(dir, '..', 'lang', file);
  if (fs.existsSync(p)) vm.runInContext(fs.readFileSync(p, 'utf8'), ctx, { filename: p });
  const d = {};
  for (const q of win.PS_LANG_Q) if (q && q[0] && typeof q[0] === 'object') Object.assign(d, q[0]);
  return d;
}

const out = {};
for (const [k, dir] of Object.entries(SNAPS)) {
  const { G, dict } = load(dir, ['moves.js', 'lang-zh-hant-names.js', 'lang-zh-hant.js']);
  const dictEn = load(dir, ['lang-en.js']).dict;
  Object.assign(dict, loadLang(dir, 'zh-Hant.js'));
  const M = G.Moves;
  const moves = M.ALL.map(m => ({
    id: m.id, es: m.name, zh: dict[m.name] || '', en: dictEn[m.name] || '', type: m.type, kind: m.kind, cat: m.cat || '',
    cd: m.cd, dmg: m.dmg ?? null, count: m.count ?? null, radius: m.radius ?? null,
    burn: m.burn || 0, poison: m.poison || 0, slow: m.slow || 0, knock: m.knock || 0,
    // 舊快照 EVO[id] = [進化後招名, 條件]；新快照 EVO[id] = 條件（進化後只加「 +」）
    evo: (Array.isArray(M.EVO[m.id]) ? M.EVO[m.id][1] : M.EVO[m.id]) || '',
    evoName: Array.isArray(M.EVO[m.id]) ? M.EVO[m.id][0] : '',
    maxLvl: m.maxLvl,
  }));
  const kinds = {};
  for (const m of moves) kinds[m.kind] = (kinds[m.kind] || 0) + 1;
  const types = {};
  for (const m of moves) types[m.type] = (types[m.type] || 0) + 1;
  out[k] = {
    count: moves.length,
    kinds, types,
    evoNeed: M.NEED_NAME,
    nonBuffNoEvo: moves.filter(m => m.kind !== 'buff' && !m.evo).map(m => m.id),
    buffWithEvo: moves.filter(m => m.kind === 'buff' && m.evo).map(m => m.id),
    evoEntries: Object.keys(M.EVO || {}).length,
    moves,
  };
}

fs.mkdirSync(path.join(HERE, 'generated'), { recursive: true });
fs.writeFileSync(path.join(HERE, 'generated', 'moves.json'), JSON.stringify(out, null, 1));

const added = out.new.moves.filter(m => !out.old.moves.some(o => o.id === m.id));
const removed = out.old.moves.filter(m => !out.new.moves.some(o => o.id === m.id));
const changed = [];
for (const m of out.new.moves) {
  const o = out.old.moves.find(x => x.id === m.id);
  if (!o) continue;
  const d = {};
  for (const f of ['type', 'kind', 'cat', 'cd', 'dmg', 'count', 'radius', 'burn', 'poison', 'slow', 'knock', 'evo', 'maxLvl'])
    if (o[f] !== m[f]) d[f] = [o[f], m[f]];
  if (Object.keys(d).length) changed.push({ id: m.id, d });
}
console.log(JSON.stringify({
  old: { count: out.old.count, kinds: out.old.kinds, nonBuffNoEvo: out.old.nonBuffNoEvo },
  new: { count: out.new.count, kinds: out.new.kinds, nonBuffNoEvo: out.new.nonBuffNoEvo, buffWithEvo: out.new.buffWithEvo },
  addedCount: added.length, removedCount: removed.length, removed: removed.map(m => m.id), changed,
}, null, 1));
