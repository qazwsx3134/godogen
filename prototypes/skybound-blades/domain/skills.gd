extends RefCounted
## Skill rules (design/skill-links.md): learning, skill slots, mastery and chains. Static and pure: the Run holds the
## data ({learned, slots, chains, seals}); these functions read it, validate a change and apply it. Every refusal comes
## back as a sentence the camp window can show.
##
## A chain [A, B, C] is legal when B.needs == A.leaves and C.needs == B.leaves. Each link costs one seal (連攜印);
## unlinking frees nothing. A chain starts with the skill in the member's first slot and occupies only that slot.


static func links(tuning: RefCounted) -> Dictionary:
	return tuning.section("skill_links")


static func tag_name(tuning: RefCounted, tag: Variant) -> String:
	if tag == null:
		return "—"
	return String(links(tuning).tags.get(tag, tag))


static func skill_name(tuning: RefCounted, id: String) -> String:
	return String(tuning.skills[id].get("name", id))


## Skill slots at an expedition level (tuning skill_links.skill_slots_by_level: [[level, slots], ...]).
static func slot_count(tuning: RefCounted, level: int) -> int:
	var count := 1
	for step: Array in links(tuning).skill_slots_by_level:
		if level >= int(step[0]):
			count = int(step[1])
	return count


## Skills of a weapon style, in the order the data lists them.
static func style_skills(tuning: RefCounted, style: String) -> Array:
	var out: Array = []
	for s: Dictionary in tuning.data.skills:
		if s.style == style:
			out.append(s.id)
	return out


# --- Mastery ----------------------------------------------------------------------

static func mastery_need(level: int) -> int:
	return ceili(100.0 * pow(1.6, level - 1))


static func mastery_level(run: RefCounted, role: String, id: String) -> int:
	return int((run.learned.get(role, {}) as Dictionary).get(id, {}).get("level", 0))


static func power_ratio(tuning: RefCounted, mastery: int) -> float:
	return 1.0 + float(links(tuning).mastery_power_per_level) * maxi(0, mastery - 1)


static func cooldown_ratio(mastery: int) -> float:
	return maxf(0.75, 1.0 - 0.02 * maxi(0, mastery - 1))


## Adds the mastery EXP of one effective cast. Returns the new level when it rose, else 0.
static func add_mastery(tuning: RefCounted, run: RefCounted, role: String, id: String) -> int:
	var book: Dictionary = run.learned.get(role, {})
	if not book.has(id):
		return 0
	var entry: Dictionary = book[id]
	var def: Dictionary = tuning.skills[id]
	if int(entry.level) >= int(def.mastery_cap):
		return 0
	entry.exp = float(entry.exp) + float(def.mastery_exp_per_cast)
	var rose := 0
	while int(entry.level) < int(def.mastery_cap) and float(entry.exp) >= mastery_need(int(entry.level)):
		entry.exp = float(entry.exp) - mastery_need(int(entry.level))
		entry.level = int(entry.level) + 1
		rose = int(entry.level)
	return rose


# --- Learning ---------------------------------------------------------------------

## "" when the member can learn the skill now, else why not.
static func learn_block(tuning: RefCounted, run: RefCounted, role: String, id: String) -> String:
	var def: Dictionary = tuning.skills[id]
	if (run.learned.get(role, {}) as Dictionary).has(id):
		return "已經學會"
	if run.level < int(def.required_level):
		return "需要 Lv.%d" % int(def.required_level)
	var prev: Variant = def.get("previous_skill")
	if prev != null and mastery_level(run, role, String(prev)) < int(def.previous_mastery_required):
		return "需要%s熟練 %d" % [skill_name(tuning, String(prev)), int(def.previous_mastery_required)]
	return ""


static func learn(tuning: RefCounted, run: RefCounted, role: String, id: String) -> String:
	var block := learn_block(tuning, run, role, id)
	if block != "":
		return block
	if not run.learned.has(role):
		run.learned[role] = {}
	run.learned[role][id] = {"level": 1, "exp": 0.0}
	var slots: Array = run.slots.get(role, [])
	if slots.size() < slot_count(tuning, run.level) and not id in slots:
		slots.append(id)
		run.slots[role] = slots
	return ""


