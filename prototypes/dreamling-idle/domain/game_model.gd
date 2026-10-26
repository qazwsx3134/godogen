extends RefCounted
## One fixed-step simulation; views never resolve damage or rewards.
## AutoCaster and UpgradeTree are unmodified godot-kit modules.

const Catalog = preload("res://domain/catalog.gd")
const AutoCaster = preload("res://addons/proto_kit/auto_caster.gd")
const UpgradeTree = preload("res://addons/proto_kit/upgrade_tree.gd")
const STEP: float = 0.05
const STARTERS: Array[String] = ["moss", "ember", "dew"]

var catalog: RefCounted
var state: Dictionary = {}
var actors: Array[Dictionary] = []
var events: Array[Dictionary] = []
var tick_number: int = 0
var elapsed: float = 0.0
var phase: String = "combat"
var phase_left: float = 0.0
var wave: int = 0
var paused: bool = false
var dirty: bool = false
var build_pending: bool = false
var revision: int = 0
var session_damage: Dictionary = {}
var session_heal: Dictionary = {}
var _books: Dictionary = {}
var _combat_rng := RandomNumberGenerator.new()
var _loot_rng := RandomNumberGenerator.new()
var _tree: RefCounted
var _spawn_serial: int = 0


func _init(seed_value: int = 2026, saved: Dictionary = {}, definitions: RefCounted = null) -> void:
	catalog = definitions if definitions != null else Catalog.new()
	_combat_rng.seed = seed_value
	_loot_rng.seed = seed_value + 1009
	state = saved.duplicate(true) if not saved.is_empty() else _fresh_state()
	if state.has("combat_rng"):
		_combat_rng.state = int(state.combat_rng)
		_loot_rng.state = int(state.loot_rng)
	_tree = UpgradeTree.new(catalog.talents, {"root": "root"})
	_tree.from_dict(state.talents)
	if saved.is_empty():
		var blade: Dictionary = _make_item("blade", 1)
		var linen: Dictionary = _make_item("linen", 1)
		var branch: Dictionary = _make_item("branch", 1)
		state.items = [blade, linen, branch]
		state.equipped.ember.weapon = blade.uid
		state.equipped.moss.armor = linen.uid
		_log("旅程開始！先讓苔角守住前排，燼尾負責輸出。", "welcome")
	_start_encounter(false)


func _fresh_state() -> Dictionary:
	var roster: Dictionary = {}
	var equipment: Dictionary = {}
	for id: String in STARTERS:
		roster[id] = {"level": 1, "xp": 0}
		equipment[id] = {"weapon": "", "armor": ""}
	return {"gold": 100, "roster": roster, "deployed": ["moss", "ember"],
		"equipped": equipment, "items": [], "pending": [], "next_item": 1,
		"talents": {"levels": {}}, "stage": 0, "best_stage": -1,
		"cleared": [], "auto_advance": true, "kills": 0, "defeats": 0,
		"earned": 0, "played": 0.0, "journal": [], "encounter": 0,
		"muted": true, "tutorial_seen": false, "blocked_drops": 0}


func snapshot() -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	result.talents = _tree.to_dict()
	# JSON numbers cannot losslessly represent all 64-bit RNG states.
	result.combat_rng = str(_combat_rng.state)
	result.loot_rng = str(_loot_rng.state)
	return result


func totals() -> Dictionary:
	return _tree.totals()


func slots() -> int:
	return 2 + int(totals().get("slots", 0))


func talent_rank(id: String) -> int:
	return int(_tree.to_dict().get("levels", {}).get(id, 0))


func bonds() -> Dictionary:
	var races: Dictionary = {}
	var elements: Dictionary = {}
	for id: String in state.deployed:
		var definition: Dictionary = catalog.units[id]
		races[definition.race] = int(races.get(definition.race, 0)) + 1
		elements[definition.element] = int(elements.get(definition.element, 0)) + 1
	return {"grove": int(races.get("grove", 0)) >= 2,
		"beast": int(races.get("beast", 0)) >= 2,
		"light": int(elements.get("light", 0)) >= 2}


