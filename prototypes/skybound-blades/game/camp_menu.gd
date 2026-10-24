extends RefCounted
## Builds the camp / bag window rows from the Run and Profile, and applies the actions they
## carry. Shop, warehouse and quest hand-in only work in camp; gear can be changed anywhere.
## Pages: 補給 (shop + sell), 倉庫, 委託, 裝備, 技能 (learn, slots, chain).

const Skills = preload("res://domain/skills.gd")
const SHOP := ["tonic_small", "emergency_kit", "bandage", "ration"]
const QUALITY := {"plain": "", "fine": "精製", "rare": "稀有", "named": "傳名"}
const STAT := {"attack": "攻擊", "defense": "防禦", "max_hp": "生命", "agility": "敏捷", "crit_chance": "爆擊",
	"block_chance": "格擋"}
const ROLE := {"leader": "隊長", "guardian": "盾衛", "support": "援護"}
const SLOT := {"weapon": "武器", "offhand": "副手", "body": "身體", "head": "頭部", "feet": "腳", "ring": "戒指",
	"neck": "項鍊"}

var tuning: RefCounted
var role: String = "leader"


func _init(tuning_: RefCounted) -> void:
	tuning = tuning_


# --- Names ----------------------------------------------------------------------

func item_name(item_id: String) -> String:
	return String(tuning.items[item_id].get("name", item_id))


func gear_name(inst: Dictionary) -> String:
	var prefix: String = QUALITY.get(inst.quality, "")
	var base := String(tuning.equipment[inst.template].name)
	return ("%s %s" % [prefix, base]) if prefix != "" else base


