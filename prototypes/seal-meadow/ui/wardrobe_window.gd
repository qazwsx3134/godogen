extends Control
## The world character is the live preview; only Apply changes the saved appearance.

const Cosmetics = preload("res://scripts/cosmetics.gd")

@onready var close_button: Button = %WardrobeClose
@onready var outfit_default: Button = %OutfitDefault
@onready var outfit_meadow: Button = %OutfitMeadow
@onready var aura_none: Button = %AuraNone
@onready var aura_meadow: Button = %AuraMeadow
@onready var apply_button: Button = %WardrobeApply
@onready var status: Label = %WardrobeStatus

var player: Node3D
var main: Node
var _outfit: String = ""
var _aura: String = ""


func _ready() -> void:
	close_button.pressed.connect(dismiss)
	outfit_default.pressed.connect(func() -> void: _select("", _aura))
	outfit_meadow.pressed.connect(func() -> void: _select("meadow_tunic", _aura))
	aura_none.pressed.connect(func() -> void: _select(_outfit, ""))
	aura_meadow.pressed.connect(func() -> void: _select(_outfit, "meadow_ring"))
	apply_button.pressed.connect(_apply)


func bind(p: Node3D, m: Node) -> void:
	player = p
	main = m


func show_wardrobe() -> void:
	player.cancel_appearance_preview()
	_outfit = player.appearance.outfit
	_aura = player.appearance.aura
	visible = true
	_refresh()


func dismiss() -> void:
	if is_instance_valid(player):
		player.cancel_appearance_preview()
	visible = false


func _select(outfit: String, aura_id: String) -> void:
	if player.preview_appearance(outfit, aura_id):
		_outfit = outfit
		_aura = aura_id
		_refresh()


func _refresh() -> void:
	outfit_default.set_pressed_no_signal(_outfit == "")
	outfit_meadow.set_pressed_no_signal(_outfit == "meadow_tunic")
	aura_none.set_pressed_no_signal(_aura == "")
	aura_meadow.set_pressed_no_signal(_aura == "meadow_ring")
	var outfit_unlocked: bool = Cosmetics.allowed("meadow_tunic", "", player.collection.claimed)
	var aura_unlocked: bool = Cosmetics.allowed("", "meadow_ring", player.collection.claimed)
	outfit_meadow.text = "草原布衣" if outfit_unlocked else "草原布衣（未解鎖）"
	aura_meadow.text = "草原光環" if aura_unlocked else "草原光環（未解鎖）"
	var hints: PackedStringArray = []
	if _outfit == "meadow_tunic" and not outfit_unlocked:
		hints.append("領取「村子的幫手」解鎖布衣")
	if _aura == "meadow_ring" and not aura_unlocked:
		hints.append("領取「果凍初遇」解鎖光環")
	status.text = "預覽：%s、%s\n%s" % [Cosmetics.OUTFITS[_outfit].name, Cosmetics.AURAS[_aura].name,
		"、".join(hints) if not hints.is_empty() else "關閉可取消。"]
	apply_button.disabled = not Cosmetics.allowed(_outfit, _aura, player.collection.claimed)


func _apply() -> void:
	var result: String = player.apply_appearance(_outfit, _aura)
	if not result.is_empty():
		status.text = "尚未解鎖，無法套用。"
		_refresh()
		return
	main.town_action("")
	visible = false
