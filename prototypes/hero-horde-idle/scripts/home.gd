extends Control
## The screen between pushes (scenes/home.tscn, the main scene): the 營地, 養成, 招募, 道具 and 關卡 pages above a nav bar that
## switches between them at once (no fade); the nav bar stays on every page, the hero page too. A page refreshes when
## it is shown. Red dots on the nav bar mark a page with something to do (progression.gd todo()); the 營地's 待辦
## rows jump to their page. The App hands over which tab to open ("tab").

const TABS := [&"camp", &"growth", &"recruit", &"items", &"stages"]

var tab: StringName = &"camp"
var _dots_in: float = 0.0

@onready var _buttons: HBoxContainer = %NavButtons
@onready var _page_nodes: Array[Control] = [%CampPage, %GrowthPage, %RecruitPage, %ItemsPage,
	%StagesPage]


func _ready() -> void:
	for k: int in TABS.size():
		(_buttons.get_child(k) as Button).pressed.connect(show_tab.bind(TABS[k]))
	%CampPage.tab_requested.connect(func(which: StringName, cls: int) -> void:
		show_tab(which)
		if which == &"growth" and cls >= 0:
			%GrowthPage.select_class(cls))
	var app: Node = get_node_or_null(^"/root/App")
	show_tab(app.take(&"tab", &"camp") if app != null else &"camp")


func _process(delta: float) -> void:
	_dots_in -= delta
	if _dots_in <= 0.0:
		_dots_in = 1.0
		update_dots()


## The nav bar's red dots: 營地 when march hours wait to be claimed, 養成 when gold or shards can be spent, 招募 when
## the tickets cover a 十連 or today's 免費單抽 is there, 道具 when a better item can be equipped or 強化石 cover a 強化.
func update_dots() -> void:
	var now: int = %CampPage.clock.call()
	var items: Array = %CampPage.progress.todo(now)
	var kinds: Array = items.map(func(item: Dictionary) -> String: return item.kind)
	(%NavCamp.get_node(^"Dot") as Control).visible = kinds.has("march")
	(%NavGrowth.get_node(^"Dot") as Control).visible = kinds.has("class") or kinds.has("ascend")
	(%NavRecruit.get_node(^"Dot") as Control).visible = kinds.has("recruit") or %CampPage.progress.ad_pull_ready(now)
	(%NavItems.get_node(^"Dot") as Control).visible = kinds.has("equip") or kinds.has("armory")


func show_tab(which: StringName) -> void:
	tab = which
	for k: int in TABS.size():
		var on: bool = TABS[k] == which
		_page_nodes[k].visible = on
		(_buttons.get_child(k) as Button).button_pressed = on
		if on:
			_page_nodes[k].refresh()
	update_dots()