func bonus_text(bonus: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat: String in bonus:
		var v := float(bonus[stat])
		var shown := ("%+d%%" % roundi(v * 100.0)) if stat.ends_with("_chance") else ("%+d" % int(v))
		parts.append("%s %s" % [STAT.get(stat, stat), shown])
	return "  ".join(parts)


func gear_price(inst: Dictionary) -> int:
	return int(round(float(tuning.equipment[inst.template].buy_gold) * 0.5))


func quest_name(qid: String) -> String:
	var q: Dictionary = tuning.quests[qid]
	var target := String(q.objective.target)
	match String(q.objective.type):
		"boss_kill":
			return "主線 · 封印%s" % tuning.bosses[target].get("name", target)
		"monster_kill":
			return "討伐 · %s ×%d" % [tuning.monsters[target].name, int(q.objective.count)]
		"item_count":
			return "收集 · %s ×%d" % [item_name(target), int(q.objective.count)]
	return qid


# --- Pages ----------------------------------------------------------------------

func header(run: RefCounted, profile: RefCounted, in_camp: bool) -> String:
	return "第 %d 代 · 金幣 %d · 倉庫 %d%s" % [run.generation, run.gold, profile.warehouse_gold,
		"" if in_camp else "   （在野外：只能換裝）"]


func tabs(run: RefCounted, profile: RefCounted, in_camp: bool, now_ms: float) -> Dictionary:
	return {"補給": {"rows": _supplies(run, in_camp)}, "倉庫": {"rows": _warehouse(run, profile, in_camp)},
		"委託": {"rows": _quests(run, in_camp, now_ms)}, "裝備": {"rows": _gear(run)},
		"技能": {"rows": _skills(run, in_camp)}}


func _supplies(run: RefCounted, in_camp: bool) -> Array:
	var rows: Array = []
	for item_id: String in SHOP:
		var price := int(tuning.items[item_id].buy_gold)
		rows.append({"title": "%s　持有 %d" % [item_name(item_id), run.count(item_id)],
			"detail": "每個 %d 金幣" % price,
			"actions": [{"label": "買 1", "action": {"type": "buy", "item": item_id, "qty": 1}, "enabled": in_camp and run.gold >= price},
				{"label": "買 5", "action": {"type": "buy", "item": item_id, "qty": 5}, "enabled": in_camp and run.gold >= price * 5}]})
	for item_id: String in run.stacks:
		var item: Dictionary = tuning.items.get(item_id, {})
		if item.get("kind", "") != "material" or run.free_count(item_id) <= 0:
			continue
		var each := int(item.get("sell_gold", 0))
		rows.append({"title": "賣出 %s　×%d" % [item_name(item_id), run.free_count(item_id)],
			"detail": "每個 %d 金幣" % each,
			"actions": [{"label": "賣 1", "action": {"type": "sell_item", "item": item_id, "qty": 1}, "enabled": in_camp},
				{"label": "全賣", "action": {"type": "sell_item", "item": item_id, "qty": run.free_count(item_id)}, "enabled": in_camp}]})
	for inst: Dictionary in run.bag_gear():
		if bool(inst.issued):
			continue
		rows.append({"title": "賣出 %s" % gear_name(inst), "detail": "%s　售價 %d" % [bonus_text(inst.bonus), gear_price(inst)],
			"actions": [{"label": "賣出", "action": {"type": "sell_gear", "id": inst.id}, "enabled": in_camp}]})
	return rows


func _warehouse(run: RefCounted, profile: RefCounted, in_camp: bool) -> Array:
	var rows: Array = [
		{"title": "金幣　身上 %d · 倉庫 %d" % [run.gold, profile.warehouse_gold], "detail": "倉庫的金幣跨代保留",
			"actions": [{"label": "全部存入", "action": {"type": "deposit_gold", "amount": run.gold}, "enabled": in_camp and run.gold > 0},
				{"label": "取出 50", "action": {"type": "withdraw_gold", "amount": mini(50, profile.warehouse_gold)},
					"enabled": in_camp and profile.warehouse_gold > 0}]},
	]
	for item_id: String in run.stacks:
		if run.free_count(item_id) > 0:
			rows.append({"title": "存入 %s　×%d" % [item_name(item_id), run.free_count(item_id)], "detail": "",
				"actions": [{"label": "全部存入", "action": {"type": "deposit_item", "item": item_id, "qty": run.free_count(item_id)}, "enabled": in_camp}]})
	for inst: Dictionary in run.bag_gear():
		if not bool(inst.issued):
			rows.append({"title": "存入 %s" % gear_name(inst), "detail": bonus_text(inst.bonus),
				"actions": [{"label": "存入", "action": {"type": "deposit_gear", "id": inst.id}, "enabled": in_camp}]})
	for item_id: String in profile.warehouse_items:
		rows.append({"title": "倉庫 %s　×%d" % [item_name(item_id), int(profile.warehouse_items[item_id])], "detail": "",
			"actions": [{"label": "取出全部", "action": {"type": "withdraw_item", "item": item_id, "qty": int(profile.warehouse_items[item_id])}, "enabled": in_camp}]})
	for gid: String in profile.warehouse_gear:
		var inst: Dictionary = profile.warehouse_gear[gid]
		rows.append({"title": "倉庫 %s" % gear_name(inst), "detail": bonus_text(inst.bonus),
			"actions": [{"label": "取出", "action": {"type": "withdraw_gear", "id": gid}, "enabled": in_camp}]})
	return rows


func _quests(run: RefCounted, in_camp: bool, now_ms: float) -> Array:
	var rows: Array = []
	for qid: String in run.quests:
		var q: Dictionary = tuning.quests[qid]
		var state: Dictionary = run.quests[qid]
		var reward: Dictionary = q.reward
		var status := ""
		if not bool(q.repeatable) and int(state.claims) > 0:
			status = "已完成"
		elif now_ms < float(state.available_at_ms):
			status = "冷卻中"
		else:
			status = "%d / %d" % [run.quest_progress(qid), int(q.objective.count)]
		rows.append({"title": "%s　%s" % [quest_name(qid), status],
			"detail": "報酬 %d EXP · %d 金幣%s" % [int(reward.get("exp", 0)), int(reward.get("gold", 0)),
				"　（交出素材）" if bool(q.consume_on_claim) else ""],
			"actions": [{"label": "回報", "action": {"type": "claim", "quest": qid}, "enabled": in_camp and run.quest_ready(qid, now_ms)}]})
	return rows


func _gear(run: RefCounted) -> Array:
	var rows: Array = []
	var pick: Array = []
	for r: String in ROLE:
		pick.append({"label": ("▶ " if r == role else "") + ROLE[r], "action": {"type": "pick_role", "role": r}, "enabled": true})
	var stats: Dictionary = run.member_stats(role)
	rows.append({"title": "%s　攻擊 %d · 防禦 %d · 生命 %d" % [ROLE[role], int(stats.attack), int(stats.defense), int(stats.max_hp)],
		"detail": "攻擊間隔 %.2f 秒 · 爆擊 %d%%%s" % [stats.attack_ms / 1000.0, roundi(stats.crit_chance * 100.0),
			" · 格擋 %d%%" % roundi(stats.block_chance * 100.0) if stats.block_chance > 0.0 else ""],
		"actions": pick})
	for slot: String in SLOT:
		var gid: String = (run.equipped.get(role, {}) as Dictionary).get(slot, "")
		if gid == "":
			continue
		var inst: Dictionary = run.gear[gid]
		rows.append({"title": "%s：%s" % [SLOT[slot], gear_name(inst)], "detail": bonus_text(inst.bonus),
			"actions": [{"label": "卸下", "action": {"type": "unequip", "role": role, "slot": slot}, "enabled": true}]})
	for inst: Dictionary in run.bag_gear():
		rows.append({"title": "背包：%s" % gear_name(inst), "detail": "%s　%s" % [bonus_text(inst.bonus), _delta(run, inst)],
			"actions": [{"label": "裝備", "action": {"type": "equip", "role": role, "id": inst.id}, "enabled": true}]})
	return rows


## Stat change if the selected role wore this piece, e.g. "→ 攻擊 +2 · 生命 -15".
func _delta(run: RefCounted, inst: Dictionary) -> String:
	var slot: String = tuning.equipment[inst.template].slot
	var worn: Array = []
	for gid: String in run.equipped_ids(role):
		if tuning.equipment[run.gear[gid].template].slot != slot:
			worn.append(run.gear[gid])
	worn.append(inst)
	var after: Dictionary = tuning.member_stats(role, run.level, worn)
	var now: Dictionary = run.member_stats(role)
	var parts := PackedStringArray()
	for stat: String in ["attack", "defense", "max_hp"]:
		var d := int(round(float(after[stat]) - float(now[stat])))
		if d != 0:
			parts.append("%s %+d" % [STAT[stat], d])
	return ("→ " + " · ".join(parts)) if not parts.is_empty() else "→ 無變化"


## The leader's skills: chain header, then every skill of the weapon style with what it needs and leaves.
func _skills(run: RefCounted, in_camp: bool) -> Array:
	var role := "leader"
	var chain := Skills.chain(run, role)
	var names := PackedStringArray()
	for id: String in chain:
		names.append(Skills.skill_name(tuning, id))
	var slots := Skills.slot_count(tuning, run.level)
	var rows: Array = [{"title": "連攜印 %d · 技能格 %d · 連招：%s" % [int(run.seals), slots, " → ".join(names) if not names.is_empty() else "—"],
		"detail": "接上一招花 1 個連攜印；解除不退印。後一招要接得住前一招留下的標記",
		"actions": [{"label": "解除最後一段", "action": {"type": "unlink"}, "enabled": in_camp and chain.size() > 1}]}]
	var style: String = run.member_stats(role).style
	for id: String in Skills.style_skills(tuning, style):
		var def: Dictionary = tuning.skills[id]
		var mastery := Skills.mastery_level(run, role, id)
		var iface := "需要「%s」→ 留下「%s」" % [Skills.tag_name(tuning, def.get("needs")), Skills.tag_name(tuning, def.get("leaves"))]
		if mastery == 0:
			var block := Skills.learn_block(tuning, run, role, id)
			rows.append({"title": "%s　未學會" % def.name, "detail": "%s · %s" % [iface, block if block != "" else "可以學習"],
				"actions": [{"label": "學習", "action": {"type": "learn", "skill": id}, "enabled": in_camp and block == ""}]})
			continue
		var entry: Dictionary = run.learned[role][id]
		var status := ""
		if id in chain:
			status = "連招第 %d 招" % (chain.find(id) + 1)
		elif id in (run.slots.get(role, []) as Array):
			status = "第 %d 格" % ((run.slots[role] as Array).find(id) + 1)
		var link_block := Skills.link_block(tuning, run, role, id)
		var actions: Array = []
		for i in mini(slots, 2):
			actions.append({"label": "放第 %d 格" % (i + 1), "action": {"type": "equip_skill", "skill": id, "slot": i},
				"enabled": in_camp and Skills.equip_block(tuning, run, role, id, i) == ""})
		actions.append({"label": "接上連招", "action": {"type": "link", "skill": id}, "enabled": in_camp and link_block == ""})
		rows.append({"title": "%s　熟練 %d（%d / %d）%s" % [def.name, mastery, int(entry.exp), Skills.mastery_need(mastery),
			"　" + status if status != "" else ""],
			"detail": "%s%s" % [iface, "" if link_block == "" or id in chain else " · 不能接：" + link_block],
			"actions": actions})
	return rows


# --- Actions --------------------------------------------------------------------

## Applies a non-battle action. Returns a toast line ("" = nothing to say). Claims go through
## the battle (they pay EXP and may level the party), so the field sends those as commands.
func apply(a: Dictionary, run: RefCounted, profile: RefCounted, in_camp: bool) -> String:
	match String(a.type):
		"pick_role":
			role = a.role
			return ""
		"equip":
			run.equip(a.role, a.id)
			return "已裝備 %s" % gear_name(run.gear[a.id])
		"unequip":
			run.unequip(a.role, a.slot)
			return "已卸下"
	if not in_camp:
		return "回到營地才能使用"
	match String(a.type):
		"buy":
			var price := int(tuning.items[a.item].buy_gold) * int(a.qty)
			if run.gold < price:
				return "金幣不足"
			run.gold -= price
			run.add_item(a.item, int(a.qty))
			return "購買 %s ×%d" % [item_name(a.item), int(a.qty)]
		"sell_item":
			if not run.take_free(a.item, int(a.qty)):
				return "數量不足"
			run.gold += int(tuning.items[a.item].sell_gold) * int(a.qty)
			return "賣出 %s ×%d" % [item_name(a.item), int(a.qty)]
		"sell_gear":
			var inst: Dictionary = run.gear.get(a.id, {})
			if inst.is_empty() or run.holder_of(a.id) != "" or bool(inst.issued):
				return "這件不能賣"
			run.gear.erase(a.id)
			run.gold += gear_price(inst)
			return "賣出 %s" % gear_name(inst)
		"deposit_gold":
			return "已存入倉庫" if profile.deposit_gold(run, int(a.amount)) else "沒有可存的金幣"
		"withdraw_gold":
			return "已取出" if profile.withdraw_gold(run, int(a.amount)) else "倉庫金幣不足"
		"deposit_item":
			return "已存入倉庫" if profile.deposit_item(run, a.item, int(a.qty)) else "配發品不能存倉"
		"withdraw_item":
			return "已取出" if profile.withdraw_item(run, a.item, int(a.qty)) else "倉庫數量不足"
		"deposit_gear":
			return "已存入倉庫" if profile.deposit_gear(run, a.id) else "穿著中或配發的裝備不能存倉"
		"withdraw_gear":
			return "已取出" if profile.withdraw_gear(run, a.id) else "找不到這件裝備"
		"learn":
			var why := Skills.learn(tuning, run, "leader", a.skill)
			return why if why != "" else "學會了%s" % Skills.skill_name(tuning, a.skill)
		"equip_skill":
			var why := Skills.equip(tuning, run, "leader", a.skill, int(a.slot))
			return why if why != "" else "%s放進第 %d 格" % [Skills.skill_name(tuning, a.skill), int(a.slot) + 1]
		"link":
			var why := Skills.link(tuning, run, "leader", a.skill)
			return why if why != "" else "連招接上%s（剩 %d 個連攜印）" % [Skills.skill_name(tuning, a.skill), int(run.seals)]
		"unlink":
			var why := Skills.unlink_last(tuning, run, "leader")
			return why if why != "" else "已解除最後一段（連攜印不退）"
	return ""