func bond_text() -> String:
	var active: Dictionary = bonds()
	var labels: Array[String] = []
	if active.grove: labels.append("森靈 2：生命 +15%")
	if active.beast: labels.append("獸靈 2：攻擊 +12%")
	if active.light: labels.append("星光 2：治療 +20%")
	return "  ·  ".join(labels) if not labels.is_empty() else "2名同族可啟動羈絆：森靈生命 +15%／獸靈攻擊 +12%"


func stats(id: String) -> Dictionary:
	var definition: Dictionary = catalog.units[id]
	var level: int = int(state.roster.get(id, {"level": 1}).level)
	var growth: float = 1.0 + 0.14 * (level - 1)
	var result: Dictionary = {"hp": float(definition.hp) * growth,
		"attack": float(definition.attack) * growth, "defense": float(definition.defense),
		"interval": float(definition.interval), "heal": float(definition.heal),
		"heal_cd": float(definition.heal_cd), "range": float(definition.range), "speed": float(definition.speed)}
	for item_id: String in state.equipped.get(id, {}).values():
		var gear: Dictionary = item(item_id)
		if not gear.is_empty():
			for key: String in ["attack", "hp", "defense"]:
				result[key] += float(gear.get(key, 0))
	var upgrades: Dictionary = totals()
	result.attack *= 1.0 + float(upgrades.get("attack", 0))
	result.hp *= 1.0 + float(upgrades.get("hp", 0))
	result.interval *= maxf(0.4, 1.0 - float(upgrades.get("cooldown", 0)))
	result.heal_cd *= maxf(0.4, 1.0 - float(upgrades.get("cooldown", 0)))
	if id in state.deployed:
		var active: Dictionary = bonds()
		if active.grove: result.hp *= 1.15
		if active.beast: result.attack *= 1.12
		if active.light: result.heal *= 1.2
	return result


func xp_needed(level: int) -> int:
	return 24 + 12 * level


func train_cost(id: String) -> int:
	return int(ceil(18.0 * pow(float(state.roster[id].level), 1.35)))


func train(id: String) -> Dictionary:
	if not state.roster.has(id): return _failure("尚未擁有這隻夢靈")
	var level: int = int(state.roster[id].level)
	if level >= catalog.level_cap: return _failure("已達本版等級上限")
	var cost: int = train_cost(id)
	if int(state.gold) < cost: return _failure("金幣不足，還差 %d" % (cost - int(state.gold)))
	state.gold -= cost
	_grant_xp(id, xp_needed(level) - int(state.roster[id].xp))
	build_pending = true
	return _success("%s 升至 Lv.%d，下波生效" % [catalog.units[id].name, state.roster[id].level])


func deploy(id: String) -> Dictionary:
	if not state.roster.has(id): return _failure("請先招募這隻夢靈")
	if id in state.deployed:
		if state.deployed.size() <= 1: return _failure("至少保留一名夢靈上陣")
		state.deployed.erase(id)
	else:
		if state.deployed.size() >= slots(): return _failure("上陣格已滿，先撤下一名；天賦「結伴」可增加一格")
		state.deployed.append(id)
	build_pending = true
	return _success("隊伍已更新，下波一起生效")


func recruit(id: String) -> Dictionary:
	if not catalog.units.has(id): return _failure("夢靈不存在")
	if state.roster.has(id): return _failure("已經是同行夥伴")
	var definition: Dictionary = catalog.units[id]
	if int(state.best_stage) + 1 < int(definition.unlock): return _failure("再向前探索幾個關卡，就能遇見牠")
	if int(state.gold) < int(definition.cost): return _failure("招募需要 %d 金幣" % int(definition.cost))
	state.gold -= int(definition.cost)
	state.roster[id] = {"level": 1, "xp": 0}
	state.equipped[id] = {"weapon": "", "armor": ""}
	return _success("%s 加入了旅程！" % definition.name)


