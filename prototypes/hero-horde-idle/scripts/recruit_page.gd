extends Control
## 招募 page (scenes/recruit.tscn, a page of scenes/home.tscn), after the author's pick (round3 B_recruit.png): gold
## and 招募券 with 商店; the 限時卡池 stage (the banner's SSR large in the tavern, name, rarity and class); 卡池倒數 and
## 機率說明; the 保底 count; 近期獲得 (the last five heroes pulled); 單抽 and 十連 for 招募券, and one 免費單抽 a day
## for a rewarded ad. Overlays: 機率說明 (domain/recruit.gd's RATES, the same table the roll uses), 商店 (the
## domain/shop.gd products through the Store autoload, with 恢復購買; marked 測試 while the store is a test one) and
## the results. A pulled hero brings 突破素材 (every hero is on the roster from the start). Saved after every pull or
## purchase. Layout lives in scenes/recruit.tscn (tools/build_recruit.gd).

const PushSim = preload("res://domain/push_sim.gd")
const PushReport = preload("res://domain/push_report.gd")
const Progression = preload("res://domain/progression.gd")
const Recruit = preload("res://domain/recruit.gd")
const Shop = preload("res://domain/shop.gd")
const Portraits = preload("res://scripts/portraits.gd")
const Items = preload("res://domain/items.gd")

## Set before the page enters the tree to use other progress (tests); otherwise the App's.
var progress: RefCounted = null
## "" = the App's progress_path (the player's save), or Progression.SAVE_PATH without the App.
var save_path: String = ""
## Unix seconds now (tests replace it).
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
## The last pulls shown in the results ({hero, rarity, featured, shards} each).
var last: Array = []

var _names: PackedStringArray = PushReport.load_names()
var _tick: float = 0.0

@onready var _gold: Label = %Gold
@onready var _tickets: Label = %Tickets
@onready var _art: TextureRect = %BannerArt
@onready var _banner_name: Label = %BannerName
@onready var _banner_tag: Label = %BannerTag
@onready var _countdown: Label = %Countdown
@onready var _pity_line: Label = %PityLine
@onready var _pity_count: Label = %PityCount
@onready var _pity_bar: ProgressBar = %PityBar
@onready var _recent: HBoxContainer = %Recent
@onready var _single: Button = %Single
@onready var _ten: Button = %Ten
@onready var _ad_pull: Button = %AdPull
@onready var _toast: Label = %Toast
@onready var _rates: Control = %RatesOverlay
@onready var _shop: Control = %ShopOverlay
@onready var _results: Control = %ResultsOverlay
@onready var _result_cards: GridContainer = %ResultCards


func _ready() -> void:
	if progress == null:
		var app: Node = get_node_or_null(^"/root/App")
		progress = app.progress() if app != null and save_path == "" else Progression.load_from(_save_path())
	_single.pressed.connect(pull.bind(1))
	_ten.pressed.connect(pull.bind(Recruit.TEN))
	_ad_pull.pressed.connect(ad_pull)
	%RatesButton.pressed.connect(func() -> void: _rates.visible = true)
	%RatesClose.pressed.connect(func() -> void: _rates.visible = false)
	%ShopButton.pressed.connect(func() -> void: _shop.visible = true)
	%ShopClose.pressed.connect(func() -> void: _shop.visible = false)
	%Restore.pressed.connect(restore)
	%ResultsClose.pressed.connect(func() -> void: _results.visible = false)
	%RatesText.text = "\n".join(Recruit.rates_lines())
	var products: Node = %Products
	for k: int in products.get_child_count():
		var row: Node = products.get_child(k)
		row.visible = k < Shop.PRODUCTS.size()
		if k < Shop.PRODUCTS.size():
			(row.get_node(^"Buy") as Button).pressed.connect(buy.bind(Shop.PRODUCTS[k].id))
	%ShopNote.visible = _test_store()
	_rates.visible = false
	_shop.visible = false
	_results.visible = false
	_toast.text = ""
	refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0 and visible:
		_tick = 1.0
		_countdown.text = Recruit.clock_text(Recruit.rotation_left(clock.call()))
		_show_ad_button()


