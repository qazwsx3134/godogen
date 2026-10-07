class_name StreetAchievement
extends Resource
## Unlocks content when a recorded stat reaches `threshold`.
@export var id: StringName
@export var title: String
@export_multiline var description: String
@export_enum("best_time", "best_kills", "total_kills", "best_level", "wins") var stat: String = "best_time"
@export var threshold: float = 300.0
@export var reward: String = ""
