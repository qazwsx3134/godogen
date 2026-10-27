extends "res://addons/proto_kit/store_front.gd"
## Store (autoload scenes/store.tscn): paying for products and showing rewarded ads through godot-kit's store_front,
## so a real billing and ad SDK can replace the test store without touching the screens. Screens call
##   await Store.buy(id)        -> true when paid; the screen then gives it with progression.grant(id) and saves
##   await Store.restore()      -> the non-consumable ids the store says were bought (恢復購買)
##   await Store.show_ad(place) -> true when the ad was watched to the end (or the player owns 免廣告)
## The products are domain/shop.gd's. While is_test() nothing is charged, an ad is the dimmed card below counting
## down ad_seconds of game time, and every surface that sells says 測試. A screen without the autoload (tests) treats
## every call as a test success.

const Shop = preload("res://domain/shop.gd")
## What the test ad card says each placement pays.
const AD_TITLES := {"free_pull": "免費單抽", "march_double": "金幣再領一次"}

@onready var _ad: Control = %AdOverlay
@onready var _ad_count: Label = %AdCount
@onready var _ad_title: Label = %AdTitle


func _ready() -> void:
	for p: Dictionary in Shop.PRODUCTS:
		products[p.id] = p.kind
	super()
	_ad.visible = false


func _ad_card_shown(placement: String) -> void:
	_ad_title.text = "廣告（測試）：%s" % AD_TITLES.get(placement, placement)
	_ad.visible = true


func _ad_card_tick(seconds_left: int) -> void:
	_ad_count.text = "%d 秒後領取獎勵" % seconds_left


func _ad_card_hidden() -> void:
	_ad.visible = false
