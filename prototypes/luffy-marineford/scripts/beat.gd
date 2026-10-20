@tool
class_name Beat
extends Node
## One story step under an ActTrigger, run in child order when the trigger fires. Only the fields of its kind matter:
##   SAY       blocking dialogue box line (speaker, text, portrait, color)
##   LINE      in-game subtitle, the game keeps running (speaker, text, seconds 0 = by length)
##   TOAST     Musou-style side notification (speaker, text, portrait, color)
##   BANNER    full-width banner (text = title, speaker = subtitle, portrait, color)
##   TITLE     act title card; blocks (text = title; the number comes from the act)
##   CUTSCENE  plays `cutscene`; blocks the game until it ends or is skipped
##   CALL      calls `method(arg)` on the host (main); with `wait`, waits for the Signal it returns
##   WAIT      waits `seconds` of game time
##   WIN       the act is cleared

enum Kind { SAY, LINE, TOAST, BANNER, TITLE, CUTSCENE, CALL, WAIT, WIN }

@export var kind: Kind = Kind.SAY:
	set(value):
		kind = value
		_rename()
@export var speaker: String = ""
## Portrait id: assets/portraits/<id>.png (initials when missing).
@export var portrait: String = ""
@export_multiline var text: String = "":
	set(value):
		text = value
		_rename()
@export var color: Color = Color("ffd16b")
@export var cutscene: PackedScene
@export var method: StringName = &""
@export var arg: String = ""
@export var seconds: float = 0.0
@export var wait: bool = true


## In the editor, names the node after what it does, so the trigger's child list reads like a script.
func _rename() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var label: String = Kind.keys()[kind]
	if not text.is_empty():
		label += " " + text.left(12).replace("\n", " ")
	elif kind == Kind.CALL:
		label += " " + String(method)
	name = label.validate_node_name()
