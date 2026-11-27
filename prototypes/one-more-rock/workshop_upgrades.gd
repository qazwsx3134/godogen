extends RefCounted

const ROUTES := {
	&"Hammer": {"name": "破石槌", "description": "逐級開啟硬度更高的原石。", "columns": [[&"steel_hammer"], [&"diamond_hammer"]]},
	&"Finish": {"name": "品相", "description": "提高每一顆原石的加工價值。", "columns": [[&"finishing"], [&"polishing"]]},
	&"Mining": {"name": "採掘工具", "description": "在大範圍劈鑿與快速近距離挖掘之間換裝。", "columns": [[&"steel_pick"], [&"drill"]]},
	&"Yield": {"name": "出礦", "description": "同樣一擊可以挖出更多原石。", "columns": [[&"ore_yield"], [&"ore_yield_2"]]},
	&"Pickup": {"name": "拾取", "description": "走過碎岩時把更大片範圍掃乾淨。", "columns": [[&"pickup_reach"], [&"fast_pickup"]]},
	&"Transport": {"name": "搬運", "description": "讓每趟回工坊運更多原石。", "columns": [[&"bag", &"bin"], [&"cart_rack"]]},
	&"Mobility": {"name": "體能", "description": "更快往返，在崎嶇的礦面上移動。", "columns": [[&"running_boots"], [&"spring_boots"]]},
	&"Automation": {"name": "自動化", "description": "把拾運與三階破石接成同一條產線。", "columns": [[&"robot"], [&"crusher"], [&"crusher_steel"], [&"crusher_diamond"]]},
}

const ITEMS := {
	&"steel_hammer": {"name": "鍛鋼槌", "cost": 30, "needs": &"",
		"detail": "每擊強度 2，可開硬度 2 的緻密原石。"},
	&"diamond_hammer": {"name": "鑽尖槌", "cost": 65, "needs": &"steel_hammer",
		"detail": "每擊強度 3，可開硬度 3 的稀有原石。"},
	&"finishing": {"name": "修面工具組", "cost": 22, "needs": &"",
		"detail": "每顆新原石的起始品相 +0.10，每次敲擊再多加 0.02。"},
	&"polishing": {"name": "精修工具組", "cost": 45, "needs": &"finishing",
		"detail": "起始品相共 +0.20，每次敲擊共多加 0.04。"},
	&"steel_pick": {"name": "鋼製十字鎬", "cost": 35, "needs": &"",
		"detail": "挖得更深，每擊能剝下更大一塊岩體。"},
	&"drill": {"name": "電鑽", "cost": 55, "needs": &"steel_pick",
		"detail": "按住持續鑽掘，近距離快速挖穿小範圍岩面。"},
	&"bag": {"name": "加大背包", "cost": 25, "needs": &"",
		"detail": "背包容量從 5 顆增至 10 顆。"},
	&"bin": {"name": "加大料斗", "cost": 32, "needs": &"",
		"detail": "工坊庫存從 30 顆增至 60 顆。"},
	&"cart_rack": {"name": "加高車斗", "cost": 46, "needs": &"bag",
		"detail": "推車容量從 20 顆增加到 30 顆。"},
	&"ore_yield": {"name": "沿紋劈鑿", "cost": 37, "needs": &"",
		"detail": "每次成功採掘，多產出 1 顆原石。"},
	&"ore_yield_2": {"name": "整面剝採", "cost": 78, "needs": &"ore_yield",
		"detail": "每次成功採掘，多產出 2 顆原石。"},
	&"pickup_reach": {"name": "擴大拾取", "cost": 24, "needs": &"",
		"detail": "普通原石的自動拾取半徑從 2.1 公尺增加到 3 公尺。"},
	&"fast_pickup": {"name": "快速入袋", "cost": 42, "needs": &"pickup_reach",
		"detail": "原石飛進背包或推車的時間從 0.62 秒縮短至 0.36 秒。"},
	&"running_boots": {"name": "輕步靴", "cost": 25, "needs": &"",
		"detail": "跑步速度從每秒 7.2 公尺增加到 8.6 公尺。"},
	&"spring_boots": {"name": "彈簧靴", "cost": 48, "needs": &"running_boots",
		"detail": "提高起跳速度，起跳高度約增加三成。"},
	&"robot": {"name": "拾運機器人", "cost": 55, "needs": &"",
		"detail": "撿起地上已落穩的普通原石，一次一顆送進木屋旁的料斗。"},
	&"crusher": {"name": "自動破石機", "cost": 50, "needs": &"robot",
		"detail": "從料斗加工硬度 1 的原石，完成後按礦物基價入帳。可獨立暫停。"},
	&"crusher_steel": {"name": "破石機 · 鍛鋼", "cost": 80, "needs": &"crusher",
		"detail": "升級破石機到硬度 2。可處理緻密原石，方解石的機率較高。"},
	&"crusher_diamond": {"name": "破石機 · 鑽尖", "cost": 125, "needs": &"crusher_steel",
		"detail": "升級破石機到硬度 3。玩家親自撿起並卸入料斗的稀有原石也能加工。"},
}

var owned: Dictionary[StringName, bool] = {}


func can_purchase(id: StringName, coins: int) -> bool:
	if not ITEMS.has(id) or owned.has(id):
		return false
	var item: Dictionary = ITEMS[id]
	return coins >= int(item.cost) and (item.needs == &"" or owned.has(item.needs))
