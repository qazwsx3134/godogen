extends Control
## The hero page of the 養成 screen (scenes/hero_page.tscn, an instance in growth.tscn over the roster): name, rarity
## and class, level / cap with EXP, ascension, 設為隊長; the 招牌技 (SSR) or the next rarity step (N / R); the class bonus; the
## shard cost with 突破 and 派去行軍. growth.gd owns the progress and fills this with show_hero().

const PushSim = preload("res://domain/push_sim.gd")
const Progression = preload("res://domain/progression.gd")
const Items = preload("res://domain/items.gd")
const Portraits = preload("res://scripts/portraits.gd")
const SHORT := Color("d9735a")

signal back_pressed
signal ascend_pressed
signal send_pressed
signal captain_pressed

@onready var _gold: Label = %Gold
@onready var _shards: Label = %Shards
@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %HeroName
@onready var _rarity: Label = %Rarity
@onready var _class_name: Label = %ClassName
@onready var _level: Label = %Level
@onready var _cap: Label = %Cap
@onready var _exp: ProgressBar = %Exp
@onready var _ascend_line: Label = %AscendLine
@onready var _power: Label = %PowerLine
@onready var _sig: Control = %SigSection
@onready var _sig_icon: TextureRect = %SigIcon
@onready var _sig_name: Label = %SigName
@onready var _sig_desc: Label = %SigDesc
@onready var _sig_bonus: Label = %SigBonus
@onready var _promote: Control = %PromoteSection
@onready var _promote_name: Label = %PromoteName
@onready var _promote_desc: Label = %PromoteDesc
@onready var _rarity_now: Label = %RarityNow
@onready var _class_icon: TextureRect = %ClassIcon
@onready var _class_level: Label = %ClassLevel
@onready var _class_mult: Label = %ClassMult
@onready var _cost: Label = %CostLine
@onready var _ascend: Button = %Ascend
@onready var _send: Button = %SendMarch
@onready var _captain: Button = %CaptainToggle


func _ready() -> void:
	%Back.pressed.connect(back_pressed.emit)
	_ascend.pressed.connect(ascend_pressed.emit)
	_send.pressed.connect(send_pressed.emit)
	_captain.pressed.connect(captain_pressed.emit)


## p: domain/progression.gd; sig: the hero's PushSim.Sig (-1 = none); slot: the march slot 派去行軍 fills.
func show_hero(p: RefCounted, i: int, hero_name: String, sig: int, slot: int) -> void:
	var cls: int = Progression.base_class(i)
	var r: int = p.rarity(i)
	_gold.text = "%d" % p.gold
	_shards.text = "%d" % p.shards
	_portrait.texture = Portraits.full(cls)
	_name.text = hero_name
	_rarity.text = PushSim.RARITY_NAMES[r]
	_rarity.add_theme_color_override(&"font_color", Portraits.RARITY_COLORS[r])
	_class_name.text = Portraits.TITLES[cls]
	_level.text = "%d" % p.hero_level[i]
	_cap.text = "／%d" % p.hero_cap(i)
	_exp.max_value = Progression.EXP_PER_LEVEL * p.hero_level[i]
	_exp.value = p.hero_exp[i] if p.hero_level[i] < p.hero_cap(i) else _exp.max_value
	_ascend_line.text = "突破 ★%d／%d" % [p.ascension[i], Progression.MAX_ASCEND]
	_power.text = "強度 ×%.2f　%s" % [p.power(i) / Progression.START_POWER,
		"飾品 %s" % Items.CHARMS[p.charm[i]].name if p.charm[i] >= 0 else "沒有飾品"]

	_sig.visible = sig >= 0
	if sig >= 0:
		_sig_icon.texture = Portraits.sig_icon(sig, cls)
		_sig_name.text = PushSim.SIG_NAMES[sig]
		_sig_desc.text = "%s。\n開戰 %d 秒起，每 %d 秒施放一次。" % [PushSim.SIG_DESC[sig], roundi(PushSim.SIG_FIRST), roundi(PushSim.SIG_CD)]
		_sig_bonus.text = "+%d%%" % roundi(PushSim.SIG_PER_LEVEL * 100.0 * p.ascension[i])
	var base: int = Progression.base_rarity(i)
	_promote.visible = base < PushSim.SR
	if base < PushSim.SR:
		_rarity_now.text = PushSim.RARITY_NAMES[r]
		_rarity_now.add_theme_color_override(&"font_color", Portraits.RARITY_COLORS[r])
		if r >= PushSim.SR:
			_promote_name.text = "已晉升到 SR"
		else:
			var left: int = Progression.ASCEND_PER_PROMOTE - p.ascension[i] % Progression.ASCEND_PER_PROMOTE
			_promote_name.text = "再突破 %d 次 → %s" % [left, PushSim.RARITY_NAMES[r + 1]]
		_promote_desc.text = "每突破 %d 次升一階稀有度，最高 SR。" % Progression.ASCEND_PER_PROMOTE

	_class_icon.texture = Portraits.class_icon(cls)
	_class_level.text = "%d" % p.class_level[cls]
	_class_mult.text = "×%.2f" % pow(Progression.CLASS_STEP, p.class_level[cls] - 1)

	var cost: int = p.ascend_cost(i)
	if cost < 0:
		_cost.text = "突破已達上限"
		_ascend.text = "突破已滿"
	else:
		_cost.text = "突破素材 %d／持有 %d" % [cost, p.shards]
		_ascend.text = "突破（%d 素材）" % cost
	_cost.add_theme_color_override(&"font_color", SHORT if cost > p.shards else Color("b3ac9d"))
	_ascend.disabled = cost < 0 or p.shards < cost
	var marching: bool = p.in_march(i)
	_send.text = "行軍中" if marching else "派去行軍（第 %d 格）" % (slot + 1)
	_send.disabled = marching
	var captain: bool = p.is_captain(i)
	var full: bool = p.captains.size() >= Progression.MAX_CAPTAINS
	var buff: String = "%s +%d%%" % [PushSim.SQUAD_NAMES[PushSim.CLASS_SQUAD[cls]], roundi(Progression.CAPTAIN_BUFF[r] * 100)]
	_captain.text = "取消隊長（%s）" % buff if captain else ("隊長已滿 %d 名" % Progression.MAX_CAPTAINS if full \
		else "設為隊長（%s）" % buff)
	_captain.disabled = full and not captain
