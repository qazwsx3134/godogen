class_name Inventory
extends PanelContainer
## 背包：GridContainer 裡預先放好的 ItemSlot（可在編輯器調欄數、格數）。
## 點一格選起、再點另一格放下：空格→移動，同物品→疊加，不同→交換；點同一格取消。

signal closed

const PICK := preload("res://assets/sfx/press.ogg")
const DROP := preload("res://assets/sfx/appear.ogg")

@export var start_items: Array[Texture2D] = []
@export var start_counts: Array[int] = []
@export var loot_pool: Array[Texture2D] = []

var _selected: ItemSlot


func _ready() -> void:
	var s := slots()
	for i in s.size():
		s[i].pressed.connect(_on_slot.bind(s[i]))
		if i < start_items.size():
			s[i].set_item(start_items[i], start_counts[i] if i < start_counts.size() else 1)
	%Loot.pressed.connect(func(): add_item(loot_pool.pick_random()))
	%Close.pressed.connect(func(): closed.emit())


func slots() -> Array[ItemSlot]:
	var out: Array[ItemSlot] = []
	out.assign(%Grid.get_children())
	return out


## 疊到同物品，否則放第一個空格；滿了回傳 null。
func add_item(tex: Texture2D, n := 1) -> ItemSlot:
	var target: ItemSlot = null
	for s in slots():
		if s.item == tex:
			target = s
			break
		if target == null and s.is_empty():
			target = s
	if target:
		target.set_item(tex, target.count + n)
		UiAnim.play_sfx(self, DROP)
	return target


func _on_slot(s: ItemSlot) -> void:
	if _selected == null:
		if not s.is_empty():
			_selected = s
			s.set_selected(true)
			UiAnim.play_sfx(self, PICK)
		return
	var from := _selected
	_selected = null
	from.set_selected(false)
	if s == from:
		return
	if s.item == from.item:
		s.set_item(s.item, s.count + from.count)
		from.set_item(null, 0)
	else:
		var t := s.item
		var c := s.count
		s.set_item(from.item, from.count)
		from.set_item(t, c)
	UiAnim.play_sfx(self, DROP)
