"""把 generated/observe-rift-run*.json 與 observe-rift.json 的每次試驗去重後彙整成表（generated/tables-rift.md）。
去重鍵：(label, boss 血量損失速度, 競技場最後樣本時間)。"""
import json, glob, statistics as st
from pathlib import Path

HERE = Path(__file__).resolve().parent
files = sorted(glob.glob(str(HERE / 'generated' / 'observe-rift-run*.json'))) + [str(HERE / 'generated' / 'observe-rift.json')]
seen, runs = set(), []
for f in files:
    d = json.loads(Path(f).read_text(encoding='utf8'))
    for label, rec in d.items():
        s = rec.get('summary')
        if not s:
            continue
        s['hpDpsBoss'] = s.get('hpDpsBoss') or round((s['bossHpFirst'] - s['bossHpLast']) / max(0.1, s['arenaTimeLast'] - s['arenaTimeFirst']), 1)
        key = (label, s.get('hpDpsBoss'), s.get('arenaTimeLast'))
        if key in seen:
            continue
        seen.add(key)
        won = rec.get('wonSeen')
        runs.append(dict(label=label, file=Path(f).name, legend=rec['setup']['legend']['name'], behavior=rec['setup']['legend']['behavior'],
                         hp=rec['setup']['legend']['maxHp'], dps=s['hpDpsBoss'], direct=s['avgDps'],
                         won=bool(won), kill=won['at'] if won else None, bossLast=s['bossHpLast'], tlast=s['arenaTimeLast'],
                         hit=rec.get('hitSummary'), share=s.get('moveDealtShare'), dist=(s.get('distAvg'), s.get('distMin'), s.get('distMax')),
                         lv=(rec.get('afterBond') or rec.get('afterArena') or rec.get('final') or {}).get('level')))
order = ['single', 'group4', 'single-ranged', 'group4-ranged']
NAME = {'single': '單招（火花 Lv.1）', 'group4': '4 招羈絆組（火花＋噴射火焰＋火焰旋渦＋熱風，全 Lv.1）',
        'single-ranged': '單招（火花 Lv.1）', 'group4-ranged': '4 招羈絆組'}
rows = ['| 配置 | 傳說（行為） | 第幾次 | boss 血量損失速度 HP/s | 直接命中 DPS | 結果 | 競技場時間 s | 被打次數／平均每擊（首擊 s） |', '|---|---|---|---|---|---|---|---|']
summary = ['', '| 配置 | 傳說 | n | HP/s（最小～最大，平均） | 擊殺時間 s（贏的場次） | 輸（逾時）場次 |', '|---|---|---|---|---|---|']
for lab in order:
    rs = [r for r in runs if r['label'] == lab]
    for i, r in enumerate(rs, 1):
        h = r['hit']
        hit = f"{h['count']}／{h['avgPerHit']}（{h['firstHitAfter']}）" if h else '—（早期版本未記錄）'
        res = f"贏，{r['kill']:.1f}" if r['won'] else f"**輸／逾時**（剩 {r['bossLast']} HP）"
        rows.append(f"| {NAME[lab]} | {r['legend']}（{r['behavior']}） | {i} | {r['dps']} | {r['direct']} | {res.split('，')[0] if r['won'] else res} | {r['kill']:.1f} | {hit} |" if r['won'] else
                    f"| {NAME[lab]} | {r['legend']}（{r['behavior']}） | {i} | {r['dps']} | {r['direct']} | {res} | {r['tlast']} | {hit} |")
    if rs:
        dps = [r['dps'] for r in rs]
        kills = [r['kill'] for r in rs if r['won']]
        summary.append(f"| {NAME[lab]} | {rs[0]['legend']}（{rs[0]['behavior']}） | {len(rs)} | {min(dps)}～{max(dps)}，平均 {st.mean(dps):.1f} | "
                       f"{('、'.join(f'{k:.1f}' for k in kills) + f'（平均 {st.mean(kills):.1f}）') if kills else '—'} | {len([r for r in rs if not r['won']])} |")
out = '\n'.join(rows) + '\n' + '\n'.join(summary) + '\n'
(HERE / 'generated' / 'tables-rift.md').write_text(out, encoding='utf8')
print(out)
print('per-move share (group runs):')
for r in runs:
    if r['share'] and r['label'].startswith('group4'):
        print(' ', r['label'], r['file'], {k: v for k, v in r['share'].items() if v}, 'dist avg/min/max', r['dist'])
print('levels after fight:', [(r['label'], r['lv']) for r in runs])
