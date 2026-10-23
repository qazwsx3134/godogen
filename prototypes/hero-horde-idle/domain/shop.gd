extends RefCounted
## 商店 (in-app purchases) and 看廣告 rewards, as pure data. What each product grants is applied by progression.gd
## (grant()); paying and showing ads goes through scripts/store.gd, which is a test store until a real billing and ad
## SDK is wired in. Prices are placeholders.
##   consumable      招募券 packs: bought again and again; the tickets never expire
##   non_consumable  免廣告: bought once, comes back with 恢復購買 (App Store guideline 3.1.1); the ad rewards are given
##                   without watching
## Ad rewards (placement -> what it gives): free_pull = one 免費單抽 a day (domain/recruit.gd AD_PULLS_PER_DAY);
## march_double = the gold of the march just claimed, once more.

const PRODUCTS := [
	{"id": "tickets_10", "name": "招募券 ×10", "price": "NT$ 90", "tickets": 10, "kind": "consumable"},
	{"id": "tickets_60", "name": "招募券 ×60", "price": "NT$ 490", "tickets": 60, "kind": "consumable",
		"tag": "多送 10 張"},
	{"id": "no_ads", "name": "免廣告", "price": "NT$ 150", "tickets": 0, "kind": "non_consumable",
		"tag": "看廣告的獎勵直接領"},
]
const PLACEMENTS := ["free_pull", "march_double"]


static func product(id: String) -> Dictionary:
	for p: Dictionary in PRODUCTS:
		if p.id == id:
			return p
	return {}
