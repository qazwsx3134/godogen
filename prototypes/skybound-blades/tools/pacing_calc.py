#!/usr/bin/env python3
"""C1 only: reproducible planning model, Python standard library, no game imports.

Run: python3 prototypes/skybound-blades/tools/pacing_calc.py
--write-report writes only production/reviews/codex-pacing.md.
--self-check checks analytic damage, EXP carry, and minute-by-minute commissions.
This is an expected-damage surrogate, not a stochastic survival/Boss simulator.
"""
from __future__ import annotations

import argparse
import bisect
import copy
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "design/tuning-draft.json"
REPORT = ROOT / "production/reviews/codex-pacing.md"
WALK_SECONDS = 3.0  # Assumption, not a tuning field.
HUB_SECONDS = 60.0  # Assumption, only optional quest scenario.
MINUTES = 480


def round_positive(x):
    return math.floor(x + 0.5)


def mean_rounded_damage(atk, defense, power, data):
    """Exact integral of max(1, round(atk*power*U-defense*factor))."""
    lo, hi = data["combat"]["damage_variance"]
    lo = atk * power * lo - defense * data["combat"]["defense_factor"]
    hi = atk * power * hi - defense * data["combat"]["defense_factor"]
    if hi == lo:
        return float(max(1, round_positive(lo)))
    total = max(0.0, min(hi, 1.5) - lo)
    for n in range(2, math.ceil(hi + 0.5) + 1):
        overlap = max(0.0, min(hi, n + 0.5) - max(lo, n - 0.5))
        total += n * overlap
    return total / (hi - lo)


def expected_hit(atk, defense, data, power=1.0, block_chance=0.0):
    c = data["combat"]
    hit = max(c["min_hit"], min(c["max_hit"], c["base_hit"] - c["base_evade"]))
    crit = 1.0 + c["crit_chance"] * (c["crit_multiplier"] - 1.0)
    block = 1.0 - block_chance * (1.0 - c["shield_block_damage_ratio"])
    return mean_rounded_damage(atk, defense, power, data) * hit * crit * block


def xp_needed(level, data):
    # The literal formula is validated in self_check; coefficient is a scenario patch.
    coefficient = data.get("_xp_coefficient", 200)
    return math.ceil(coefficient * level ** 1.8)


def penalty(level, monster_level, data):
    return max(0.1, 0.8 ** max(0, level - monster_level - 3))


def add_xp(level, xp, reward, data):
    xp += reward  # Assumption: fractional EXP carries, no per-award integer truncation.
    while level < data["simulation"]["max_level"] and xp + 1e-9 >= xp_needed(level, data):
        xp -= xp_needed(level, data)
        level += 1
    return level, xp


def members(level, party, data):
    templates = {e["id"]: e for e in data["equipment_templates"]}
    profiles = {w["id"]: w for w in data["weapon_profiles"]}
    h = data["hero"]
    roles = ["leader", "guardian", "support"] if party else ["leader"]
    result = []
    for role in roles:
        ratios = data["party"]["roles"][role]
        items = [templates[i] for i in data["party"]["initial_equipment"][role]]
        bonus = {}
        for item in items:
            for stat, value in item["bonus"].items():
                bonus[stat] = bonus.get(stat, 0) + value
        atk = (h["attack_base"] + h["attack_per_level"] * (level - 1)) * ratios["attack_ratio"] + bonus.get("attack", 0)
        defense = (h["defense_base"] + h["defense_per_level"] * (level - 1)) * ratios["defense_ratio"] + bonus.get("defense", 0)
        hp = (h["hp_base"] + h["hp_per_level"] * (level - 1)) * ratios["hp_ratio"] + bonus.get("max_hp", 0)
        agility = h["agility_base"] + h["agility_per_level"] * (level - 1) + bonus.get("agility", 0)
        weapon = next(i for i in items if i["slot"] == "weapon")
        speed = profiles[weapon["style"]]["speed_ratio"]
        if any(i["slot"] == "offhand" for i in items) and weapon["style"] != "mace":
            speed *= data["combat"]["shield_speed_ratio_non_mace"]
        interval = max(data["combat"]["attack_min_ms"], data["combat"]["attack_base_ms"] / (1 + agility / 100) / speed)
        result.append(dict(role=role, attack=atk, defense=defense, hp=hp,
                           interval=interval, block=bonus.get("block_chance", 0)))
    return result


