class_name StreetItemDefinition
extends Resource
## One level-up card: a weapon, a passive, an evolved weapon or a filler reward.
## Weapon stats at level L are base + per_level × (L - 1); passives add per_level per level to `stat`.
@export var id: StringName
@export var title: String
@export_multiline var description: String
## Card text for levels 2..max_level, in order.
@export var level_notes: PackedStringArray = []
@export_enum("weapon", "passive", "evolution", "fusion", "filler") var slot: String = "weapon"
@export var accent: Color = Color("72e0c0")
@export_range(1, 8, 1) var max_level: int = 5
## Achievement id that must be unlocked in the meta save; empty means always available.
@export var unlock: StringName

@export_group("Weapon")
@export var kind: StringName
## Behaviour tweak: homing, rocket, permanent, rapid…; empty for the plain form.
@export var variant: StringName
@export var projectile: PackedScene
@export var damage: float = 10.0
@export var damage_per_level: float = 0.0
@export var cooldown: float = 1.0
## Fraction of the cooldown removed per level after the first.
@export var cooldown_per_level: float = 0.0
@export var amount: int = 1
## Levels at which amount grows by one.
@export var amount_levels: PackedInt32Array = []
@export var area: float = 1.0
@export var area_per_level: float = 0.0
@export var speed: float = 300.0
@export var duration: float = 1.0
@export var pierce: int = -1
@export var knockback: float = 1.0
## Level from which the weapon's special effect (heavy punch, etc.) is active; 0 = never.
@export var special_level: int = 0
## Fraction of speed removed from enemies standing in the projectile (zones).
@export var slow: float = 0.0
## Pixels per second that enemies inside the projectile are dragged toward its centre.
@export var pull: float = 0.0
## Explode when the projectile expires instead of on first contact.
@export var blast_on_end: bool = false

@export_group("Evolution")
## On a weapon: the passive that, owned at any level with this weapon maxed, offers `evolve_into`.
@export var evolve_passive: StringName
@export var evolve_into: StringName
## On an evolution: the base weapon it replaces in its slot.
@export var replaces: StringName

@export_group("Fusion")
## Hidden recipe: owning both weapons at `fuse_level` or higher offers this card; both are replaced by it.
@export var fuse_a: StringName
@export var fuse_b: StringName
@export_range(1, 8, 1) var fuse_level: int = 4

@export_group("Passive")
@export var stat: StringName
@export var per_level: float = 0.0