func buy_talent(id: String) -> Dictionary:
	if id == "company" and talent_rank("might") < 1: return _failure("先購買「勇氣」1級")
	var result: Dictionary = _tree.buy(id, int(state.gold))
	if not result.ok:
		var reasons: Dictionary = {"maxed": "已達最高等級", "locked": "請先購買前置天賦", "short": "金幣不足"}
		return _failure(str(reasons.get(result.reason, "目前無法購買")))
	state.gold = result.remaining
	state.talents = _tree.to_dict()
	build_pending = true
	return _success("%s 已提升至 %d 級" % [catalog.talent(id).name, talent_rank(id)])


func talent_preview(id: String) -> Dictionary:
	var result: Dictionary = _tree.preview(id, int(state.gold))
	result["rank"] = talent_rank(id)
	result["cost"] = _tree.cost(id)
	result["available"] = _tree.is_available(id) and (id != "company" or talent_rank("might") >= 1)
	return result


func select_stage(index: int) -> Dictionary:
	if index < 0 or index >= catalog.stages.size(): return _failure("關卡不存在")
	if index > int(state.best_stage) + 1: return _failure("請先完成前一關")
	state.stage = index
	wave = 0
	_start_encounter(false)
	return _success("前往 %s" % catalog.stages[index].name)


func set_auto(value: bool) -> void:
	state.auto_advance = value
	_touch()


func item(uid: String) -> Dictionary:
	for entry: Dictionary in state.get("items", []):
		if entry.uid == uid: return entry
	return {}


func holder(uid: String) -> String:
	if uid.is_empty(): return ""
	for id: String in state.equipped:
		if uid in state.equipped[id].values(): return id
	return ""


func bag_count() -> int:
	var result: int = 0
	for entry: Dictionary in state.items:
		if holder(entry.uid).is_empty(): result += 1
	return result


func equip(unit_id: String, item_id: String) -> Dictionary:
	if not state.roster.has(unit_id): return _failure("尚未擁有這隻夢靈")
	var entry: Dictionary = item(item_id)
	if entry.is_empty(): return _failure("裝備不存在")
	var old_holder: String = holder(item_id)
	var old_item: String = str(state.equipped[unit_id].get(entry.slot, ""))
	if old_holder == unit_id: return _failure("已經穿戴這件裝備")
	if not old_holder.is_empty() and not old_item.is_empty() and bag_count() >= catalog.bag_capacity:
		return _failure("背包已滿，沒有空間放下換出的裝備")
	if not old_holder.is_empty(): state.equipped[old_holder][entry.slot] = ""
	state.equipped[unit_id][entry.slot] = item_id
	build_pending = true
	return _success("%s 穿戴了 %s，下波生效" % [catalog.units[unit_id].name, entry.name])


func unequip(unit_id: String, slot: String) -> Dictionary:
	if not state.roster.has(unit_id) or not state.equipped[unit_id].has(slot): return _failure("部位不存在")
	if str(state.equipped[unit_id][slot]).is_empty(): return _failure("這個部位沒有裝備")
	if bag_count() >= catalog.bag_capacity: return _failure("背包已滿，請先出售不用的裝備")
	state.equipped[unit_id][slot] = ""
	build_pending = true
	return _success("裝備已卸下，下波生效")


func sell(uid: String) -> Dictionary:
	var entry: Dictionary = item(uid)
	if entry.is_empty(): return _failure("裝備不存在")
	if not holder(uid).is_empty(): return _failure("穿戴中的裝備不能出售")
	if bool(entry.locked): return _failure("裝備已鎖定")
	var price: int = int(entry.price)
	state.items.erase(entry)
	state.gold += price
	return _success("出售裝備，獲得 %d 金幣" % price)


func lock_item(uid: String) -> Dictionary:
	var entry: Dictionary = item(uid)
	if entry.is_empty(): return _failure("裝備不存在")
	entry.locked = not bool(entry.locked)
	return _success("裝備已鎖定" if entry.locked else "裝備已解鎖")


func claim_pending() -> Dictionary:
	var count: int = 0
	while not state.pending.is_empty() and bag_count() < catalog.bag_capacity:
		state.items.append(state.pending.pop_front())
		count += 1
	if count == 0: return _failure("背包沒有空位，或沒有待領裝備")
	return _success("已領取 %d 件裝備" % count)


