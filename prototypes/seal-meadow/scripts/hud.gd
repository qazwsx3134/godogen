extends CanvasLayer
## Status frame (name, level, HP, XP), the locked target's frame, and the message log.

@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_text: Label = %HpText
@onready var xp_bar: ProgressBar = %XpBar
@onready var xp_text: Label = %XpText
@onready var target_panel: Control = %TargetPanel
@onready var target_name: Label = %TargetName
@onready var target_hp_bar: ProgressBar = %TargetHpBar
@onready var log_box: RichTextLabel = %Log

var player: Node3D


func bind(p: Node3D) -> void:
	player = p
	player.stats_changed.connect(refresh)
	player.message.connect(log_line)
	name_label.text = player.player_name
	refresh()
	log_line("歡迎來到蓬蓬草原！點地面移動，點怪物攻擊。", Color("ffd75e"))


func refresh() -> void:
	level_label.text = "Lv %d" % player.level
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_text.text = "%d / %d" % [ceili(player.hp), player.max_hp]
	xp_bar.max_value = player.xp_to_next()
	xp_bar.value = player.xp
	xp_text.text = "EXP %.1f%%" % (100.0 * player.xp / player.xp_to_next())


func log_line(text: String, color: Color = Color.WHITE) -> void:
	log_box.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])


func _process(_delta: float) -> void:
	if player == null:
		return
	var t: Node3D = player.target
	target_panel.visible = t != null and is_instance_valid(t) and t.is_alive()
	if target_panel.visible:
		target_name.text = t.actor.display_name
		target_hp_bar.max_value = t.max_hp
		target_hp_bar.value = t.hp
