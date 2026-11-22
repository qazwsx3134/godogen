extends CanvasLayer
## In-app purchases and rewarded ads behind one interface, so a real billing and ad SDK can replace the test store
## without touching the screens. This script is the test store; make it the base of an autoload's script:
##   extends "res://addons/proto_kit/store_front.gd"       # scripts/store.gd
##   func _ready() -> void:
##       products = {"gems_100": CONSUMABLE, "no_ads": NON_CONSUMABLE}
##       super()
##   func _ad_card_shown(placement: String) -> void: %AdOverlay.visible = true   # the game draws its own ad card
##   func _ad_card_tick(seconds_left: int) -> void: %AdCount.text = "%d" % seconds_left
##   func _ad_card_hidden() -> void: %AdOverlay.visible = false
##
## Screens call (a screen run without the autoload should treat every call as a success):
##   await Store.buy(id)               -> true when paid; the game then grants the product and saves
##   await Store.restore()             -> the non-consumable ids bought (恢復購買 / Restore Purchases)
##   await Store.show_ad(place, skip)  -> true when the ad ran to the end; skip = the player owns 免廣告, no ad shown
##   Store.is_test()                   -> true here: every surface that sells should say so
## What a product holds, its price and name stay in the game's own data; the store only knows ids and kinds.
##
## The test store charges nothing: buy() succeeds at once, a non-consumable is remembered in test_file (as a store
## account would), and an ad is the game's card counting down ad_seconds of game time (paused time does not count).
## A real backend overrides _charge, _restore_ids and _play_ad, and is_test.

const CONSUMABLE := "consumable"
const NON_CONSUMABLE := "non_consumable"

## Product id -> CONSUMABLE or NON_CONSUMABLE. buy() refuses ids not listed.
var products: Dictionary = {}
## Where the test store remembers non-consumables bought on this device (tests point it elsewhere).
var test_file: String = "user://store_test.json"
## Seconds of game time a test ad runs (0 = no card; tests set it).
var ad_seconds: float = 3.0
## Set while an ad is showing; another show_ad() is refused meanwhile.
var busy: bool = false

const _AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_test() -> bool:
	return true


func buy(product_id: String) -> bool:
	if not products.has(product_id):
		push_error("store: unknown product " + product_id)
		return false
	return await _charge(product_id)


func restore() -> PackedStringArray:
	return await _restore_ids()


## Shows a rewarded ad for `placement`; `skip` (the player owns 免廣告) gives the reward without one.
func show_ad(placement: String, skip: bool = false) -> bool:
	if busy:
		return false
	if skip:
		await get_tree().process_frame
		return true
	busy = true
	var watched: bool = await _play_ad(placement)
	busy = false
	return watched


## The ad card: the game shows and fills its own overlay in these.
func _ad_card_shown(_placement: String) -> void:
	pass


func _ad_card_tick(_seconds_left: int) -> void:
	pass


func _ad_card_hidden() -> void:
	pass


## Test backend: paid at once; a non-consumable is written to test_file.
func _charge(product_id: String) -> bool:
	await get_tree().process_frame
	if products[product_id] == NON_CONSUMABLE:
		var bought: PackedStringArray = _test_bought()
		if not bought.has(product_id):
			bought.append(product_id)
			_AtomicFile.write_text(test_file, JSON.stringify({"bought": Array(bought)}))
	return true


func _restore_ids() -> PackedStringArray:
	await get_tree().process_frame
	return _test_bought()


## Test backend: the card counts down ad_seconds of game time, a second at a time.
func _play_ad(placement: String) -> bool:
	if ad_seconds <= 0.0:
		await get_tree().process_frame
		return true
	_ad_card_shown(placement)
	var left: float = ad_seconds
	while left > 0.0:
		_ad_card_tick(ceili(left))
		await get_tree().create_timer(minf(left, 1.0), true, false, false).timeout
		left -= 1.0
	_ad_card_hidden()
	return true


func _test_bought() -> PackedStringArray:
	var bytes: PackedByteArray = _AtomicFile.read_bytes(test_file)
	if bytes.is_empty():
		return PackedStringArray()
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return PackedStringArray(data.get("bought", [])) if data is Dictionary else PackedStringArray()
