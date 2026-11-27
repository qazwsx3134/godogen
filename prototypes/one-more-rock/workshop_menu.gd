@tool
extends Control

signal close_requested
signal purchase_requested(id: StringName)
signal tool_requested(drill: bool)
signal automation_toggled(id: StringName)

const Catalog := preload("res://workshop_upgrades.gd")

@export var card_ready: StyleBoxTexture
@export var card_locked: StyleBoxTexture
@export var card_owned: StyleBoxTexture
@export var card_selected: StyleBoxTexture

@onready var route_buttons: VBoxContainer = %RouteButtons
@onready var route_pages: Control = %RoutePages
@onready var links: Control = %Links
@onready var route_title: Label = %RouteTitle
@onready var route_description: Label = %RouteDescription
@onready var route_count: Label = %RouteCount
@onready var wallet: Label = %Wallet
@onready var detail_title: Label = %DetailTitle
@onready var detail_text: Label = %DetailText
@onready var apply_button: Button = %Apply

var cards: Dictionary[StringName, PanelContainer] = {}
var routes: Dictionary[StringName, Control] = {}
var card_routes: Dictionary[StringName, StringName] = {}
var upgrades: Catalog
var coins := 0
var using_drill := false
var collector_enabled := false
var crusher_enabled := false
var selected: StringName = &"steel_hammer"
var route: StringName = &"Hammer"


func _ready() -> void:
	%Close.pressed.connect(func(): close_requested.emit())
	apply_button.pressed.connect(_apply_selection)
	links.draw.connect(_draw_links)
	for page: Control in route_pages.get_children():
		var id := page.name
		routes[id] = page
		var switch: Button = route_buttons.get_node(NodePath(id))
		switch.pressed.connect(_select_route.bind(id))
		for column: VBoxContainer in page.get_children():
			for card: PanelContainer in column.get_children():
				cards[card.name] = card
				card_routes[card.name] = id
				card.get_node("%Name").text = Catalog.ITEMS[card.name].name
				card.get_node("%Status").text = "%d 幣" % Catalog.ITEMS[card.name].cost
				card.get_node("%Select").pressed.connect(select_talent.bind(card.name))
				card.item_rect_changed.connect(links.queue_redraw)
	_update_view()


func present() -> void:
	show()
	(cards[selected].get_node("%Select") as Button).grab_focus()
	links.queue_redraw()


func refresh(state: Catalog, balance: int, drill_equipped: bool, collector_running: bool, crusher_running: bool) -> void:
	upgrades = state
	coins = balance
	using_drill = drill_equipped
	collector_enabled = collector_running
	crusher_enabled = crusher_running
	wallet.text = "%d 幣" % coins
	_update_view()


func _select_route(id: StringName) -> void:
	select_talent(Catalog.ROUTES[id].columns[0][0])


func select_talent(id: StringName) -> void:
	if not cards.has(id):
		return
	selected = id
	route = card_routes[id]
	_update_view()


func _update_view() -> void:
	for id in routes:
		routes[id].visible = id == route
		var button: Button = route_buttons.get_node(NodePath(id))
		button.set_pressed_no_signal(id == route)
	var route_info: Dictionary = Catalog.ROUTES[route]
	route_title.text = route_info.name
	route_description.text = route_info.description
	var unlocked := 0
	var total := 0
	for column: Array in route_info.columns:
		for id: StringName in column:
			var owned := upgrades != null and upgrades.owned.has(id)
			var item: Dictionary = Catalog.ITEMS[id]
			var available := upgrades == null or upgrades.can_purchase(id, coins)
			if owned:
				unlocked += 1
			total += 1
			var card := cards[id]
			var style := card_ready if available else card_locked
			if owned:
				style = card_owned
			if id == selected:
				style = card_selected
			card.add_theme_stylebox_override("panel", style)
			var pale := not (available or id == selected) or (owned and id != selected)
			card.get_node("%Name").add_theme_color_override("font_color", Color("fff5de") if pale else Color("3d291a"))
			var badge: Label = card.get_node("%Status")
			badge.text = _status_text(id, item)
			badge.add_theme_color_override("font_color", Color("f9e4b4") if pale else Color("754522"))
	route_count.text = "已解鎖 %d／%d" % [unlocked, total]
	links.queue_redraw()

	var chosen: Dictionary = Catalog.ITEMS[selected]
	detail_title.text = chosen.name
	detail_text.text = chosen.detail
	apply_button.text = "解鎖　%d 幣" % chosen.cost
	apply_button.disabled = upgrades == null or not upgrades.can_purchase(selected, coins)
	if upgrades == null:
		return
	if upgrades.owned.has(selected):
		apply_button.text = "已解鎖"
		if selected == &"steel_pick" or selected == &"drill":
			var equipped := using_drill == (selected == &"drill")
			apply_button.text = "使用中" if equipped else "換裝"
			apply_button.disabled = equipped
		elif _toggleable(selected):
			apply_button.text = "暫停接單" if _automation_enabled(selected) else "啟動"
			apply_button.disabled = false
	elif apply_button.disabled:
		apply_button.text = _status_text(selected, chosen)


func _status_text(id: StringName, item: Dictionary) -> String:
	if upgrades == null:
		return "%d 幣" % item.cost
	if upgrades.owned.has(id):
		if _toggleable(id):
			return "運作中" if _automation_enabled(id) else "已暫停"
		if (id == &"steel_pick" and not using_drill) or (id == &"drill" and using_drill):
			return "裝備中"
		return "已解鎖"
	if item.needs != &"" and not upgrades.owned.has(item.needs):
		return "需%s" % Catalog.ITEMS[item.needs].name
	return "%d 幣" % item.cost if upgrades.can_purchase(id, coins) else "%d 幣 · 不足" % item.cost


func _apply_selection() -> void:
	if upgrades == null:
		return
	if not upgrades.owned.has(selected):
		purchase_requested.emit(selected)
	elif selected == &"steel_pick" or selected == &"drill":
		tool_requested.emit(selected == &"drill")
	elif _toggleable(selected):
		automation_toggled.emit(selected)


func _toggleable(id: StringName) -> bool:
	return id == &"robot" or id == &"crusher"


func _automation_enabled(id: StringName) -> bool:
	return collector_enabled if id == &"robot" else crusher_enabled


func _draw_links() -> void:
	for id: StringName in cards:
		var parent: StringName = Catalog.ITEMS[id].needs
		if route != card_routes[id] or parent == &"":
			continue
		var from := _link_point(cards[parent], 1.0)
		var to := _link_point(cards[id], 0.0)
		var active := upgrades != null and upgrades.owned.has(parent)
		var color := Color("64644d") if active else Color("9b744a")
		var middle := (from.x + to.x) * 0.5
		links.draw_polyline(PackedVector2Array([from, Vector2(middle, from.y), Vector2(middle, to.y), to]), color, 3, true)
		links.draw_circle(Vector2(middle, to.y), 4, color)


func _link_point(card: Control, edge: float) -> Vector2:
	return card.global_position + card.size * Vector2(edge, 0.5) - links.global_position