def encounter(level, monster, party, data):
    """Periodic attack timestamps; ceil absolute timestamps to 50ms; retain phase.

    All actors first hit after one attack interval. Both sides' same-tick hits
    resolve together. One foe at a time, focused fire. Enemy hits guardian in
    party case (explicit target sensitivity, NOT guaranteed by 4s/10s taunt).
    """
    actors = members(level, party, data)
    damages = [expected_hit(a["attack"], monster["defense"], data) for a in actors]
    step = data["simulation"]["step_ms"]
    hit_numbers = [1] * len(actors)
    total = 0.0
    while total + 1e-9 < monster["hp"]:
        due = [math.ceil((a["interval"] * n - 1e-9) / step) * step for a, n in zip(actors, hit_numbers)]
        time_ms = min(due)
        for index, at in enumerate(due):
            if at == time_ms:
                total += damages[index]
                hit_numbers[index] += 1
    victim = actors[1] if party else actors[0]
    incoming_hits = int(time_ms // monster["attack_interval_ms"])
    incoming = incoming_hits * expected_hit(monster["attack"], victim["defense"], data, block_chance=victim["block"])
    leader_incoming = incoming_hits * expected_hit(monster["attack"], actors[0]["defense"], data, block_chance=actors[0]["block"])
    return dict(seconds=time_ms/1000, damage=incoming, leader_damage=leader_incoming,
                victim_hp=victim["hp"], fatal=incoming >= victim["hp"])


def floor_for_level(level):
    # Assumption: Boss clears instantly at its recommended level; no Boss XP.
    return 1 if level < 5 else 2 if level < 10 else 3


def grind(target, party, data, walk=WALK_SECONDS, quests=False,
          duration=None, start_level=1, fixed_floor=None):
    monsters = {m["id"]: m for m in data["monsters"]}
    level, xp, time_s, kills, quest_exp, hub_count, fatal_count = start_level, 0.0, 0.0, 0, 0, 0, 0
    indices = {z["floor"]: 0 for z in data["zones"]}
    kill_quests = {q["id"]: dict(q=q, active=False, count=0, ready=0.0)
                   for q in data["quest_definitions"] if q["kind"] == "kill"}
    entered = set()
    material = {z["floor"]: 0.0 for z in data["zones"]}
    gathered = set()
    previous_floor = None
    encounter_cache = {}
    while (duration is not None and time_s < duration) or (duration is None and level < target):
        floor = fixed_floor or floor_for_level(level)
        zone = next(z for z in data["zones"] if z["floor"] == floor)
        if floor not in entered:
            entered.add(floor)
            if quests:
                for state in kill_quests.values():
                    if state["q"]["floor"] == floor:
                        state["active"] = True
        previous_floor = floor
        monster_id = zone["monster_ids"][indices[floor] % len(zone["monster_ids"])]
        monster = monsters[monster_id]
        key = (level, monster_id)
        if key not in encounter_cache:
            encounter_cache[key] = encounter(level, monster, party, data)
        fight = encounter_cache[key]
        cost = fight["seconds"] + data["simulation"]["search_ms"]/1000 + walk
        if duration is not None and time_s + cost > duration + 1e-9:
            break
        time_s += cost
        indices[floor] += 1
        kills += 1
        fatal_count += int(fight["fatal"])
        material[floor] += data["loot"]["material_chance"]
        reward = monster["base_exp"] * penalty(level, monster["level"], data)
        level, xp = add_xp(level, xp, reward, data)
        if quests:
            for state in kill_quests.values():
                obj = state["q"]["objective"]
                if state["active"] and obj["target"] == monster_id:
                    state["count"] += 1
            if indices[floor] % 15 == 0:
                if duration is not None and time_s + HUB_SECONDS > duration: break
                time_s += HUB_SECONDS
                hub_count += 1
                for state in kill_quests.values():
                    q = state["q"]
                    if q["floor"] != floor: continue
                    if state["active"] and state["count"] >= q["objective"]["count"]:
                        quest_exp += q["reward"]["exp"]
                        level, xp = add_xp(level, xp, q["reward"]["exp"], data)
                        state.update(active=False, count=0, ready=time_s + data["quests"]["repeat_cooldown_ms"]/1000)
                    elif not state["active"] and time_s >= state["ready"]:
                        state.update(active=True, count=0)
                collect = next(q for q in data["quest_definitions"] if q["kind"] == "collect" and q["floor"] == floor)
                if floor not in gathered and material[floor] >= collect["objective"]["count"]:
                    gathered.add(floor)
                    material[floor] -= collect["objective"]["count"]
                    quest_exp += collect["reward"]["exp"]
                    level, xp = add_xp(level, xp, collect["reward"]["exp"], data)
    total_xp = sum(xp_needed(l, data) for l in range(start_level, level)) + xp
    return dict(level=level, xp=xp, total_xp=total_xp, kills=kills, minutes=time_s/60,
                quest_exp=quest_exp, hubs=hub_count, fatal=fatal_count, last_floor=previous_floor)


def offline(floor, start_level, data, reference="mix", duration=MINUTES):
    zone = next(z for z in data["zones"] if z["floor"] == floor)
    monsters = {m["id"]: m for m in data["monsters"]}
    levels = [monsters[i]["level"] for i in zone["monster_ids"]]
    if reference == "min": levels = [min(levels)]
    if reference == "max": levels = [max(levels)]
    level, xp = start_level, 0.0
    total, trace = 0.0, []
    minutes = min(duration, data["commission"]["cap_ms"] // 60000)
    for minute in range(1, minutes + 1):
        # Freeze penalty at minute start; grant then carry all level-ups forward.
        factor = sum(penalty(level, ml, data) for ml in levels)/len(levels)
        reward = zone["commission_exp_per_min"] * data["commission"]["reward_ratio"] * factor
        total += reward
        level, xp = add_xp(level, xp, reward, data)
        trace.append((minute, reward, level, xp))
    return dict(level=level, xp=xp, total_xp=total, trace=trace)


def table(headers, rows):
    return "\n".join(["| " + " | ".join(headers) + " |", "|" + "|".join(["---"]*len(headers)) + "|"] +
                     ["| " + " | ".join(map(str, row)) + " |" for row in rows])


def scenario_data(data, coefficient=None, ratio=None, floor1_exp=None, search_ms=None):
    patch = copy.deepcopy(data)
    if coefficient is not None: patch["_xp_coefficient"] = coefficient
    if ratio is not None: patch["commission"]["reward_ratio"] = ratio
    if floor1_exp is not None:
        for monster_id, exp in zip(patch["zones"][0]["monster_ids"], floor1_exp):
            next(m for m in patch["monsters"] if m["id"] == monster_id)["base_exp"] = exp
    if search_ms is not None: patch["simulation"]["search_ms"] = search_ms
    return patch


def report(data, digest):
    lines = ["# C1：節奏與離線收益試算", "", "2026-10-24；僅分析，不修改 tuning、不執行 Godot。", "",
             "數字唯一來源：`design/tuning-draft.json`，SHA-256：`"+digest+"`。",
             "重現：在 repo root 執行 `python3 prototypes/skybound-blades/tools/pacing_calc.py --self-check`；不帶參數會將完整報告印到 stdout，`--write-report` 只寫本文件。", "",
             "## 結論與適用範圍", ""]
    solo = grind(5, False, data)
    party = grind(5, True, data)
    first = offline(1, 1, data)
    second = offline(2, 5, data)
    lines += [f"- 無任務、每場走路 {WALK_SECONDS:g} 秒時，L1→L5：單人 {solo['kills']} 隻／{solo['minutes']:.2f} 分，三人隊 {party['kills']} 隻／{party['minutes']:.2f} 分。這是普通怪普攻模型，未含整備與 Boss 戰。",
              f"- 第一層 8 小時委託（L1 開始）為 {first['total_xp']:.2f} EXP、L{first['level']}＋{first['xp']:.2f}；第二層由 L5 開始為 {second['total_xp']:.2f} EXP、L{second['level']}＋{second['xp']:.2f}。",
              "- B6 的累計 EXP 4,768 正確；『約 260 隻、30–45 分』不是固定結論，三人火力與每場移動時間會大幅改變結果。B7 忽略 reward_ratio 與逐分鐘衰減的直接乘法會高估。",
              "- 現有委託不超過本模型同時間實戰：8 小時累計為單人約 44–53%、三人約 32–36%。不能直接判定過強，但若單人有補給／回城損耗，安全委託的相對吸引力會上升。比較只涵蓋 EXP；無死亡風險與 Boss／稀有掉落限制仍需一起驗證。", "",
              "## 假設（與資料欄位分開）", "",
              "1. 角色從 L1、0 EXP 出發；固定初始 plain／tier 1 裝備。AI 倍率只乘基礎能力，裝備再加。所有隊員等級相同，隊伍只獲一份 EXP。未購裝、強化、換武器或承襲倉庫資源。隊員倍率產生的小數能力保留，不自行對角色基礎能力取整。",
              "2. 基準只打普通怪、普攻集火，一次一怪；不含技能、精英、Buff、毒傷及 AI 治療占用。這些省略會使時間與傷害朝不同方向偏移，所以不是完整實戰模擬，也不宣稱能驗證 Boss 可擊敗。",
              "3. 命中率依 base_hit／base_evade／上下限；爆擊依機率與倍率。將傷害浮動視為連續均勻分布，精確積分 round 後傷害。每次出手使用期望傷害，累計至怪物 HP；這不等於隨機過程的期望擊殺時間 E[TTK]。敵人也使用同一命中、爆擊與浮動規則，沒有另造敵方機率。",
              "4. 每次遭遇重置普攻相位，首擊等待一個普攻間隔（假設）；事件時間是 ceil(n×原始間隔／step_ms)×step_ms，保留餘數；怪物同 tick 攻擊與致死擊一起計算。擊殺時間不含搜尋／走路。",
              "5. 每次遭遇搜尋取 simulation.search_ms；走路額外假設 3 秒，代表附近目標接近與轉向，另列 0／8 秒敏感度。沒有地圖速度與距離資料，不宣稱 3 秒是量測值。",
              "6. 路線按各層三種怪等權輪替：L1–4 第一層、L5–9 第二層、L10 起第三層；升級時沿用未滿 EXP。Boss 門檻取建議等級，但打 Boss、通關、回城、教學與轉層時間全未計；L10／L15 表是『已能過門檻』的條件推估。",
              "7. 三人承傷基準全部落在 guardian（用其 DEF／盾格擋）；同表列出改打隊長的範圍。這是目標選擇敏感度，不能由 taunt 的 4 秒／10 秒推出全程坦怪。傷害為未治療的總入傷，不減自然回復／藥物；不模擬續航與補給耗盡。遇單場傷害達最大 HP，列為致死曝險但仍繼續試算工時，不能拿該路線當可達保證。",
              "8. 基準不計任務。另有任務情境：入層接該層兩件討伐；每 15 次當層擊殺回城，整趟加 60 秒（假設），於城內領已完成獎勵；領後按 repeat_cooldown_ms 冷卻，下次回城才可重接，不追溯累計；每 15 殺固定回城，即使當下沒有可領獎勵，也是這個情境的假設，不代表最優策略。收集以 material_chance 的期望量、消耗 5 件、每層僅一次。Boss 主線獎勵不計。",
              "9. 低等衰減使用擊殺前等級：max(0.1,0.8^max(0,L−怪物等級−3))。EXP 保留小數，沒有每筆向下取整；達 max_level 後不再升級。",
              "10. 委託的 zone 每分鐘數字解讀為『乘 reward_ratio 前基準』，EXP 再乘 0.5；每分鐘開始時計算衰減、當分鐘結算後升級。委託未給參考怪物等級，因此基準取該層三種怪衰減的算術平均，並附最小／最大怪等級兩界，並非擅自確立正式規則。",
              "11. 八小時委託假設已解鎖且有足夠口糧；第一層 L1 是解鎖後歸一化基準，並非新角色能立刻派遣。第二層 L1 僅反事實比較；正常情境 L5、0 級內 EXP。8 小時實戰是同起點、固定該層、無任務、同裝備、補給無限／零回城損耗的生產工時基準。", "",
              "## 算式與累計需求", "",
              "ATK/DEF/HP＝(base＋per_level×(L−1))×role_ratio＋起始裝備 bonus；AGI＝base＋per_level×(L−1)＋裝備 bonus。", "",
              "普攻間隔＝max(attack_min_ms,attack_base_ms／(1＋AGI/100)／weapon.speed_ratio)。", "",
              "每次出手期望傷害＝E[max(1,round(ATK×U−DEF×defense_factor))]×命中率×(1＋crit_chance×(crit_multiplier−1))；有盾再乘 (1−block_chance×(1−block_damage_ratio))。", "",
              table(["目標", "累計 EXP（從 L1）"], [(f"L{t}",sum(xp_needed(l,data) for l in range(1,t))) for t in (5,10,15)]), "",
              "## 每種普通怪：同級附近的基準遭遇", "",
              "參考角色等級＝怪物 level；避免用 L1 跨三層攻擊力混在同一表。EXP/min＝衰減後 base_exp×60／(擊殺秒數＋搜尋秒數＋3 秒走路)。全部為上述期望傷害模型。", ""]
    rows = []
    for monster in data["monsters"]:
        level = monster["level"]
        s = encounter(level,monster,False,data)
        p = encounter(level,monster,True,data)
        incoming = f"{p['damage']:.2f}–{p['leader_damage']:.2f}"
        rows.append((monster["id"],level,f"{s['seconds']:.2f}",f"{s['damage']:.2f}",
                     f"{monster['base_exp']*60/(s['seconds']+data['simulation']['search_ms']/1000+WALK_SECONDS):.2f}",
                     f"{p['seconds']:.2f}",incoming,
                     f"{monster['base_exp']*60/(p['seconds']+data['simulation']['search_ms']/1000+WALK_SECONDS):.2f}"))
    lines += [table(["怪物","角色 L","單人 TTK秒","單人入傷","單人 EXP/min","三人 TTK秒","三人入傷（坦→隊長）","三人 EXP/min"],rows), "",
              "## 新角色升級路線", ""]
    rows=[]
    for t in (5,10,15):
        for party_flag in (False,True):
            r=grind(t,party_flag,data)
            q=grind(t,party_flag,data,quests=True)
            rows.append((f"L{t}","三人" if party_flag else "單人",r["kills"],f"{r['minutes']:.2f}",r["fatal"],q["kills"],f"{q['minutes']:.2f}",q["quest_exp"],q["hubs"]))
    lines += [table(["目標","隊伍","無任務擊殺","無任務分","單場致死曝險次","任務情境擊殺","任務情境分","任務 EXP","回城次"],rows),"",
              "『致死曝險』是該遭遇總期望入傷 ≥ 該次承傷角色最大 HP；0 次也不代表連續無補給可活。任務情境可能因回城成本更慢；討伐回報不是免費直接加 EXP/min。", "",
              "### L5 對走路時間的敏感度", ""]
    rows=[]
    for w in (0.0,WALK_SECONDS,8.0):
        rows.append((f"{w:g} 秒",f"{grind(5,False,data,walk=w)['minutes']:.2f}",f"{grind(5,True,data,walk=w)['minutes']:.2f}"))
    lines += [table(["每場額外走路","單人分鐘","三人分鐘"],rows),"",
              "## 八小時委託：逐分鐘衰減與同層實戰", ""]
    rows=[]
    for floor,start in ((1,1),(2,5),(2,1)):
        o=offline(floor,start,data)
        bounds=[offline(floor,start,data,r) for r in ("min","max")]
        s=grind(None,False,data,duration=MINUTES*60,start_level=start,fixed_floor=floor)
        p=grind(None,True,data,duration=MINUTES*60,start_level=start,fixed_floor=floor)
        rows.append((floor,f"L{start}",f"{o['total_xp']:.2f}",f"L{o['level']} + {o['xp']:.2f}",
                     f"{bounds[0]['total_xp']:.2f}–{bounds[1]['total_xp']:.2f}",
                     f"{s['total_xp']:.2f} / L{s['level']}",f"{p['total_xp']:.2f} / L{p['level']}",
                     f"{o['total_xp']/s['total_xp']*100:.1f}% / {o['total_xp']/p['total_xp']*100:.1f}%"))
    lines += [table(["層","起點","離線 EXP","離線終點＋級內 EXP","參考怪等級兩界 EXP","單人實戰 EXP / 終點","三人實戰 EXP / 終點","離線/實戰 單/三"],rows),"",
              "注意：衰減因升級而改變；8 小時累計比值包含這個負回饋，不是同等級瞬時收益比。第二層 L1 沒有正常解鎖路徑，僅用來比較同起點的公式。", "",
              "### 委託分鐘／小時快照（實際仍逐分鐘運算）", ""]
    rows=[]
    for floor,start in ((1,1),(2,5)):
        o=offline(floor,start,data)
        for minute in (1,60,120,240,480):
            _,reward,level,xp=o["trace"][minute-1]
            rows.append((floor,minute,f"{reward:.4f}",level,f"{xp:.2f}"))
    lines += [table(["層","分鐘","該分鐘 EXP","結算後等級","級內 EXP"],rows),"",
              "### 同等級瞬時收益比（排除升級的負回饋）", ""]
    rows=[]
    for floor,level in ((1,1),(1,5),(2,5),(2,10)):
        z=data["zones"][floor-1]
        mons=[next(m for m in data["monsters"] if m["id"]==i) for i in z["monster_ids"]]
        rate=z["commission_exp_per_min"]*data["commission"]["reward_ratio"]*sum(penalty(level,m["level"],data) for m in mons)/len(mons)
        rates=[]
        for pf in (False,True):
            cycle=sum(encounter(level,m,pf,data)["seconds"]+data["simulation"]["search_ms"]/1000+WALK_SECONDS for m in mons)
            rate_live=sum(m["base_exp"]*penalty(level,m["level"],data) for m in mons)*60/cycle
            rates.append(rate_live)
        rows.append((floor,level,f"{rate:.2f}",f"{rates[0]:.2f}",f"{rates[1]:.2f}",f"{rate/rates[0]*100:.1f}% / {rate/rates[1]*100:.1f}%"))
    lines += [table(["層","L","離線 EXP/min","單人實戰 EXP/min","三人實戰 EXP/min","離線/實戰 單/三"],rows),"",
              "### 補給與其他收益邊界", "",
              f"八小時口糧需求＝ceil({MINUTES}/60)×ration_per_started_hour＝{math.ceil(MINUTES/60)*data['commission']['ration_per_started_hour']} 份；起始僅 3 份，不能直接派滿八小時。若買全數口糧，按 buy_gold 需 {math.ceil(MINUTES/60)*data['commission']['ration_per_started_hour']*next(i['buy_gold'] for i in data['items'] if i['id']=='ration')} 金；口糧若仍視為配發 3 份，補足其餘需 {(math.ceil(MINUTES/60)*data['commission']['ration_per_started_hour']-3)*next(i['buy_gold'] for i in data['items'] if i['id']=='ration')} 金。",
              "commission.reward_ratio 是否也乘 gold 沒有精確寫明；§9 寫 EXP／素材 50%，本報告不私自確定金幣規則。素材按 §9 同乘 ratio，每層八小時 240 件（原始 1/min×0.5×480），若另外定義數值已是淨收益，結果會不同。", "",
              "## 三組可比較的數值修正（只提案，不改 tuning）", "",
              "以下保留攻擊數值與層級衰減。A／C 改 EXP 曲線會影響全等級；B 只提高第一層普通怪 EXP。三組皆採同一 3 秒走路、無任務模型，並把離線倍率一起降低作為保守候選。", ""]
    proposals = [
        ("A：全曲線加速、預留整備時間",scenario_data(data,coefficient=120,ratio=0.25),"simulation.level_xp_formula：ceil(200 * level ** 1.8) → ceil(120 * level ** 1.8)；commission.reward_ratio：0.5 → 0.25"),
        ("B：只提高第一層擊殺獎勵",scenario_data(data,floor1_exp=(18,27,38),ratio=0.25),"monsters[id=meadow_slime].base_exp：12 → 18；monsters[id=briar_boar].base_exp：18 → 27；monsters[id=ruin_hound].base_exp：25 → 38；commission.reward_ratio：0.5 → 0.25"),
        ("C：溫和曲線與縮短搜尋",scenario_data(data,coefficient=150,search_ms=1000,ratio=0.20),"simulation.level_xp_formula：ceil(200 * level ** 1.8) → ceil(150 * level ** 1.8)；simulation.search_ms：2000 → 1000；commission.reward_ratio：0.5 → 0.20"),
    ]
    rows=[]
    for name,patch,fields in proposals:
        l5s=grind(5,False,patch)
        l5p=grind(5,True,patch)
        l10=grind(10,True,patch)
        l15=grind(15,True,patch)
        o1=offline(1,1,patch)
        o2=offline(2,5,patch)
        lines += [f"### {name}", "", fields, ""]
        rows.append((name.split('：')[0],f"{l5p['kills']}",f"{l5s['minutes']:.2f} / {l5p['minutes']:.2f}",f"{l10['minutes']:.2f} / {l15['minutes']:.2f}",f"{o1['total_xp']:.2f} / L{o1['level']}",f"{o2['total_xp']:.2f} / L{o2['level']}"))
    lines += [table(["方案","L5 擊殺","L5 單/三 分","L10/L15 三人分","一層8h EXP/等級","二層8h EXP/等級（L5起）"],rows),"",
              "建議先測 B：保留整條等級曲線，只提高第一層擊殺 EXP，降低安全委託倍率；風險是跨層 EXP/min 不連續，需再檢查是否繼續留第一層最划算。A 改全曲線、影響面最大；C 的搜尋調整會影響每一層，須以目標密度與導航手感驗證。三組均以三人新手達 L5 為目標，沒有讓單人同時保證 20–30 分。整備、回城與教學仍是未量測時間，不能把工時等同完整體驗。若目標是『準備挑戰』而不是『到達 L5』，仍需驗證裝備、補給與 Boss 勝率；此報告只提供等級工時。", "",
              "## 需要主導決定／資料尚缺", "",
              "- 委託衰減參考 monster_level／monster weights 目前缺欄位；需決定用區域基準等級、怪物權重平均，或每分鐘抽樣。本文三種結果是敏感度，不是補完整規則。",
              "- commission_*_per_min 是否為 reward_ratio 前基準、金幣是否同乘 ratio，應明訂；若 72／160 已是最終 EXP/min，當前試算須移除一次 ratio，不能混用。",
              "- 技能後普攻計時、施放被取消／空轉規則、怪物實際出現權重、導航距離／速度、回城耗時、續航／補給補充與 Boss 首通成功率未提供；無法從此表推導完整新手通關時間。",
              "- 第 2／3 層普通怪開放與 Boss 建議等級、裝備 tier 可穿等級（6／11）不同；主路線按 L5／L10 立即過門，不計裝備提升。",
              "- 第 1 層委託需 10 擊殺才能解鎖；第 2 層還需完成第一 Boss。新角色沒有 8 份口糧。不能把 L1 離線表直接當成新手開局流程。", "",
              "## 驗證", "",
              "只使用 Python 3 標準庫；沒有讀取遊戲實作、執行 Godot、變更 tuning／design 或建立其他檔案。報告完整重算與檔案內容逐字相符。`--self-check` 包含常數傷害積分、數值積分交叉檢查、升級餘數、50ms 事件格線、逐分鐘委託參考式與衰減上下界驗證。", ""]
    return "\n".join(lines)


def validate_source(data):
    if data["simulation"]["level_xp_formula"] != "ceil(200 * level ** 1.8)":
        raise SystemExit("Unsupported source EXP formula; update the model before reporting")
    if data["simulation"]["low_level_xp_formula"] != "max(0.1, 0.8 ** max(0, team_level - monster_level - 3))":
        raise SystemExit("Unsupported source penalty formula; update the model before reporting")


def self_check(data):
    validate_source(data)
    assert data["simulation"]["low_level_xp_formula"] == "max(0.1, 0.8 ** max(0, team_level - monster_level - 3))"
    assert data["simulation"]["step_ms"] == 50
    assert sum(xp_needed(l,data) for l in range(1,5)) == 4768
    for attack, defense in ((20,2),(22,4),(5,40)):
        n=20000
        lo,hi=data["combat"]["damage_variance"]
        approx=sum(max(1,round_positive(attack*(lo+(i+0.5)*(hi-lo)/n)-defense*data["combat"]["defense_factor"])) for i in range(n))/n
        assert abs(approx-mean_rounded_damage(attack,defense,1,data)) < 0.001
    assert add_xp(1,0,200.25,data) == (2,0.25)
    for floor,start in ((1,1),(2,5)):
        result=offline(floor,start,data)
        assert len(result["trace"]) == MINUTES
        # Independent accumulated-XP reference: recover level using threshold
        # bisection instead of add_xp's iterative remainder subtraction.
        thresholds = [0]
        for l in range(1,data["simulation"]["max_level"]):
            thresholds.append(thresholds[-1] + xp_needed(l,data))
        base = thresholds[start-1]
        total = 0.0
        zone = data["zones"][floor-1]
        monster_levels = [m["level"] for m in data["monsters"] if m["id"] in zone["monster_ids"]]
        for minute,reward,got_level,got_xp in result["trace"]:
            prior_level = bisect.bisect_right(thresholds,base+total+1e-9)
            ref_reward = zone["commission_exp_per_min"]*data["commission"]["reward_ratio"]*sum(max(0.1,0.8**max(0,prior_level-ml-3)) for ml in monster_levels)/len(monster_levels)
            assert abs(reward-ref_reward) < 1e-8
            total += ref_reward
            ref_level = bisect.bisect_right(thresholds,base+total+1e-9)
            assert got_level == ref_level
            assert abs(got_xp-(base+total-thresholds[ref_level-1])) < 1e-6
        recovered=sum(xp_needed(l,data) for l in range(start,result["level"]))+result["xp"]
        assert abs(recovered-result["total_xp"]) < 1e-6
        assert offline(floor,start,data,"min")["total_xp"] <= result["total_xp"] <= offline(floor,start,data,"max")["total_xp"]
        trace=result["trace"]
        assert all(b[1] <= a[1]+1e-9 for a,b in zip(trace,trace[1:]))
        assert offline(floor,start,data,duration=0)["total_xp"] == 0
        assert offline(floor,start,data,duration=MINUTES+60)["total_xp"] == result["total_xp"]
    for monster in data["monsters"]:
        solo=encounter(monster["level"],monster,False,data)
        party=encounter(monster["level"],monster,True,data)
        assert party["seconds"] <= solo["seconds"]
        assert abs(solo["seconds"]*1000/data["simulation"]["step_ms"]-round(solo["seconds"]*1000/data["simulation"]["step_ms"])) < 1e-9
    print("SELF-CHECK PASS: damage integration, EXP carry, event grid, minute commission bounds/cap")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-check",action="store_true")
    parser.add_argument("--write-report",action="store_true")
    args=parser.parse_args()
    raw=SOURCE.read_bytes()
    data=json.loads(raw)
    validate_source(data)
    if args.self_check:
        self_check(data)
        if not args.write_report: return
    result=report(data,hashlib.sha256(raw).hexdigest())
    if SOURCE.read_bytes() != raw:
        raise SystemExit("tuning changed during calculation; no report written")
    if args.write_report:
        REPORT.write_text(result,encoding="utf-8")
        print(REPORT)
    else:
        print(result)


if __name__ == "__main__":
    main()
