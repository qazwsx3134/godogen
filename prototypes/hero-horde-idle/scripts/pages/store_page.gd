extends Control
## 商店 (scenes/pages/store.tscn, Taskbar Hero's store.png page): four product cards (單抽 and 十連 for 招募券, a
## ticket pack and 免廣告 through the Store autoload: a test store until a billing SDK is wired in), the daily free
## pull for a rewarded ad, and 機率說明 (domain/recruit.gd RATES, the numbers the rolls use). Pull results and the odds
## open in the home screen's dialog.

signal changed
signal open_tab(tab: StringName)
signal message(text: String)
signal dialog_requested(title: String, body: String)

const Recruit = preload("res://domain/recruit.gd")
const Progression = preload("res://domain/progression.gd")
const Shop = preload("res://domain/shop.gd")
const PushSim = preload("res://domain/push_sim.gd")
const Heroes = preload("res://domain/heroes.gd")
const UiArt = preload("res://scripts/ui_art.gd")
const Names = preload("res://domain/push_report.gd")

## The cards in order: [kind, product id or pull count].
const CARDS := [["pull", 1], ["pull", 10], ["buy", "tickets_60"], ["buy", "no_ads"]]

var progress: RefCounted = null
## The clock (unix seconds); tests replace it.
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var names := PackedStringArray()


func _ready() -> void:
	for k: int in mini(%ProductGrid.get_child_count(), CARDS.size()):
		(%ProductGrid.get_child(k).get_node("BuyButton") as Button).pressed.connect(_card.bind(k))
	%GiftButton.pressed.connect(_free_pull)
	%RatesButton.pressed.connect(func() -> void:
		dialog_requested.emit("機率說明", "\n".join(Recruit.rates_lines())))


func _card(k: int) -> void:
	var spec: Array = CARDS[k]
	if spec[0] == "pull":
		var got: Array = progress.recruit(spec[1], clock.call())
		if got.is_empty():
			message.emit("招募券不夠（要 %d 張）" % spec[1])
			return
		changed.emit()
		dialog_requested.emit("招募結果", _pulls_text(got))
		return
	var store: Node = get_node_or_null(^"/root/Store")
	if store != null and not await store.buy(spec[1]):
		message.emit("購買取消")
		return
	if progress.grant(spec[1]):
		message.emit("已購買：%s" % Shop.product(spec[1]).name)
		changed.emit()


func _free_pull() -> void:
	var now: int = clock.call()
	if not progress.ad_pull_ready(now):
		message.emit("今天的免費招募已經用過了")
		return
	var store: Node = get_node_or_null(^"/root/Store")
	if store != null and not await store.show_ad("free_pull", progress.owns("no_ads")):
		return
	var got: Dictionary = progress.free_pull(now)
	if not got.is_empty():
		changed.emit()
		dialog_requested.emit("免費招募", _pulls_text([got]))


func _pulls_text(got: Array) -> String:
	if names.is_empty():
		names = Names.load_names()
	var lines := PackedStringArray()
	var shards: int = 0
	for g: Dictionary in got:
		var i: int = g.hero
		lines.append("%s　%s（%s%s）%s　→ 突破素材 ×%d" % [PushSim.RARITY_NAMES[g.rarity], Names.hero_name(names, i),
			Heroes.FORM_NAMES[Heroes.form(i)], PushSim.CLASS_NAMES[Progression.base_class(i)],
			"・限時" if g.featured else "", g.shards])
		shards += g.shards
	lines.append("\n共得到突破素材 ×%d（到英雄頁突破）" % shards)
	return "\n".join(lines)


func refresh() -> void:
	if progress == null:
		return
	var now: int = clock.call()
	if names.is_empty():
		names = Names.load_names()
	var featured: int = Recruit.featured(now)
	%StoreSubtitle.text = "限時英雄：%s（剩 %s）　保底還有 %d 抽　招募券 %d 張" % [Names.hero_name(names, featured),
		Recruit.clock_text(Recruit.rotation_left(now)), progress.pity_left(), progress.tickets]
	for k: int in mini(%ProductGrid.get_child_count(), CARDS.size()):
		var card: Control = %ProductGrid.get_child(k)
		var spec: Array = CARDS[k]
		var buy: Button = card.get_node("BuyButton")
		if spec[0] == "pull":
			(card.get_node("Title") as Label).text = "單抽" if spec[1] == 1 else "十連招募"
			(card.get_node("Icon") as TextureRect).texture = UiArt.material_icon("tickets")
			(card.get_node("Quantity") as Label).text = "招募券 ×%d" % spec[1]
			(card.get_node("Description") as Label).text = "抽到的英雄化為突破素材" if spec[1] == 1 else "SSR 3%，30 抽保底"
			buy.text = "招募"
			buy.disabled = progress.tickets < spec[1]
		else:
			var p: Dictionary = Shop.product(spec[1])
			(card.get_node("Title") as Label).text = p.name
			(card.get_node("Icon") as TextureRect).texture = UiArt.tex("product_1" if p.tickets > 0 else "video_icon")
			(card.get_node("Quantity") as Label).text = p.get("tag", "招募券 ×%d" % p.tickets)
			(card.get_node("Description") as Label).text = "測試商店，不會扣款" if _test_store() else ""
			var owned: bool = p.kind == "non_consumable" and progress.owns(spec[1])
			buy.text = "已購買" if owned else p.price
			buy.disabled = owned
	%GiftDescription.text = ("今天還可以免費招募一次。" if progress.ad_pull_ready(now) else "今天的免費招募已用完，明天再來。") \
		+ ("\n已買免廣告：直接領取。" if progress.owns("no_ads") else "\n看一段廣告就能免費單抽。")
	%GiftButton.disabled = not progress.ad_pull_ready(now)
	%GiftButton.text = "免費招募" if progress.owns("no_ads") else "看廣告招募"


func _test_store() -> bool:
	var store: Node = get_node_or_null(^"/root/Store")
	return store == null or store.is_test()
