extends PanelContainer
signal action_requested(action: String, uid: String)
var item_uid: String = ""


func _ready() -> void:
	%EquipItem.pressed.connect(func() -> void: action_requested.emit("equip", item_uid))
	%SellItem.pressed.connect(func() -> void: action_requested.emit("sell", item_uid))
	%LockItem.pressed.connect(func() -> void: action_requested.emit("lock", item_uid))


func refresh(entry: Dictionary, game: RefCounted, selected: String) -> void:
	item_uid = entry.uid
	%ItemName.text = entry.name
	%ItemKind.text = "武器" if entry.slot == "weapon" else "護具"
	%ItemIcon.text = "刃" if entry.slot == "weapon" else "甲"
	var old: Dictionary = game.item(str(game.state.equipped[selected].get(entry.slot, "")))
	var attack_delta: int = int(entry.attack) - int(old.get("attack", 0))
	var hp_delta: int = int(entry.hp) - int(old.get("hp", 0))
	%ItemStats.text = "攻擊 %d（%+d）\n生命 %d（%+d）· 甲 %d" % [entry.attack, attack_delta, entry.hp, hp_delta, entry.defense]
	var held: String = game.holder(item_uid)
	%ItemOwner.text = "由 %s 穿戴" % game.catalog.units[held].name if not held.is_empty() else "背包中 · 售價 %d" % int(entry.price)
	%EquipItem.text = "穿戴中" if held == selected else "穿戴"
	%EquipItem.disabled = held == selected
	%SellItem.disabled = not held.is_empty() or bool(entry.locked)
	%LockItem.text = "解鎖" if entry.locked else "鎖定"
	theme_type_variation = &"SelectedCard" if not held.is_empty() else &"Card"
