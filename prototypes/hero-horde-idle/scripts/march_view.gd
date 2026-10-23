extends "res://addons/proto_kit/march_strip.gd"
## The 營地's 行軍 view (scenes/march_view.tscn) on godot-kit march_strip: the 行軍小隊 walks right through the region,
## meets a monster, fights it on its own and walks on (+金幣). It only shows the march: the march's rewards come by
## the hour (progression.gd claim_march), and a kill's gold is that hour's gold shared out over the kills an hour
## holds. Damage grows with the squad's strength. This adds the squad's sprites (portraits.gd atlas cells and rarity
## looks), the damage size and the texts.

const Portraits = preload("res://scripts/portraits.gd")
const CELL := 48
const RUN := [0, 1, 2, 3]
const ATTACK := [4, 5, 6]
## A kill every so many seconds on average (walk + fight): the hour's gold over this many kills.
const SECONDS_PER_KILL := 6.0

var _heroes: Array = []
var _power: float = 1.0
var _gold_per_kill: int = 1

@onready var _region: Label = %RegionLabel
@onready var _kills: Label = %KillLabel


## heroes: [{cls, rarity, tint}] of the march squad in slot order; region: its name and the monsters' tint; power:
## the squad's strength (damage numbers); gold_per_hour: what an hour of march brings.
func setup(heroes: Array, region_name: String, monster_tint: Color, power: float, gold_per_hour: int) -> void:
	_heroes = heroes
	_power = power
	_gold_per_kill = maxi(1, roundi(gold_per_hour * SECONDS_PER_KILL / 3600.0))
	_region.text = "行軍中‧%s" % region_name
	_enemy.self_modulate = monster_tint
	for k: int in _hero_nodes.get_child_count():
		var node: TextureRect = _hero_nodes.get_child(k)
		node.visible = k < heroes.size()
		if k < heroes.size():
			node.texture = (node.texture as AtlasTexture).duplicate() if node.texture is AtlasTexture else AtlasTexture.new()
			(node.texture as AtlasTexture).atlas = load(Portraits.HEROES)
			node.self_modulate = heroes[k].tint
			node.material = Portraits.material(heroes[k].rarity)
	_show_frames()


func _damage_base() -> float:
	return 100.0 * _power


func fell() -> void:
	_kills.text = "擊倒 %d" % kills
	popup("+%d 金幣" % _gold_per_kill, Color("e9cf8f"), _enemy.position + Vector2(_enemy.size.x * 0.3, -30.0))


## Run frames while walking, attack frames while fighting; each hero a little out of step.
func _show_frames() -> void:
	for k: int in mini(_heroes.size(), _hero_nodes.get_child_count()):
		var cells: Array = RUN if walking else ATTACK
		var fps: float = 9.0 if walking else 6.0
		var frame: int = cells[int(_t * fps + k * 1.7) % cells.size()]
		var atlas := (_hero_nodes.get_child(k) as TextureRect).texture as AtlasTexture
		atlas.region = Rect2(frame * CELL, _heroes[k].cls * CELL, CELL, CELL)
