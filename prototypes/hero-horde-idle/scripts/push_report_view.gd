extends VBoxContainer
## The 推王戰報 on the result panel (hud.tscn > Result): the MVP with their field sprite, the top 3 of 輸出 / 承傷 /
## 治療, and on a loss the diagnosis. Fills itself from push_report.gd's dictionary; the layout and the preview text
## live in push_report.tscn.

const HEROES_ATLAS := "res://assets/heroes/heroes.png"
const CELL := 48
## The ready stance's column in a class row of the hero atlas.
const READY_CELL := 4

@onready var _portrait: TextureRect = %Portrait
@onready var _mvp_name: Label = %MvpName
@onready var _mvp_line: Label = %MvpLine
@onready var _boards: Array[Node] = %Boards.get_children()
@onready var _diagnosis: Label = %Diagnosis


func show_report(report: Dictionary, hero_class: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(HEROES_ATLAS)
	atlas.region = Rect2(READY_CELL * CELL, hero_class * CELL, CELL, CELL)
	_portrait.texture = atlas
	_mvp_name.text = "MVP　%s" % report.mvp_name
	_mvp_line.text = report.mvp_line
	var boards: Array = report.boards
	for k: int in _boards.size():
		var column: Node = _boards[k]
		(column.get_node("Title") as Label).text = boards[k].title
		var rows: Array = boards[k].rows
		var row_nodes: Array[Node] = column.get_node("Rows").get_children()
		for r: int in row_nodes.size():
			if r < rows.size():
				row_nodes[r].show_row(r + 1, rows[r].name, rows[r].value)
			else:
				(row_nodes[r] as Control).visible = false
	var lines: Array = report.diagnosis
	_diagnosis.text = "\n".join(lines)
	_diagnosis.visible = not lines.is_empty()
