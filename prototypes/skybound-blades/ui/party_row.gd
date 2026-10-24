extends PanelContainer
## One party member in the HUD's party list (ui/party_row.tscn).

@onready var _name: Label = %MemberName
@onready var _bar: ProgressBar = %MemberBar
@onready var _hp: Label = %MemberHp
@onready var _state: Label = %MemberState


## member = {name, hp, max, alive, hot} or {} to hide.
func show_member(member: Dictionary) -> void:
	visible = not member.is_empty()
	if member.is_empty():
		return
	_name.text = member.name
	_bar.max_value = member.max
	_bar.value = member.hp
	_hp.text = "%d / %d" % [ceili(member.hp), int(member.max)]
	_state.text = "倒下" if not member.alive else ("回復中" if member.hot else "")
	modulate = Color(1, 1, 1, 0.55) if not member.alive else Color.WHITE
