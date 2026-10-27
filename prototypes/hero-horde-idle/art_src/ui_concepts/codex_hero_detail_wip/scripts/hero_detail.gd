extends Control
## Presentation only. All progression mutations and saving belong to growth.gd.
signal back_requested
signal ascend_requested
signal march_requested

const Progression = preload("res://domain/progression.gd")
const PushSim = preload("res://domain/push_sim.gd")
const CLASSES := ["盾衛", "劍士", "槍兵", "弓手", "法師", "補師"]
const PORTRAITS := ["shield", "sword", "spear", "bow", "mage", "healer"]
var _probe := PushSim.new()

func _ready() -> void:
	%Back.pressed.connect(func() -> void: back_requested.emit())
	%Ascend.pressed.connect(func() -> void: ascend_requested.emit())
	%SendMarch.pressed.connect(func() -> void: march_requested.emit())
	%MarchTarget.item_selected.connect(func(slot: int) -> void: march_slot_selected.emit(slot))

signal march_slot_selected(slot: int)

func open() -> void:
	show()
	%Back.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()

func show_hero(p: RefCounted, i: int, hero_name: String, slot: int) -> void:
	var c: int = Progression.base_class(i)
	%DetailName.text = hero_name
	%Identity.text = "%s  │  %s" % [PushSim.RARITY_NAMES[p.rarity(i)], CLASSES[c]]
	%DetailLine.text = "Lv %d / %d" % [p.hero_level[i], p.hero_cap(i)]
	%Stars.text = "突破  ★ %d" % p.ascension[i]
	%Power.text = "英雄強度 ×%.2f" % (p.power(i) / Progression.START_POWER)
	%Exp.max_value = Progression.EXP_PER_LEVEL * p.hero_level[i]
	%Exp.value = p.hero_exp[i]
	%Exp.tooltip_text = "經驗 %d / %d" % [p.hero_exp[i], %Exp.max_value]
	%Portrait.texture = load("res://assets/ui/portraits/%s.png" % PORTRAITS[c])
	%Gold.text = "%s 金幣" % String.num_int64(p.gold).replace(",", "")
	%Shards.text = "%d 素材" % p.shards
	var signature: int = _probe.sig[i]
	var has_signature: bool = Progression.base_rarity(i) == PushSim.SSR
	%SkillName.text = PushSim.SIG_NAMES[signature] if has_signature else "無專屬招牌技"
	%SkillDesc.text = PushSim.SIG_DESC[signature] if has_signature else "依職業進行普攻與一般技能。"
	%SkillBonus.text = "+%d%%" % roundi(PushSim.SIG_PER_LEVEL * 100.0 * p.ascension[i]) if has_signature else "—"
	%SkillIcon.texture = load("res://assets/ui/detail/slash.png") if signature == PushSim.Sig.CLEAVE and has_signature else %Portrait.texture
	%ClassLevel.text = "職業等級 %d" % p.class_level[c]
	%ClassDesc.text = "提升同職業英雄的能力。"
	%ClassMultiplier.text = "×%.2f" % pow(Progression.CLASS_STEP, p.class_level[c] - 1)
	%ClassCaption.text = "全%s英雄" % CLASSES[c]
	%ClassIcon.texture = load("res://assets/ui/detail/class_sword.png") if c == 1 else load("res://assets/flags/%s.png" % ["melee", "melee", "melee", "ranged", "ranged", "support"][c])
	var cost: int = p.ascend_cost(i)
	%Cost.text = "突破素材 %d ／ 持有 %d" % [cost, p.shards] if cost > 0 else "突破已達上限 ★%d" % Progression.MAX_ASCEND
	%Ascend.text = "突破（%d 素材）" % cost if cost > 0 else "突破已滿"
	%Ascend.disabled = cost < 0 or p.shards < cost
	%Ascend.tooltip_text = "等級上限 +%d" % Progression.CAP_PER_ASCEND if cost > 0 else "已達最高突破"
	%SendMarch.text = "行軍中" if p.in_march(i) else "派去行軍"
	%SendMarch.disabled = p.in_march(i)
	%MarchTarget.select(slot)

func show_feedback(message: String) -> void:
	%Feedback.text = message