func refresh() -> void:
	if progress == null:
		return
	var now: int = clock.call()
	_gold.text = "%d" % progress.gold
	_tickets.text = "%d" % progress.tickets
	var hero: int = Recruit.featured(now)
	var c: int = Progression.base_class(hero)
	_art.texture = Portraits.full(c)
	_banner_name.text = PushReport.hero_name(_names, hero)
	_banner_tag.text = "SSR　｜　%s" % Portraits.TITLES[c]
	_countdown.text = Recruit.clock_text(Recruit.rotation_left(now))
	_pity_line.text = "再 %d 抽必出 SSR" % progress.pity_left()
	_pity_count.text = "%d／%d" % [progress.pity, Recruit.PITY]
	_pity_bar.max_value = Recruit.PITY
	_pity_bar.value = progress.pity
	for k: int in _recent.get_child_count():
		var i: int = progress.recent[k] if k < progress.recent.size() else -1
		_recent.get_child(k).show_pull(i, PushReport.hero_name(_names, i) if i >= 0 else "", progress, "")
	_single.disabled = progress.tickets < 1
	_ten.disabled = progress.tickets < Recruit.TEN
	var products: Node = %Products
	for k: int in mini(products.get_child_count(), Shop.PRODUCTS.size()):
		var p: Dictionary = Shop.PRODUCTS[k]
		var row: Node = products.get_child(k)
		(row.get_node(^"Words/Name") as Label).text = p.name
		(row.get_node(^"Words/Tag") as Label).text = p.get("tag", "")
		(row.get_node(^"Icon") as TextureRect).texture = Items.material_icon("tickets") if p.tickets > 0 else null
		var button: Button = row.get_node(^"Buy")
		button.text = "已購買" if progress.owns(p.id) else p.price
		button.disabled = progress.owns(p.id)
	_show_ad_button()


func _show_ad_button() -> void:
	var open: bool = progress.ad_pull_ready(clock.call())
	_ad_pull.disabled = not open
	if not open:
		_ad_pull.text = "今天的免費單抽領過了"
	else:
		_ad_pull.text = "免費單抽（免廣告）" if progress.owns("no_ads") else "看廣告　免費單抽"


## 單抽 / 十連 with 招募券. Returns the pulls (empty when the tickets do not cover it).
func pull(count: int) -> Array:
	var got: Array = progress.recruit(count, clock.call())
	if got.is_empty():
		_toast.text = "招募券不夠：首次通關每關給 %d 張，也可以在商店買" % Recruit.FIRST_TICKETS
		return got
	_after_pull(got)
	return got


## 免費單抽 after a rewarded ad (straight away with 免廣告).
func ad_pull() -> void:
	if not progress.ad_pull_ready(clock.call()):
		return
	var store: Node = get_node_or_null(^"/root/Store")
	if store != null and not await store.show_ad("free_pull", progress.owns("no_ads")):
		return
	var one: Dictionary = progress.free_pull(clock.call())
	if not one.is_empty():
		_after_pull([one])


func buy(product_id: String) -> void:
	var store: Node = get_node_or_null(^"/root/Store")
	if store != null and not await store.buy(product_id):
		_toast.text = "購買沒有完成"
		return
	if progress.grant(product_id):
		progress.save(_save_path())
		_toast.text = "已購買 %s" % Shop.product(product_id).name
	refresh()


## 恢復購買: gives back the non-consumables the store remembers.
func restore() -> void:
	var store: Node = get_node_or_null(^"/root/Store")
	var ids: PackedStringArray = await store.restore() if store != null else PackedStringArray()
	var back: int = 0
	for id: String in ids:
		if not progress.owns(id) and progress.grant(id):
			back += 1
	if back > 0:
		progress.save(_save_path())
	_toast.text = "恢復了 %d 項購買" % back if back > 0 else "沒有需要恢復的購買"
	refresh()


func _after_pull(got: Array) -> void:
	last = got
	progress.save(_save_path())
	var shards: int = 0
	var best: int = 0
	for one: Dictionary in got:
		shards += one.shards
		best = maxi(best, one.rarity)
	for k: int in _result_cards.get_child_count():
		var card: Node = _result_cards.get_child(k)
		card.visible = k < got.size()
		if k < got.size():
			var one: Dictionary = got[k]
			card.show_pull(one.hero, PushReport.hero_name(_names, one.hero), progress,
				("限時！" if one.featured else "") + "素材 +%d" % one.shards, one.rarity)
	%ResultsText.text = "英雄之魂化為突破素材 +%d　（現有 %d）" % [shards, progress.shards]
	%ResultsTitle.text = "招募結果" + ("　SSR！" if best == PushSim.SSR else "")
	_results.visible = true
	_toast.text = ""
	refresh()


func _test_store() -> bool:
	var store: Node = get_node_or_null(^"/root/Store")
	return store == null or store.is_test()


func _save_path() -> String:
	if save_path == "":
		var app: Node = get_node_or_null(^"/root/App")
		save_path = app.progress_path if app != null else Progression.SAVE_PATH
	return save_path
