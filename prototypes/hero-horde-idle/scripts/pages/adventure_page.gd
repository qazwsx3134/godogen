extends Control
## 冒險 (scenes/pages/adventure.tscn, Taskbar Hero's adventure.png page): the region picked with the chapter button,
## its stages as stage cards (cleared / the boss to beat / locked; the one the squad marches at is marked). A card
## picks a stage: 在此行軍 sends the march there, 挑戰樓層王 starts that stage's 推王 (push_requested).

signal changed
signal open_tab(tab: StringName)
signal message(text: String)
signal push_requested(stage: int)

const Stages = preload("res://domain/stages.gd")
const UiArt = preload("res://scripts/ui_art.gd")

var progress: RefCounted = null
var region: int = -1
var selected: int = -1


func _ready() -> void:
	%ChapterButton.pressed.connect(func() -> void:
		region = (region + 1) % Stages.REGIONS.size()
		selected = -1
		refresh())
	for k: int in %StageGrid.get_child_count():
		var card: Control = %StageGrid.get_child(k)
		(card.get_node("SelectButton") as Button).pressed.connect(func() -> void:
			var n: int = Stages.REGIONS[region].first + k
			if progress.unlocked(n):
				selected = n
				refresh()
			else:
				message.emit("先打倒上一層的樓層王"))
	%MarchHereButton.pressed.connect(func() -> void:
		if progress.set_march_stage(selected):
			message.emit("小隊前往 %s 行軍" % Stages.label(selected))
			changed.emit())
	%DepartButton.pressed.connect(func() -> void: push_requested.emit(selected))


func refresh() -> void:
	if progress == null:
		return
	if region < 0:
		region = Stages.region(progress.next_stage())
	if selected < 0 or Stages.region(selected) != region:
		selected = clampi(progress.next_stage(), Stages.REGIONS[region].first, _last(region))
		if not progress.unlocked(selected):
			selected = Stages.REGIONS[region].first
	var info: Dictionary = Stages.REGIONS[region]
	%ChapterButton.text = "%s　第%d～%d層　⌄" % [info.name, info.first, _last(region)]
	%ChapterTitle.text = "%s　第%d～%d層" % [info.name, info.first, _last(region)]
	%ChapterDescription.text = "樓層王：%s\n推薦戰力 %.2f　目前 %.2f" % [Stages.boss_name(selected), Stages.recommended(selected), progress.team_power()]
	for k: int in %StageGrid.get_child_count():
		var card: Control = %StageGrid.get_child(k)
		var n: int = info.first + k
		card.visible = n <= _last(region)
		if not card.visible:
			continue
		# Locked cards are greyed here; the button stays live (its disabled look covers the card) and says why.
		(card.get_node("SelectButton") as Button).disabled = false
		(card.get_node("Title") as Label).text = Stages.label(n)
		var status: String = "已通關" if n <= progress.cleared else ("樓層王" if progress.unlocked(n) else "未開放")
		if n == progress.march_stage:
			status += "・行軍中"
		(card.get_node("Status") as Label).text = status
		card.modulate = Color.WHITE if progress.unlocked(n) else Color(0.6, 0.6, 0.65)
		(card.get_node("Icon") as CanvasItem).modulate = Color.WHITE
		(card.get_node("Frame") as Control).self_modulate = Color("ffd76a") if n == selected else Color.WHITE
	var icons: Array = ["gold", "shards", "stones"]
	for k: int in 4:
		var icon: TextureRect = get_node("%%RewardIcon%d" % k)
		icon.texture = UiArt.material_icon(icons[k]) if k < 3 else UiArt.tex(UiArt.WEAPONS[1])
	var unlocked: bool = progress.unlocked(selected)
	%LaunchNote.text = "%s：行軍每次擊倒 %d 金幣；樓層王必掉突破素材與裝備" % [Stages.label(selected), progress.kill_gold(selected)]
	%MarchHereButton.disabled = not unlocked or progress.march_stage == selected
	%MarchHereButton.text = "行軍中" if progress.march_stage == selected else "在此行軍"
	%DepartButton.disabled = not unlocked
	%DepartButton.text = "挑戰樓層王" if selected > progress.cleared else "再戰樓層王"
	var ready: bool = progress.team_power() >= Stages.recommended(selected)
	%DepartHint.text = "戰力 %.2f／推薦 %.2f%s" % [progress.team_power(), Stages.recommended(selected),
		"" if ready else "（偏弱，操作好也能贏）"]


func _last(r: int) -> int:
	return Stages.REGIONS[r + 1].first - 1 if r + 1 < Stages.REGIONS.size() else Stages.COUNT