# --- Slots ------------------------------------------------------------------------

## Puts a learned skill into slot `index` (0-based). The first slot holds the chain head: it cannot change while the
## chain has links.
static func equip_block(tuning: RefCounted, run: RefCounted, role: String, id: String, index: int) -> String:
	if not (run.learned.get(role, {}) as Dictionary).has(id):
		return "還沒學會"
	if index < 0 or index >= slot_count(tuning, run.level):
		return "技能格不足（Lv.10 開第 2 格）"
	var chain: Array = run.chains.get(role, [])
	if index == 0 and chain.size() > 1:
		return "第 1 格是連招起手，先解除連招"
	if id in chain.slice(1):
		return "已在連招中，不必另佔格子"
	return ""


static func equip(tuning: RefCounted, run: RefCounted, role: String, id: String, index: int) -> String:
	var block := equip_block(tuning, run, role, id, index)
	if block != "":
		return block
	var slots: Array = run.slots.get(role, []).duplicate()
	slots.erase(id)
	while slots.size() <= index:
		slots.append("")
	slots[index] = id
	while not slots.is_empty() and slots[-1] == "":
		slots.pop_back()
	run.slots[role] = slots
	run.chains[role] = [slots[0]] if not slots.is_empty() and slots[0] != "" else []
	return ""


# --- Chains -----------------------------------------------------------------------

## The member's chain: the first slot's skill plus its links.
static func chain(run: RefCounted, role: String) -> Array:
	var c: Array = run.chains.get(role, [])
	var slots: Array = run.slots.get(role, [])
	if c.is_empty() and not slots.is_empty() and slots[0] != "":
		return [slots[0]]
	return c


## "" when `id` may be linked after the current chain end, else why not.
static func link_block(tuning: RefCounted, run: RefCounted, role: String, id: String) -> String:
	var cfg := links(tuning)
	var c := chain(run, role)
	if c.is_empty():
		return "第 1 格沒有技能"
	if not (run.learned.get(role, {}) as Dictionary).has(id):
		return "還沒學會"
	if id in c:
		return "已在連招中"
	if c.size() >= int(cfg.max_chain_length):
		return "連招最多 %d 招" % int(cfg.max_chain_length)
	if int(run.seals) < int(cfg.seal_cost_per_link):
		return "沒有連攜印（擊敗守層者、完成主線或收集委託取得）"
	var last: String = c[-1]
	var needs: Variant = tuning.skills[id].get("needs")
	var leaves: Variant = tuning.skills[last].get("leaves")
	if needs == null:
		return "%s是起手招，不能接在後面" % skill_name(tuning, id)
	if needs != leaves:
		return "%s需要「%s」，%s留下的是「%s」" % [skill_name(tuning, id), tag_name(tuning, needs),
			skill_name(tuning, last), tag_name(tuning, leaves)]
	var min_m := int(cfg.min_mastery_to_link)
	for sid: String in [last, id]:
		if mastery_level(run, role, sid) < min_m:
			return "%s熟練度要 %d 以上" % [skill_name(tuning, sid), min_m]
	return ""


static func link(tuning: RefCounted, run: RefCounted, role: String, id: String) -> String:
	var block := link_block(tuning, run, role, id)
	if block != "":
		return block
	var c := chain(run, role).duplicate()
	c.append(id)
	run.chains[role] = c
	run.seals = int(run.seals) - int(links(tuning).seal_cost_per_link)
	var slots: Array = run.slots.get(role, [])
	if id in slots:  # a linked skill no longer needs a slot of its own
		slots.erase(id)
		run.slots[role] = slots
	return ""


## Removes the last link. The seal it cost is gone (skill_links.unlink_refunds_seal).
static func unlink_last(tuning: RefCounted, run: RefCounted, role: String) -> String:
	var c := chain(run, role).duplicate()
	if c.size() <= 1:
		return "沒有可以解除的連結"
	c.pop_back()
	run.chains[role] = c
	if bool(links(tuning).unlink_refunds_seal):
		run.seals = int(run.seals) + int(links(tuning).seal_cost_per_link)
	return ""