func step() -> void:
	if paused: return
	tick_number += 1
	elapsed += STEP
	state.played += STEP
	if phase != "combat":
		phase_left -= STEP
		if phase_left <= 0.0:
			if phase == "recover": wave = 0
			_start_encounter(wave > 0)
		return
	for actor: Dictionary in actors:
		if float(actor.hp) <= 0.0: continue
		var foes: Array = _living(not bool(actor.friendly))
		if foes.is_empty(): continue
		foes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var da: float = absf(float(a.x) - float(actor.x))
			var db: float = absf(float(b.x) - float(actor.x))
			return a.uid < b.uid if is_equal_approx(da, db) else da < db)
		var target: Dictionary = foes[0]
		var distance: float = absf(float(target.x) - float(actor.x))
		actor.moving = distance > float(actor.range)
		if actor.moving:
			var amount: float = minf(float(actor.speed) * STEP, distance - float(actor.range) + 0.1)
			var proposed: float = float(actor.x) + signf(float(target.x) - float(actor.x)) * amount
			# Frontline bodies reserve space; rear melee wait instead of stacking on one pixel.
			for ally: Dictionary in _living(bool(actor.friendly)):
				if ally.uid == actor.uid: continue
				if actor.friendly and float(ally.x) > float(actor.x):
					proposed = minf(proposed, float(ally.x) - 76.0)
				elif not actor.friendly and float(ally.x) < float(actor.x):
					proposed = maxf(proposed, float(ally.x) + 76.0)
			actor.x = proposed
		var candidates: Array = []
		for foe: Dictionary in foes:
			candidates.append({"id": foe.uid, "pos": Vector2(float(foe.x), 0), "hp": foe.hp, "max_hp": foe.max_hp, "tags": ["boss"] if foe.boss else []})
		for cast: Dictionary in _books[actor.uid].step(STEP, Vector2(float(actor.x), 0), candidates):
			actor.action_tick = tick_number
			actor.action = "attack"
			for hit: Dictionary in cast.hits:
				_damage(actor, _actor(str(hit.id)), float(hit.damage), "attack")
		if float(actor.heal) > 0.0:
			actor.heal_left = maxf(0.0, float(actor.heal_left) - STEP)
			if float(actor.heal_left) <= 0.0:
				var allies: Array = _living(bool(actor.friendly))
				allies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
					var ar: float = float(a.hp) / float(a.max_hp)
					var br: float = float(b.hp) / float(b.max_hp)
					return a.uid < b.uid if is_equal_approx(ar, br) else ar < br)
				if not allies.is_empty() and float(allies[0].hp) < float(allies[0].max_hp) * 0.9:
					_heal(actor, allies[0])
					actor.heal_left = actor.heal_cd
	if _living(false).is_empty():
		_wave_cleared()
	elif _living(true).is_empty():
		state.defeats += 1
		state.auto_advance = false
		state.stage = maxi(0, int(state.best_stage))
		phase = "recover"
		phase_left = 3.0
		_log("隊伍需要休息。3秒後回到已通關獵場；試試加入露露、訓練或換裝。", "defeat")
		_touch()


func drain_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = events
	events = []
	return result


