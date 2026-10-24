"""由 generated/moves.json（dump_moves.mjs 產出）產生報告用的表格，寫到 generated/tables.md。
用法：node dump_moves.mjs && python3 gen_tables.py
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
d = json.loads((HERE / 'generated' / 'moves.json').read_text(encoding='utf8'))
new, old = d['new'], d['old']
old_ids = {m['id'] for m in old['moves']}

TYPE_ZH = {'normal': '一般', 'fire': '火', 'water': '水', 'grass': '草', 'electric': '電', 'psychic': '超能力', 'poison': '毒',
           'ground': '地面', 'flying': '飛行', 'bug': '蟲', 'rock': '岩石', 'ice': '冰', 'fighting': '格鬥', 'ghost': '幽靈',
           'dragon': '龍', 'fairy': '妖精', 'steel': '鋼', 'dark': '惡'}
KIND_ZH = {'projectile': '投射物', 'melee': '近戰', 'beam': '光束', 'orbit': '繞身', 'nova': '放射', 'aura': '光環', 'buff': '增益',
           'boomerang': '迴力鏢', 'chain': '連鎖', 'mine': '地雷', 'meteor': '落石', 'turret': '砲台', 'dash': '衝刺', 'trail': '拖尾',
           'cone': '扇形', 'homing': '追蹤', 'bounce': '彈跳', 'charge': '蓄力光束', 'spin': '旋轉', 'quake': '震波', 'vortex': '漩渦',
           'shove': '推擠', 'stun': '暈眩區'}
CAT_ZH = {'physical': '物', 'special': '特', '': '—'}
# 強化卡：id → (專案既有中文名, 西文卡名)
CARD = {'hp': ('體力', 'Vigor'), 'atk': ('力量', 'Potencia'), 'spd': ('速度', 'Carrera'), 'cd': ('反射', 'Reflejos'),
        'def': ('硬殼', 'Coraza'), 'rgn': ('光合', 'Síntesis'), 'mag': ('磁力', 'Imán'), 'xp': ('學習', 'Aprendizaje')}
STATUS = lambda m: '／'.join(x for x, k in (('燒', 'burn'), ('毒', 'poison'), ('緩', 'slow')) if m[k]) or '—'

lines = []
# 1. 進化配對（依強化卡分組）
by = {}
for m in new['moves']:
    if m['evo']:
        by.setdefault(m['evo'], []).append(m)
lines.append('| 需要的強化卡 | 招式數 | 可進化的招式（中文名／id；＊＝10-19 新增） |')
lines.append('|---|---|---|')
for k in ['atk', 'cd', 'spd', 'hp', 'rgn', 'def', 'mag', 'xp']:
    ms = by.get(k, [])
    cell = '、'.join(f"{m['zh']}（{m['id']}）{'＊' if m['id'] not in old_ids else ''}" for m in ms) or '（無）'
    lines.append(f"| {CARD[k][0]}（{CARD[k][1]}，`{k}`） | {len(ms)} | {cell} |")
n_evo = sum(len(v) for v in by.values())
buffs = [m['zh'] for m in new['moves'] if m['kind'] == 'buff']
lines.append(f"\n合計 {n_evo} 招有進化配對；沒有配對的只有增益招（{'、'.join(buffs)}）。非增益招全部都有配對（`nonBuffNoEvo` 為空）。")
(HERE / 'generated' / 'tables-evo.md').write_text('\n'.join(lines) + '\n', encoding='utf8')

# 2. 新增 39 招
add = [m for m in new['moves'] if m['id'] not in old_ids]
L = ['| 招式（id） | 屬性 | 種類 | 物/特 | 冷卻 | 傷害 | 狀態 | 進化卡 |', '|---|---|---|---|---|---|---|---|']
for m in add:
    L.append(f"| {m['zh']}／{m['en']}（{m['id']}） | {TYPE_ZH[m['type']]} | {KIND_ZH[m['kind']]} | {CAT_ZH[m['cat']]} | {m['cd']} | {m['dmg'] if m['dmg'] is not None else '—'} | {STATUS(m)} | {CARD[m['evo']][0] if m['evo'] else '—'} |")
(HERE / 'generated' / 'tables-new-moves.md').write_text('\n'.join(L) + '\n', encoding='utf8')

# 3. 全部 103 招（依屬性）
L = ['| 屬性 | 招式（id） | 種類 | 物/特 | 冷卻 s | 傷害 | 範圍/數量 | 狀態 | 進化卡 |', '|---|---|---|---|---|---|---|---|---|']
order = list(TYPE_ZH)
for m in sorted(new['moves'], key=lambda x: (order.index(x['type']), x['kind'], x['id'])):
    rng = '／'.join(str(v) for v in (m['radius'], m['count']) if v is not None) or '—'
    L.append(f"| {TYPE_ZH[m['type']]} | {m['zh']}（{m['id']}）{'＊' if m['id'] not in old_ids else ''} | {KIND_ZH[m['kind']]} | {CAT_ZH[m['cat']]} | {m['cd']} | {m['dmg'] if m['dmg'] is not None else '—'} | {rng} | {STATUS(m)} | {CARD[m['evo']][0] if m['evo'] else '—'} |")
(HERE / 'generated' / 'tables-all-moves.md').write_text('\n'.join(L) + '\n', encoding='utf8')

# 4. 種類統計（新舊）
L = ['| 種類 | 舊（10-14）| 新（10-23）|', '|---|---|---|']
for k in KIND_ZH:
    L.append(f"| {KIND_ZH[k]}（{k}） | {old['kinds'].get(k, 0)} | {new['kinds'].get(k, 0)} |")
L.append(f"| **合計** | {old['count']} | {new['count']} |")
(HERE / 'generated' / 'tables-kinds.md').write_text('\n'.join(L) + '\n', encoding='utf8')
print('ok', {k: len(by.get(k, [])) for k in CARD}, 'added', len(add), 'total', new['count'])