func _start_encounter(preserve_health: bool) -> void:
	var old: Dictionary = {}
	if preserve_health:
		for actor: Dictionary in actors:
			if actor.friendly: old[actor.species] = clampf(float(actor.hp) / float(actor.max_hp), 0.0, 1.0)
	actors.clear()
	_books.clear()
	state.encounter += 1
	_spawn_serial += 1
	var order: Array = state.deployed.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return _rank(a) < _rank(b) if _rank(a) != _rank(b) else a < b)
	for i: int in order.size():
		var id: String = order[i]
		var values: Dictionary = stats(id)
		var actor: Dictionary = _new_actor(id, id, true, values, 360.0 - i * 115.0, false)
		# Dead members recover to half health between waves; living members keep their ratio.
		if old.has(id): actor.hp = values.hp * maxf(0.5 if float(old[id]) <= 0.0 else 0.0, float(old[id]))
		actors.append(actor)
	var stage: Dictionary = catalog.stages[int(state.stage)]
	var boss_wave: bool = bool(stage.boss) and wave == 2
	var count: int = 1 if boss_wave else 3
	var enemy_species: Array[String] = ["dew", "moss", "ember"]
	for i: int in count:
		var id: String = "moss" if boss_wave else enemy_species[(i + wave + int(state.stage)) % 3]
		var values: Dictionary = {"hp": float(stage.hp) * (4.1 if boss_wave else 1.0) * (1.0 + wave * 0.08),
			"attack": float(stage.attack) * (1.9 if boss_wave else 1.0), "defense": float(int(state.stage) * 4),
			"interval": 1.55 if boss_wave else 1.9 + i * 0.15, "speed": 62.0 + i * 8,
			"range": 105.0 if id != "dew" else 190.0, "heal": 0.0, "heal_cd": 0.0}
		actors.append(_new_actor("foe_%d_%d" % [_spawn_serial, i], id, false, values, 850.0 + i * 110.0, boss_wave))
	phase = "combat"
	phase_left = 0.0
	build_pending = false
	_emit({"kind": "encounter", "wave": wave, "boss": boss_wave})
	revision += 1


func _rank(id: String) -> int:
	var job: String = str(catalog.units[id].job)
	return 0 if job == "tank" else (1 if job == "striker" else 2)


func _new_actor(uid: String, species: String, friendly: bool, values: Dictionary, x: float, boss: bool) -> Dictionary:
	var actor: Dictionary = values.duplicate(true)
	actor.merge({"uid": uid, "species": species, "friendly": friendly, "x": x,
		"max_hp": float(values.hp), "hp": float(values.hp), "boss": boss,
		"heal_left": 1.5, "moving": false, "action_tick": -100, "action": "idle", "rewarded": false}, true)
	var book: RefCounted = AutoCaster.new(_combat_rng)
	book.learn({"id": "strike", "cooldown": values.interval, "range": values.range + 0.5,
		"damage": values.attack, "target": "nearest"})
	_books[uid] = book
	return actor


func _living(friendly: bool) -> Array:
	return actors.filter(func(actor: Dictionary) -> bool: return bool(actor.friendly) == friendly and float(actor.hp) > 0.0)


func _actor(uid: String) -> Dictionary:
	for actor: Dictionary in actors:
		if actor.uid == uid: return actor
	return {}


func _damage(source: Dictionary, target: Dictionary, raw: float, kind: String) -> void:
	if target.is_empty() or float(target.hp) <= 0.0: return
	var amount: int = maxi(1, roundi(raw * 100.0 / (100.0 + maxf(0.0, float(target.defense)))))
	var applied: int = mini(amount, int(ceil(float(target.hp))))
	target.hp = maxf(0.0, float(target.hp) - amount)
	if source.friendly:
		session_damage[source.species] = int(session_damage.get(source.species, 0)) + applied
	_emit({"kind": kind, "source": source.uid, "target": target.uid, "amount": applied, "friendly": source.friendly})
	if float(target.hp) <= 0.0 and not target.rewarded:
		target.rewarded = true
		_emit({"kind": "down", "target": target.uid})
		if not target.friendly: _reward_kill(target)


func _heal(source: Dictionary, target: Dictionary) -> void:
	var raw: float = float(source.attack) * float(source.heal)
	var applied: float = minf(raw, float(target.max_hp) - float(target.hp))
	if applied <= 0.0: return
	target.hp += applied
	source.action_tick = tick_number
	source.action = "skill"
	session_heal[source.species] = float(session_heal.get(source.species, 0.0)) + applied
	_emit({"kind": "heal", "source": source.uid, "target": target.uid, "amount": roundi(applied)})
	# One explicit reaction, using applied healing. Reaction damage cannot heal or retrigger itself.
	var foes: Array = _living(false)
	if not foes.is_empty():
		foes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a.x) - float(source.x)) < absf(float(b.x) - float(source.x)))
		_damage(source, foes[0], applied * 0.5 * (1.0 + float(totals().get("reaction", 0))), "reaction")


func _reward_kill(actor: Dictionary) -> void:
	var stage: Dictionary = catalog.stages[int(state.stage)]
	var gold: int = roundi(float(stage.gold) * (3.0 if actor.boss else 1.0) * (1.0 + float(totals().get("gold", 0))))
	state.gold += gold
	state.earned += gold
	state.kills += 1
	# Reward the active encounter's team, not a pending replacement.
	for member: Dictionary in actors:
		if member.friendly: _grant_xp(member.species, int(stage.xp))
	_emit({"kind": "gold", "amount": gold, "target": actor.uid})
	if _loot_rng.randf() < 0.19 or actor.boss:
		grant_loot()
	_touch()


func grant_loot() -> Dictionary:
	if bag_count() >= catalog.bag_capacity and state.pending.size() >= catalog.pending_capacity:
		state.blocked_drops += 1
		_log("背包與待領箱已滿，裝備產出暫停；金幣與經驗仍正常取得。", "capacity")
		return {}
	var keys: Array = catalog.gear.keys()
	var template: String = str(keys[_loot_rng.randi_range(0, keys.size() - 1)])
	var quality: int = 1 + int(state.stage) / 2
	if _loot_rng.randf() < 0.12: quality += 1
	var entry: Dictionary = _make_item(template, quality)
	if bag_count() < catalog.bag_capacity:
		state.items.append(entry)
	else:
		state.pending.append(entry)
	_log("發現 %s%s" % [entry.name, "（已放入待領箱）" if entry in state.pending else ""], "loot")
	_touch()
	return entry


func _make_item(template: String, quality: int) -> Dictionary:
	var entry: Dictionary = catalog.gear[template].duplicate(true)
	entry.uid = "gear_%06d" % int(state.next_item)
	state.next_item += 1
	entry.quality = quality
	entry.locked = false
	entry.price = 8 + quality * 7
	entry.name = ("精良·" if quality > 1 else "") + str(entry.name) + (" +%d" % (quality - 1) if quality > 1 else "")
	for key: String in ["attack", "hp", "defense"]:
		entry[key] = roundi(float(entry[key]) * (1.0 + 0.48 * (quality - 1)))
	return entry


func _grant_xp(id: String, amount: int) -> void:
	var progress: Dictionary = state.roster[id]
	if int(progress.level) >= catalog.level_cap: return
	progress.xp += maxi(0, amount)
	var before: int = int(progress.level)
	while int(progress.level) < catalog.level_cap and int(progress.xp) >= xp_needed(int(progress.level)):
		progress.xp -= xp_needed(int(progress.level))
		progress.level += 1
	if int(progress.level) >= catalog.level_cap: progress.xp = 0
	if int(progress.level) > before:
		build_pending = true
		_log("%s 成長至 Lv.%d，下波生效" % [catalog.units[id].name, int(progress.level)], "level")
	_touch()


func _wave_cleared() -> void:
	wave += 1
	if wave >= 3:
		var stage_index: int = int(state.stage)
		if stage_index not in state.cleared:
			state.cleared.append(stage_index)
			state.best_stage = maxi(int(state.best_stage), stage_index)
			var bonus: int = 40 + stage_index * 25
			state.gold += bonus
			state.earned += bonus
			grant_loot()
			_log("首次完成 %s！獲得 %d 金幣，新的獵場與夥伴已開放。" % [catalog.stages[stage_index].name, bonus], "clear")
		if state.auto_advance and int(state.stage) < catalog.stages.size() - 1:
			state.stage += 1
		wave = 0
	phase = "advance"
	phase_left = 1.35
	_emit({"kind": "advance"})
	_touch()


func _emit(event: Dictionary) -> void:
	event["tick"] = tick_number
	if events.size() >= 256: events.pop_front()
	events.append(event)


func _log(message: String, kind: String = "info") -> void:
	state.journal.append({"message": message, "kind": kind, "seconds": int(state.played)})
	if state.journal.size() > 80: state.journal.pop_front()
	_emit({"kind": "notice", "message": message, "category": kind})


func _touch() -> void:
	dirty = true
	revision += 1


func _success(message: String) -> Dictionary:
	_touch()
	_log(message, "upgrade")
	return {"ok": true, "message": message}


func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
