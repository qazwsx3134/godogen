# 能力目錄（由 tools/capabilities.py build 產生）

用途與範例由 catalog/specs.json 維護；參數、回傳型別、訊號與原碼註解由來源擷取。
完整結構化契約見 catalog/capabilities.json；先讀 docs/COMPOSITION.md。

| ID | 用途／情境 | 類型 |
|---|---|---|
| [atomic_file](#atomic_file) | 原子式檔案提交；存檔落盤，備份政策由呼叫端決定 | rule |
| [auto_caster](#auto_caster) | 自動施法、選敵與冷卻；輸出施法事件交由戰鬥系統套用 | rule |
| [camera_shake](#camera_shake) | 2D trauma 震屏；打擊回饋與無障礙強度調整 | rule |
| [camera_shot](#camera_shot) | 可存成 Resource 的鏡頭演出參數；策劃在 Inspector 調校 | resource |
| [card_draft](#card_draft) | 加權升級選卡、重抽與放逐；局內 roguelite 成長 | rule |
| [chest_shop](#chest_shop) | 遞增價格的局內寶箱；消費貨幣取得加權獎勵 | rule |
| [combo_input](#combo_input) | 節拍連招與雙鍵和弦判定；輸入已正規化按鍵和秒數 | rule |
| [damage_numbers_3d](#damage_numbers_3d) | 池化 3D 傷害數字；跨存活類遊戲的純視覺回饋 | node |
| [fixed_step](#fixed_step) | 固定步長累積器；可選保留或丟棄追趕時間 | rule |
| [floating_stick](#floating_stick) | 浮動虛擬搖桿；觸控區輸出螢幕方向向量 | node |
| [font_check](#font_check) | 檢查字型涵蓋遊戲字元；Web 匯出與字型子集驗證 | inspection |
| [gacha](#gacha) | 獨立亂數流的加權抽取、保底與指定角色；召喚規則 | rule |
| [game_clock](#game_clock) | 可暫停遊戲時鐘與背景恢復；遊戲規則共用時間來源 | node |
| [haptics](#haptics) | 手機震動分級、節流與支援偵測；事件手感回饋 | rule |
| [hd2d_demo](#hd2d_demo) | HD-2D 組合示範；製作期研究各元件接線 | authoring |
| [hd2d_gallery](#hd2d_gallery) | HD-2D 擷取工具；比較鏡頭與渲染預設 | inspection |
| [hd2d_look](#hd2d_look) | HD-2D 環境、景深與暗角資源；製作期保存外觀預設 | authoring |
| [hd2d_stage](#hd2d_stage) | 場景燈光取樣與火光變化；像素角色融入 3D 環境 | node |
| [loot_ledger](#loot_ledger) | 首領掉落、區域解鎖與裝備收藏；永久收集成長 | rule |
| [march_strip](#march_strip) | 放置行軍展示；把收益規則留在遊戲端 | node |
| [music](#music) | 背景音樂交叉淡入淡出；場景切換與暫停仍保持播放 | node |
| [nine_slice](#nine_slice) | PNG 九宮格 Theme 製作；保留既有主題其他設定 | authoring |
| [orientation_guard](#orientation_guard) | 手機方向遮罩；阻擋錯誤方向下的點擊 | node |
| [pet_care](#pet_care) | 寵物飢餓、餵食與進化；城鎮與野外養成 | rule |
| [pixel_card3d](#pixel_card3d) | 可編輯像素圖卡；HD-2D 道具、樹木與建築立片 | node |
| [pixel_vfx](#pixel_vfx) | 2D 像素打擊特效；形狀、粒子與 shader 擴充 | node |
| [pixel_vfx3d](#pixel_vfx3d) | 3D 像素碎片與地面波紋；立體打擊回饋 | node |
| [rarity](#rarity) | 稀有度權重與加成；與選卡、技能升級組合 | rule |
| [refine_ladder](#refine_ladder) | 裝備精煉、失敗結果與成本估算；強化系統 | rule |
| [run_goals](#run_goals) | 局內／跨局目標與獎勵解鎖；事件式進度追蹤 | rule |
| [run_timeline](#run_timeline) | 局內事件與生怪預算；定時首領和難度曲線 | rule |
| [save_slots](#save_slots) | JSON 版本、備份恢復與遷移鏈；跨版本進度存檔 | rule |
| [scene_builder](#scene_builder) | 儲存可編輯場景與 owner 驗證；一次性製作工具 | authoring |
| [scene_loader](#scene_loader) | 背景載入與顯示進度；自訂載入畫面的邏輯 | rule |
| [scene_router](#scene_router) | 淡出換場與一次性交接資料；畫面導航 | node |
| [screenshot](#screenshot) | Viewport 圖片擷取；多解析度畫面檢查 | inspection |
| [sfx_bank](#sfx_bank) | 依事件名播放音效、後備與聲道節流；遊戲音效接線 | node |
| [shot_camera](#shot_camera) | 固定構圖鏡頭演出與優先權；HD-2D 戰鬥運鏡 | node |
| [song_clock](#song_clock) | 歌曲聽覺時間與拍子換算；節奏遊戲判定 | node |
| [sprite3d_actor](#sprite3d_actor) | 單位 billboard 動畫與朝向；主角、首領、NPC | node |
| [sprite3d_gallery](#sprite3d_gallery) | sprite3d 展示擷取；製作期檢查視角與動畫 | inspection |
| [sprite3d_sheet](#sprite3d_sheet) | 圖集、方向與動畫資料資源；單位與 MultiMesh 共用規格 | resource |
| [sprite_check](#sprite_check) | 圖集裁切、空白幀與腳底跳動檢查；素材品質驗證 | inspection |
| [sprite_inspector](#sprite_inspector) | 可互動 sprite 檢查場景；逐幀、方向、洋蔥皮檢查 | inspection |
| [sprite_inspector_atlas](#sprite_inspector_atlas) | sprite 檢查器的圖集子元件；由檢查場景組合 | internal |
| [sprite_inspector_frame](#sprite_inspector_frame) | sprite 檢查器的單幀子元件；固定比例查看幀 | internal |
| [store_front](#store_front) | 模擬購買與獎勵廣告介面；開發測試與未來 SDK adapter | node |
| [synth](#synth) | 程序合成 WAV 佔位音；不依賴音效素材的原型開發 | rule |
| [talent_tiers](#talent_tiers) | 分系天賦、前置與多套配置；長期角色成長 | rule |
| [tap_picker_3d](#tap_picker_3d) | 螢幕點選角色與地面；手機 3D 選取 | rule |
| [test_kit](#test_kit) | Godot headless 測試基底；斷言、等待與輸入模擬 | inspection |
| [time_control](#time_control) | 牆上時間驅動 hit stop；集中管理 Engine.time_scale | node |
| [ui.ui_theme](#ui-ui_theme) | 從樣式資料製作 Theme；手機 UI 版型的主題來源 | rule |
| [upgrade_tree](#upgrade_tree) | 永久升級與天賦相鄰圖；購買預覽、退款與屬性加總 | rule |
| [vfx.2d.sheet_effect](#vfx-2d-sheet_effect) | 2D 圖集特效場景行為；完成訊號與生命週期 | node |
| [vfx.3d.00gamedevs.impact_demo](#vfx-3d-00gamedevs-impact_demo) | 命中特效展示宿主；只用於預覽 | internal |
| [vfx.3d.00gamedevs.impact_frame](#vfx-3d-00gamedevs-impact_frame) | 全畫面命中效果；中心、方向與遮罩參數 | node |
| [vfx.3d.00gamedevs.source_effect](#vfx-3d-00gamedevs-source_effect) | 原生 mesh／shader 特效播放；投射物、光束與命中 | node |
| [vfx.3d.00gamedevs.spell_indicator](#vfx-3d-00gamedevs-spell_indicator) | 地面圓形／扇形預警；手動進度與遊戲時鐘 | node |
| [vfx.3d.00gamedevs.trail_demo](#vfx-3d-00gamedevs-trail_demo) | 拖尾展示宿主；只用於預覽 | internal |
| [vfx.3d.00gamedevs.weapon_smear](#vfx-3d-00gamedevs-weapon_smear) | 武器拖尾；綁定真實武器的世界座標軌跡 | node |
| [vfx.3d.pixel_burst](#vfx-3d-pixel_burst) | 3D 像素爆發場景 adapter；自動或手動步進 | node |
| [vfx.3d.sheet_effect](#vfx-3d-sheet_effect) | 3D billboard 圖集特效；共用 SpriteFrames | node |
| [vfx.gallery](#vfx-gallery) | 特效場景瀏覽器；開發者預覽 | inspection |
| [vfx.library](#vfx-library) | 以 ID 取得 2D／3D 特效場景；素材目錄入口 | rule |
| [vfx.preview_2d](#vfx-preview_2d) | 2D 特效預覽宿主；配合 gallery | inspection |
| [vfx.preview_3d](#vfx-preview_3d) | 3D 特效預覽宿主；配合 gallery | inspection |
| [vfx.sheet_frames](#vfx-sheet_frames) | 橫向圖集轉 SpriteFrames；2D／3D 動畫共用 | rule |
| [vfx_gallery](#vfx_gallery) | 2D 特效比較擷取；固定時間點輸出圖片 | inspection |
| [weighted_choice](#weighted_choice) | 有序浮點權重抽取；共用單一演算法並保留亂數消耗契約 | rule |

## atomic_file

原子式檔案提交；存檔落盤，備份政策由呼叫端決定

適用：存檔落盤，備份政策由呼叫端決定

入口：[addons/proto_kit/atomic_file.gd](../../addons/proto_kit/atomic_file.gd) · rule · 來源靜態引用：debt-commission、dreamling-idle、hero-horde-idle、pixel-monster、seal-meadow、skybound-blades、star-tide-harbor、survivor-series、taskbar-hero；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。 不提供多寫入者鎖；平台 rename fallback 與 Web IndexedDB 持久化仍需平台測試。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/atomic_file.gd")
var error: Error = Capability.write_text("user://progress.json", "{\"level\":1}")
if error != OK:
    push_error(error_string(error))
```

### 參數、輸出與訊號

```gdscript
static func write_bytes(path: String, bytes: PackedByteArray) -> Error:
static func write_text(path: String, text: String) -> Error:
static func write_var(path: String, value: Variant) -> Error:
static func read_bytes(path: String) -> PackedByteArray:
```

Crash-tolerant file commit: write `path.tmp`, flush, read it back to verify, then rename it
over `path`. An interrupted save leaves either the old file or the new one, never a torn mix.
`const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")`

Backup policy (.bak, validation, recovery) stays with each game; this is only the commit step.
Pass user:// paths as-is. On Web, DirAccess routes virtual paths through the persistent
IndexedDB filesystem; ProjectSettings.globalize_path would bypass it.
Same byte layout as FileAccess.store_var(value, false), so FileAccess.get_var reads it back.
Empty when the file is missing or unreadable.

測試引用（存在不等於本輪已重跑）：tests/test_m0_modules.gd, tests/test_proto_kit.gd

## auto_caster

自動施法、選敵與冷卻；輸出施法事件交由戰鬥系統套用

適用：輸出施法事件交由戰鬥系統套用

入口：[addons/proto_kit/auto_caster.gd](../../addons/proto_kit/auto_caster.gd) · rule · 來源靜態引用：dreamling-idle；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/auto_caster.gd")
var book = Capability.new()
book.learn({"id": "slash", "damage": 10.0, "range": 3.0})
var casts: Array = book.step(0.1, Vector3.ZERO, [{"id": "e1", "pos": Vector3.ONE, "hp": 20.0, "max_hp": 20.0, "tags": []}])
```

### 參數、輸出與訊號

```gdscript
var damage_mult: float = 1.0
var cooldown_mult: float = 1.0
func _init(rng: RandomNumberGenerator = null) -> void:
func learn(spell: Dictionary, bonus: Dictionary = {}) -> void:
func rank_up(id: String, bonus: Dictionary = {}) -> bool:
func knows(id: String) -> bool:
func rank(id: String) -> int:
func spells() -> Array[String]:
func effective(id: String) -> Dictionary:
func buff_mult() -> float:
func step(delta: float, origin: Variant, targets: Array) -> Array[Dictionary]:
func reset(forget_spells: bool = false) -> void:
func to_dict() -> Dictionary:
func from_dict(data: Dictionary) -> void:
```

Auto-cast spell book for survivor-likes: every learned spell fires on its own cooldown at targets chosen by a rule.
Pure logic, no nodes: each step the game passes the caster's position and the candidate targets, and turns the
returned casts into effects, numbers and sounds. `const AutoCaster = preload("res://addons/proto_kit/auto_caster.gd")`

var book := AutoCaster.new()
book.learn({"id": "cleave", "cooldown": 1.5, "range": 3.0, "target": "nearest", "max_targets": 3, "damage": 40})
book.rank_up("cleave", {"damage": 0.18})               # a drafted upgrade; Rarity.bonus() builds the dict
for cast in book.step(delta, me.position, enemies):   # enemies: [{id, pos, hp, max_hp, tags}]
for hit in cast.hits: damage(hit.id, hit.damage)

Spell fields (only id is required):
cooldown (s, 1.0)  range (m, 5.0)  damage (per target, 0)  max_targets (1)
target: "nearest" | "farthest" | "highest_hp" | "lowest_hp" | "random" | "all" | "self"
priority: tags picked before anything else, in order (["boss", "elite"]); inside a tag the target rule decides
execute_below + execute_mult: damage multiplier on targets under that HP ratio (they are also preferred)
heal_ratio: the caster heals this share of the damage dealt (cast.heal)
dot: {"total": damage over the whole effect, "ticks": n, "duration": s}; unique_dot skips afflicted targets
stun (s) with stun_boss_factor (0.25): bosses are stunned for that share
buff: {"damage": 0.4, "duration": 11} raises all damage while it lasts; trigger_range: fire only with an enemy
that close (a buff with no trigger fires on cooldown)
Upgrades (rank_up, learn's bonus) add up: {"damage": +ratio, "cooldown": -ratio (0.23 = 23 % shorter),
"targets": +n}. Global modifiers: damage_mult (per-level growth, talents) and cooldown_mult.

Cast (Dictionary): {"spell": id, "hits": [{"id", "damage", "stun"}], "heal": float, "buff": {...} or {},
"dot": bool (a damage-over-time tick)}. Deterministic with the RNG passed to _init (used only by "random").
Adds a spell at rank 1 (or adds its bonus to a known one). `bonus`: the rarity bonus of the card that taught it.
A drafted upgrade for a known spell: one more rank and its bonus. False for an unknown spell.
Effective numbers of a spell after bonuses and global modifiers (for tooltips and tests).
Damage multiplier from active buffs (they stack additively).
Advances cooldowns, buffs and damage-over-time by `delta` seconds and returns what fired.
Forget timers, buffs and dots (a new run); spells and ranks stay unless `forget_spells`.

測試引用（存在不等於本輪已重跑）：tests/test_capability_composition.gd, tests/test_survivor_modules.gd

## camera_shake

2D trauma 震屏；打擊回饋與無障礙強度調整

適用：打擊回饋與無障礙強度調整

入口：[addons/proto_kit/camera_shake.gd](../../addons/proto_kit/camera_shake.gd) · rule · 來源靜態引用：erwin-run、survivor-series；不代表本輪已做遊戲／真人驗收

限制／副作用：每幀由宿主 step 一次；delta 為有限非負秒數，非法值不更新。震動期間獨占 Camera2D.offset/rotation，首次寫入前擷取非零基準；自然結束、reset()、shake_scale <= 0 或改綁鏡頭時還原。改綁保留剩餘 trauma。釋放此 RefCounted 或交還鏡頭控制權前必須 reset()；不支援同時寫入這兩欄的控制器。decay/frequency/scale 使用有限非負值，trauma/ceiling 為 0..1；沒有 RNG。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/camera_shake.gd")
var shake = Capability.new()
shake.camera = $Camera2D
shake.add_trauma(0.25)
# 每幀一次：shake.step(delta)
# 離場或交還鏡頭控制權：shake.reset()
# 立即停用並還原：shake.shake_scale = 0.0
```

### 參數、輸出與訊號

```gdscript
var camera: Camera2D
var shake_scale: float = 1.0
var decay: float = 1.5
var max_offset: Vector2 = Vector2(40.0, 30.0)
var max_roll: float = 0.02
var frequency: float = 8.0
var trauma: float = 0.0
func reset() -> void:
func add_trauma(amount: float, ceiling: float = 1.0) -> void:
func step(delta: float) -> void:
```

Camera shake by trauma. Every impact adds trauma (0..1), trauma drains at a fixed rate, and the camera moves by
trauma squared: small hits barely stir it, big ones punch, and a stream of small ones does not add up to a big one.
`const CameraShake = preload("res://addons/proto_kit/camera_shake.gd")`

var shake := CameraShake.new()
shake.camera = $Camera2D
func _process(delta): shake.step(delta)        # whoever owns the camera steps it once a frame
shake.add_trauma(0.25)                          # a small hit
shake.add_trauma(0.85)                          # a boss death
shake.add_trauma(0.25, 0.35)                    # never pushes trauma past 0.35, so a stream of crits rumbles instead of punching

It moves Camera2D.offset and Camera2D.rotation only, never a body or the camera's position, so aiming and
collisions are untouched. The motion is two sines at unrelated rates, not a random value per frame (that buzzes).
Rotation only shows with Camera2D.ignore_rotation off. The starting offset/rotation are restored on completion.
While shaking this object exclusively owns those two properties. Call reset() before handing them back.
The camera to shake. Nothing happens to the camera while this is null (trauma still drains).
Accessibility: scales how far the camera moves. 0 = the camera never shakes (trauma is not even collected).
Trauma lost per second. The shake itself is trauma squared, so it dies away faster than trauma does.
Camera offset (px) at full trauma, and the roll (rad) the camera turns at most.
How fast the shake wobbles (Hz). Much above 10 it turns into a buzz on a 30 or 60 fps screen.
0..1, added to by every shake and drained by `decay`. The camera shakes by trauma squared.
Stops the shake and restores the captured camera pose. Safe to call repeatedly or after the camera was freed.
Shakes add up, but one never pushes the trauma past its own `ceiling` (and never lowers it).
Does nothing while shake_scale is 0.
Once per frame, with the frame's delta.
Smooth, not random: two sines at unrelated rates. A fresh randf() every frame would buzz. Within -1..1.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## camera_shot

可存成 Resource 的鏡頭演出參數；策劃在 Inspector 調校

適用：策劃在 Inspector 調校

入口：[addons/proto_kit/camera_shot.gd](../../addons/proto_kit/camera_shot.gd) · resource · 來源靜態引用：hero-horde-idle；不代表本輪已做遊戲／真人驗收

限制／副作用：只保存鏡頭演出設定的 Resource，沒有執行行為。push_m 公尺、yaw/pitch/fov 角度、ease/hold/hit_stop 秒；hold<0 要宿主 release。priority 高者打斷低者，同值替換。export_range 是 inspector 提示，不代替程序輸入驗證；實際座標／時間／中斷行為以 ShotCamera 為準。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/camera_shot.gd")
var shot = Capability.new()
shot.push_m = 1.0
shot.hold = 0.3
# 製作期 ResourceSaver.save(shot, "res://camera/hit.tres")
```

### 參數、輸出與訊號

```gdscript
@export var push_m: float = 2.0
@export_range(-20.0, 20.0) var yaw_deg: float = 0.0
@export_range(-20.0, 20.0) var pitch_deg: float = 0.0
@export var fov_delta: float = 0.0
@export var ease_in: float = 0.3
@export var hold: float = 0.5
@export var ease_out: float = 0.5
@export var priority: int = 1
@export var hit_stop: float = 0.0
@export var trauma: float = 0.0
```

One short cinematic move of a fixed gameplay camera (shot_camera.gd): ease from the gameplay framing toward a
focus point, hold, ease back. Save each move as a .tres so it is tuned in the inspector. Projects that want a typed
name subclass it: `class_name CameraShot` + `extends "res://addons/proto_kit/camera_shot.gd"`.
Metres the camera dollies toward the focus point.
Orbit around the focus before the dolly: yaw turns around world up (+ = camera swings right), pitch raises (+) or
lowers (-) the camera. Keep yaw small: the field sprites are drawn facing one way and read as cards from the side.
Added to the camera's field of view (degrees; - = tighter).
Seconds held at the peak; < 0 holds until the director is released or reset (the win shot).
Higher interrupts lower; equal replaces.
Game-time freeze at the start of the shot (hit stop), seconds.
Screen shake added at the start, 0..1.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## card_draft

加權升級選卡、重抽與放逐；局內 roguelite 成長

適用：局內 roguelite 成長

入口：[addons/proto_kit/card_draft.gd](../../addons/proto_kit/card_draft.gd) · rule · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：建構時深複製卡片，借用專屬 RNG；offer/pick/reroll/banish 改內部狀態，from_dict 也改傳入 RNG.state。current 為公開可變 Array；pick 只驗證 current membership，不重新檢查資格。無放回抽選；reroll 優先避開舊選項，候選不足仍會回用。抽樣邊界 <=0，與 weighted_choice 不同。restore 有局部 clamp，但非完整 snapshot schema／槽位／先決條件驗證。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/card_draft.gd")
var rng = RandomNumberGenerator.new()
rng.seed = 42
var cards: Array[Dictionary] = [{"id": "power", "kind": "upgrade", "max_level": 3}]
var draft = Capability.new(cards, rng)
var offered: Array = draft.offer(3)
if not offered.is_empty():
    draft.pick(offered[0])
```

### 參數、輸出與訊號

```gdscript
var current: Array[String] = []
var rerolls_left: int
var banishes_left: int
func _init(pool: Array[Dictionary], rng: RandomNumberGenerator, options: Dictionary = {}) -> void:
func level(id: String) -> int:
func slots_used() -> int:
func branch_progress(branch: String) -> int:
func ultimate_ready(branch: String, need: int) -> bool:
func offer(count: int = 3) -> Array:
func pick(id: String) -> bool:
func reroll() -> bool:
func banish(id: String) -> bool:
func to_dict() -> Dictionary:
func from_dict(data: Dictionary) -> void:
```

Weighted upgrade drafts from {id, kind, weight, max_level, branch, requires} cards.
`const CardDraft = preload("res://addons/proto_kit/card_draft.gd")`
Ultimate cards do not occupy skill slots; ultimate_need defaults to 3.
from_dict restores the state of the caller-provided RNG; use a dedicated RNG.

測試引用（存在不等於本輪已重跑）：tests/test_capability_composition.gd, tests/test_genre_modules.gd

## chest_shop

遞增價格的局內寶箱；消費貨幣取得加權獎勵

適用：消費貨幣取得加權獎勵

入口：[addons/proto_kit/chest_shop.gd](../../addons/proto_kit/chest_shop.gd) · rule · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。 加權核心已改用 weighted_choice；有效分佈保留順序及一次 randf，無效分佈的防禦行為已調整，重構後測試暫緩。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/chest_shop.gd")
var rng = RandomNumberGenerator.new()
rng.seed = 42
var shop = Capability.new([{"id": "potion", "weight": 1}], rng, {"base": 20})
var result: Dictionary = shop.open(100)
# result.ok 才更新貨幣為 result.gold 並發放 result.reward
```

### 參數、輸出與訊號

```gdscript
var opened: int = 0
func _init(pool: Array[Dictionary], rng: RandomNumberGenerator, options: Dictionary = {}) -> void:
func price(n: int = -1) -> int:
func can_open(gold: int) -> bool:
func open(gold: int) -> Dictionary:
func reset() -> void:
func to_dict() -> Dictionary:
func from_dict(data: Dictionary) -> void:
```

In-run chests bought with gold: every opening costs more than the last, and each one gives a random reward from a
weighted pool. Gold never piles up uselessly, and the rising price caps how much it buys in one run.
`const ChestShop = preload("res://addons/proto_kit/chest_shop.gd")`

var chests := ChestShop.new([{"id": "potion", "weight": 5}, {"id": "tome", "weight": 1, "max": 2}], rng,
{"base": 20, "growth": 1.5})
hud.chest_label = str(chests.price())       # "20", then 30, 45, 68...
var r := chests.open(gold)                   # {"ok", "spent", "gold" (what is left), "reward" (pool entry)}
if r.ok: gold = r.gold; give(r.reward.id)
chests.reset()                               # a new run: price back to base, per-run limits cleared

Price of the n-th opening (n from 0): round(base x growth^n + step x n), capped at max_price when that is > 0.
Pool entry: {id, weight (1), max (openings per run that may give it; 0 = no limit)}. A failed open (not enough gold,
or nothing left to give) changes nothing.
What the next chest costs (or the n-th, counted from 0).

測試引用（存在不等於本輪已重跑）：tests/test_survivor_modules.gd

## combo_input

節拍連招與雙鍵和弦判定；輸入已正規化按鍵和秒數

適用：輸入已正規化按鍵和秒數

入口：[addons/proto_kit/combo_input.gd](../../addons/proto_kit/combo_input.gd) · rule · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/combo_input.gd")
var combos = Capability.new([{"id": "pair", "steps": ["A", "S"]}], {"beat": 0.45})
combos.add_gauge(1.0)
var events: Array = combos.press("A", 0.0)
# 每幀 combos.update(now_seconds)，不可混用毫秒
```

### 參數、輸出與訊號

```gdscript
var gauge: float = 0.0
func _init(combos: Array[Dictionary], options: Dictionary = {}) -> void:
func add_gauge(amount: float) -> void:
func is_ready() -> bool:
func running() -> bool:
func steps() -> Array[String]:
func candidates() -> Array[Dictionary]:
func press(key: String, now: float) -> Array[Dictionary]:
func update(now: float) -> Array[Dictionary]:
```

Rhythm combos on a few keys (Seal Online style A / S / D): attacking fills a combo gauge; once it is ready, a known
sequence of presses on the beat chains hits that land faster and harder; a wrong key or a missed beat breaks it.
Two keys pressed together (within `chord_window`) form a chord step such as "AD".
Pure logic: feed it presses with a clock in seconds; it does not read Input. `const ComboInput = preload("res://addons/proto_kit/combo_input.gd")`

var combos := ComboInput.new([
{"id": "triple", "steps": ["A", "S", "AS"]},
{"id": "five", "steps": ["A", "S", "A", "A", "AD"], "finish_bonus": 0.5},
], {"beat": 0.45, "window": 0.15})
combos.add_gauge(0.08)                         # on every normal hit
for e in combos.press("A", now): ...            # in _unhandled_input
for e in combos.update(now): ...                # every frame: commits chords, notices a missed beat

Events (Dictionary): {"type": "start" | "step" | "finish" | "break", "step": n (1-based), "combo": id or "",
"mult": damage multiplier for this hit, "speed": attack-speed multiplier}. A step names the combo only once one
candidate is left. "finish" comes with the last step of a combo no longer sequence could still extend, or one beat
after it when one could. Starting spends the whole gauge, so after a finish or a break it fills again from zero.

Options: beat (s between steps, 0.45), window (± s around the beat, 0.15), chord_window (s, 0.06), ready (gauge
needed to start, 0.5), step_mult (+damage per step, 0.1), speed (attack speed while comboing, 1.3), finish_bonus
(default extra damage on a finished combo, 0.3; a combo may set its own).
Steps committed so far (for a HUD that lights the keys).
Combos still possible from here: what to show as the next key hints.

測試引用（存在不等於本輪已重跑）：tests/test_mmo_modules.gd

## damage_numbers_3d

池化 3D 傷害數字；跨存活類遊戲的純視覺回饋

適用：大量命中且需限制 Label3D 數量；可變生命週期、顏色與縮放

入口：[addons/proto_kit/damage_numbers_3d.gd](../../addons/proto_kit/damage_numbers_3d.gd) · node · 本輪從三款原型抽取；尚未遷移既有遊戲，headless 證據見 VALIDATION

限制／副作用：只接受世界座標公尺；step 使用秒。固定容量在 ready 決定；專屬 RNG；不套用傷害。只有單一時間驅動者。GPU 外觀尚待真人驗收。

### 使用範例

```gdscript
var numbers = preload("res://addons/proto_kit/damage_numbers_3d.tscn").instantiate()
numbers.pool_size = 16
numbers.rng.seed = 42
add_child(numbers)
var accepted: bool = numbers.show_hit(Vector3.ZERO, 25.0, true)
# 每幀 numbers.step(delta)，或改 auto_step = true。
```

### 參數、輸出與訊號

```gdscript
@export var number_scene: PackedScene
@export_range(1, 256) var pool_size: int = 32
@export_range(0.01, 10.0) var life: float = 0.6
@export var rise: float = 1.4
@export var min_shown: float = 1.0
@export var jitter: float = 0.3
@export var height: float = 0.2
@export var normal_color: Color = Color.WHITE
@export var critical_color: Color = Color(1.0, 0.85, 0.3)
@export var critical_scale: float = 1.4
@export var auto_step: bool = false
var rng := RandomNumberGenerator.new()
func show_hit(world_position: Vector3, amount: float, critical: bool = false) -> bool:
func step(delta: float) -> void:
func clear() -> void:
func active_count() -> int:
```

Pooled cosmetic 3D numbers extracted from horde-25d, madara-survivor and luffy-marineford.
Instance damage_numbers_3d.tscn; tune number_scene and exports in the editor.
show_hit(world_position, amount, critical) -> accepted; never applies gameplay damage.
Local placement is derived from world_position, including a transformed pool parent.
Each pool owns its RNG. Set rng.seed for deterministic captures; never consumes global randf().
Manual step(seconds) by default; enable auto_step OR step from the game's clock, never both.
Capacity is fixed on _ready; changing pool_size later requires a new instance.
World metres; amount below min_shown, non-finite input or unavailable pool returns false.
Ring reuse: when full, the oldest issued slot is reused. No allocation on accepted hits.
Nonnegative game seconds. Invalid delta is ignored; completed labels are hidden, not freed.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## fixed_step

固定步長累積器；可選保留或丟棄追趕時間

適用：放置模擬保留積欠時間；即時戰鬥限制單幀工作量

入口：[addons/proto_kit/fixed_step.gd](../../addons/proto_kit/fixed_step.gd) · rule · 本輪依兩款原型抽取；既有遊戲尚未遷移

限制／副作用：輸入與輸出時間均為秒；configure 成功會 reset；invalid config/delta 不改狀態；呼叫端只在遊戲運行時 advance。drop 保留小數餘額，與 skybound 舊版清零不同。

### 使用範例

```gdscript
const FixedStep = preload("res://addons/proto_kit/fixed_step.gd")
var clock = FixedStep.new()
assert(clock.configure(0.05, 10, "retain") == OK)
# 在 _process(delta) 中：
# for i in clock.advance(delta):
#     simulation.step(clock.step_seconds())
var count: int = clock.advance(0.12) # 2；backlog_seconds 約 0.02
```

### 參數、輸出與訊號

```gdscript
func configure(seconds: float, max_steps: int = 10, backlog_policy: String = "retain") -> Error:
func advance(delta: float) -> int:
func step_seconds() -> float:
func backlog_seconds() -> float:
func dropped_seconds() -> float:
func alpha() -> float:
func reset() -> void:
```

Variable render delta -> bounded fixed simulation steps, without calling gameplay code.
Extracted from skybound-blades/domain/stepper.gd and dreamling-idle/scripts/simulation_driver.gd.
configure(seconds, max_steps, "retain"|"drop") returns Error; invalid settings leave state unchanged.
retain keeps unprocessed seconds for later frames (idle simulation); drop discards overdue whole
steps but keeps the fractional remainder (real-time combat). Neither reads a wall clock.
advance(delta_seconds) returns how many times the owner should call simulation.step(step_seconds()).
One owner, once per frame. No background catch-up unless the owner explicitly feeds that time.
Reconfiguration starts a new time domain and resets accumulated/dropped time.
Invalid/negative delta returns 0 without changing the accumulator, including existing backlog.
Render interpolation fraction; clamps to 1 when retained backlog is at least one full step.

測試引用（存在不等於本輪已重跑）：tests/test_capability_composition.gd

## floating_stick

浮動虛擬搖桿；觸控區輸出螢幕方向向量

適用：觸控區輸出螢幕方向向量

入口：[addons/proto_kit/floating_stick.gd](../../addons/proto_kit/floating_stick.gd) · node · 來源靜態引用：horde-25d、survivor-series；不代表本輪已做遊戲／真人驗收

限制／副作用：場景擁有生命週期；依下方契約準備子節點與資源。每幀只能由一個時鐘推進，不可重複 auto/manual step。

### 使用範例

```gdscript
# scene Control 掛此腳本；建立 %Base 與其下 %Knob
var direction: Vector2 = $Stick.vector
$Stick.release()
```

### 參數、輸出與訊號

```gdscript
@export var radius: float = 120.0
@export var knob_travel: float = 82.0
@export var dead_zone: float = 0.18
var vector: Vector2 = Vector2.ZERO
func release() -> void:
```

Floating virtual joystick: nothing is on screen until a finger presses anywhere in this area. The base then
appears under the finger, dragging steers, and letting go hides it again. Reads mouse events, so it works with
touch (Godot's emulate_mouse_from_touch, on by default), a desktop mouse, and test_kit's _drag.
`vector` is a screen vector: x right, y DOWN, length 0..1 (zero inside the dead zone). A 3D game that wants
"y forward" flips it: `Vector2(stick.vector.x, -stick.vector.y)`.

Put the script on a Control that fills the touch area and give it two children with unique names:
%Base   a Control (a round Panel): follows the finger's press position and is shown while held
%Knob   a Control inside it: moves with the finger, at most `knob_travel` px from the middle of %Base
and read `stick.vector` in the game's _physics_process. The scene leaves the base visible so the editor shows
how it looks; _ready hides it. The look (sizes, StyleBox, alpha) is authored in the game's scene, not here.
Call `release()` when the touch must end without a mouse-up (the game was paused under the finger).
Finger travel (px) that counts as full deflection.
How far the knob is drawn from the centre at full deflection; keep it inside the base.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## font_check

檢查字型涵蓋遊戲字元；Web 匯出與字型子集驗證

適用：Web 匯出與字型子集驗證

入口：[addons/proto_kit/font_check.gd](../../addons/proto_kit/font_check.gd) · inspection · 來源靜態引用：dreamling-idle、erwin-run、kagura-dango、luffy-marineford、seal-meadow、skybound-blades、survivor-series；不代表本輪已做遊戲／真人驗收

限制／副作用：來源文字檢查，不是字型渲染驗收。只收 code point>0x7E（排除 BOM），含註解與非玩家文字；不驗 ASCII、字形組合、動態下載文字。預設略過 addons/art_src/tests/tools/build/docs 等及隱藏目錄，不辨識 .gdignore；extensions 大小寫須符合。missing_report 回字元→第一個來源路徑；缺檔／目錄讀取失敗未形成獨立錯誤，空結果不保證掃描成功。傳入 Font 的 fallback 可能影響 has_char 結果；應使用實際隨遊戲交付的字型配置。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/font_check.gd")
var missing: String = Capability.missing_characters(load("res://ui/font.ttf"))
assert(missing.is_empty()) # font.ttf 由遊戲提供
```

### 參數、輸出與訊號

```gdscript
static func scanned_characters(root: String = "res://", extensions: PackedStringArray = EXTENSIONS, skip_dirs: PackedStringArray = SKIP_DIRS) -> Dictionary:
static func missing_report(font: Font, root: String = "res://", extensions: PackedStringArray = EXTENSIONS, skip_dirs: PackedStringArray = SKIP_DIRS) -> Dictionary:
static func missing_characters(font: Font, root: String = "res://", extensions: PackedStringArray = EXTENSIONS, skip_dirs: PackedStringArray = SKIP_DIRS) -> String:
```

Test helper: does the shipped font have a glyph for every character the game can write?

A trimmed font (tools/subset_font.py) drops what the game does not use. On a desktop the editor and the
player's system fonts hide a missing glyph, but a web build has no system font and shows a blank box.
This scans the game's own scripts, scenes, resources and data files, so a test can say so before a player does.

const FontCheck = preload("res://addons/proto_kit/font_check.gd")
var missing: String = FontCheck.missing_characters(load("res://ui/fonts/MyFont.ttf"))
_expect(missing.is_empty(), "the font has every character the game writes (missing: %s; run tools/subset_font.py)" % missing)

Keep the extensions and skipped folders in step with subset_font.py (same defaults). A project whose text
lives in a file type that is not listed passes `extensions` explicitly.
Folders that never ship text to the player (`publishing` = the store page's text and pictures). Hidden folders (".godot", ".git") are always skipped.
{character: path of the first file that writes it} for every non-ASCII character under `root`.
{character: path} for the characters `font` has no glyph for.
The missing characters as one string, sorted by code point ("" when the font covers everything).

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## gacha

獨立亂數流的加權抽取、保底與指定角色；召喚規則

適用：召喚規則

入口：[addons/proto_kit/gacha.gd](../../addons/proto_kit/gacha.gd) · rule · 來源靜態引用：hero-horde-idle；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有 pity、pool 與專屬 RNG；函式會消耗傳入 RNG，並非無副作用純函式。tier 使用整數 randi_range，保底不抽；不可替換浮點抽樣而聲稱存檔 RNG 序列不變。weights 須非空、非負整數且總和正；目前未完整驗證。featured>=0 時可直接回傳 featured，即使不在 pool 或 pool 為空；呼叫端須先確認 membership、share 0..1。未抽到 featured 且剩餘 pool 空時回 -1。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/gacha.gd")
var rng = RandomNumberGenerator.new()
rng.seed = 42
var tier: int = Capability.tier(rng, [55, 30, 12, 3], false)
var picked: int = Capability.pick(rng, PackedInt32Array([1, 2, 3]))
```

### 參數、輸出與訊號

```gdscript
static func tier(rng: RandomNumberGenerator, weights: Array, pity_reached: bool = false) -> int:
static func pick(rng: RandomNumberGenerator, pool: PackedInt32Array, featured: int = -1, share: float = 0.0) -> int:
```

Gacha rolls with pity (保底) and a featured (限時) pick, on a random stream the game owns:
`const Gacha = preload("res://addons/proto_kit/gacha.gd")`. Pure functions: the game keeps the pity counter,
the pools and the stream (saved with its progress, so a reload does not reroll), and the rates it shows on its
機率說明 page are the same array it passes here.

var tier := Gacha.tier(rng, RATES, pity >= PITY)       # RATES = [55, 30, 12, 3]: N, R, SR, SSR in percent
pity = 0 if tier == RATES.size() - 1 else pity + 1
var hero := Gacha.pick(rng, pools[tier], featured if tier == RATES.size() - 1 else -1, 0.5)

Use a RandomNumberGenerator of its own, never the global randf(): other systems drawing from the same stream
would shift every pull, and fixed-seed tests and balance runs would move with them.
Draw order per pull (keep it if you save rng.state): one randi_range for the tier (none when pity forces it),
then for a featured tier one randf, then one randi_range for the pick unless the featured unit was drawn.
A tier index for one pull: `weights` low to high (percents, or any whole-number weights); a forced pull
(`pity_reached`) is the top tier without drawing.
One unit from `pool`. With `featured` >= 0 it comes `share` of the time, and otherwise one of the others, so the
featured unit is exactly `share` of the tier (it is left out of the even draw). -1 when the pool is empty.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## game_clock

可暫停遊戲時鐘與背景恢復；遊戲規則共用時間來源

適用：遊戲規則共用時間來源

入口：[addons/proto_kit/game_clock.gd](../../addons/proto_kit/game_clock.gd) · node · 來源靜態引用：seal-meadow；不代表本輪已做遊戲／真人驗收

限制／副作用：場景擁有生命週期；依下方契約準備子節點與資源。每幀只能由一個時鐘推進，不可重複 auto/manual step。 修改 SceneTree.paused；與遊戲暫停管理共同設計，非多人伺服器時間。

### 使用範例

```gdscript
# scene 的 Node 掛此腳本
var now_seconds: float = $GameClock.now
var now_milliseconds: int = $GameClock.now_ms()
```

### 參數、輸出與訊號

```gdscript
@export var pause_in_background: bool = true
@export var resume_frames: int = 2
@export var max_delta: float = 0.1
var now: float = 0.0
var away: bool = false
signal backgrounded(away: bool)
func now_ms() -> int:
func set_away(value: bool) -> void:
```

Game time for gameplay rules. Pauses the tree while the app is in the background (tab hidden,
app switched away) and counts unpaused seconds, so rules never read the wall clock.
Add one node anywhere; it sets itself to PROCESS_MODE_ALWAYS. Timers made with
create_timer(t, false) and every pausable _process then stop while the app is away.

Coming back, the first frame's delta covers the whole time away; the tree stays paused for
`resume_frames` frames so that delta is spent while paused, not as one giant step.
Hand `now_ms` to modules that take an injectable clock (haptics.gd `clock`).
Upper bound on one frame of game time, so a hitch never jumps `now` far ahead.
Seconds of unpaused game time since this node entered the tree.
Also callable directly (tests, a web visibilitychange hook).

測試引用（存在不等於本輪已重跑）：tests/test_m0_modules.gd

## haptics

手機震動分級、節流與支援偵測；事件手感回饋

適用：事件手感回饋

入口：[addons/proto_kit/haptics.gd](../../addons/proto_kit/haptics.gd) · rule · 來源靜態引用：debt-commission、erwin-run、hero-horde-idle、kagura-dango、skybound-blades；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/haptics.gd")
var haptics = Capability.new()
haptics.enabled = true
haptics.buzz(0) # 不支援裝置安全略過
```

### 參數、輸出與訊號

```gdscript
var enabled: bool = true
var scale: float = 1.0
var min_gap_ms: int = 70
var max_per_second: int = 6
var durations_ms: PackedInt32Array = PackedInt32Array([14, 38, 90])
var amplitudes: PackedFloat64Array = PackedFloat64Array([0.35, 0.65, 1.0])
var clock: Callable:
signal vibrated(duration_ms: int, amplitude: float)
func now_ms() -> int:
func supported() -> bool:
func buzz(tier: int) -> void:
```

The phone's vibration motor, behind rules that keep a room full of events from turning into a hum.
`const Haptics = preload("res://addons/proto_kit/haptics.gd")`

A tier is an index into `durations_ms` and `amplitudes` (0 = the lightest buzz; three tiers by default).
var haptics := Haptics.new()
haptics.enabled = saved.haptics                 # the player's switch
haptics.buzz(0)                                 # a tick for a small event
haptics.buzz(2)                                 # a thump for a big one
haptics.vibrated.connect(func(ms: int, strength: float) -> void: print("buzz ", ms, " ms at ", strength))
if not haptics.supported():                     # no motor here: hide the settings switch (buzz() is harmless anyway)
switch_row.hide()
haptics.clock = func() -> int: return game_ms   # headless tests and bots: the rules follow game time, not the wall clock

Rules (all in buzz()):
1. `enabled` off, or `scale` 0: nothing at all.
2. Buzzes are `min_gap_ms` apart, and at most `max_per_second` in any one second.
3. A weaker buzz never cuts off a stronger one that is still running (a new buzz replaces the running
one on the phone).
A bigger tier than the last buzz passes rule 2 (a boss killed by a crit: small, then large in the same
frame; the large must not be swallowed).

Why the web check asks for a touch screen: navigator.vibrate exists on a desktop browser too (a function in
Chromium with no touch screen: measured with godot-kit/tools/web/web_probe.mjs), so asking only for the
function would make a desktop think it can buzz. iPhone Safari has no vibrate at all. Godot's web side logs a
warning on every call that cannot work, which is why supported() is checked before the motor is asked.
One buzz of the phone's motor went out (any device: it is sent when the rules let the buzz through,
whether or not this device has a motor).
The player's switch. Off = the phone never buzzes.
Scales how long every buzz runs. 0 = no buzzing at all.
Two buzzes are at least this many ms apart. A bigger tier than the last one cuts through (see buzz()).
At most this many buzzes in any one second, so a room full of kills does not hum. A bigger tier than the last one cuts through.
One buzz per tier: how long it runs (ms) and how hard (0..1; only Android uses the strength).
Under about 10 ms most phones feel nothing; over about 150 ms it is a hum, not a hit.
64-bit on purpose: a PackedFloat32Array hands 0.35 back as 0.3499999940395355, so `vibrated` would stop reporting what was set.
Milliseconds for the rules. Empty = the wall clock: the motor runs in real time, not in game
time. Tests and bots set one that follows game time; setting it forgets earlier buzzes.
Web: only a touch device whose browser has navigator.vibrate (see the top of this file).
Milliseconds on the clock the rules use: `clock` if one is set, else the wall clock.
Whether this device can buzz, asked once. Android and iOS: yes. Web: only a touch device whose browser has
navigator.vibrate (Android Chrome and Firefox). That is checked here because Godot's web side logs a
warning on every call that cannot work. Desktop: no.
One buzz at this tier, if the rules let it through. They are all here:
1. `enabled` off, or `scale` 0: nothing at all.
2. Buzzes are `min_gap_ms` apart, and at most `max_per_second` in any second.
3. A weaker buzz never cuts off a stronger one that is still running (a new buzz replaces the
running one on the phone).
A bigger buzz than the last one passes rule 2 (a boss killed by a crit: small, then large in the same
frame; the large must not be swallowed).
`vibrated` is sent for every buzz that passes, on any device; the motor is only asked on a device that has one.
ponytail: `tier` is not range-checked; one past the arrays is a script error, which says "the config is short" loudly enough.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## hd2d_demo

HD-2D 組合示範；製作期研究各元件接線

適用：製作期研究各元件接線

入口：[addons/proto_kit/hd2d_demo.gd](../../addons/proto_kit/hd2d_demo.gd) · authoring · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：組合示例／製作參考，build 回未入樹 Node，由呼叫端 add/free。程序建立整個 stage、HUD與佔位圖；不是已保存可直接維護的遊戲畫面。Runner 停用 MarchStrip 自動 process 再手動 step，但 shot camera 仍自行推進，並非所有動畫共享單一 deterministic clock。正式交付須製作並保存 scenes/resources，保留編輯器調整。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/hd2d_demo.gd")
var demo: Node = Capability.build(Vector2(720, 1280))    # add to the tree; demo.step(game_delta) each frame
```

### 參數、輸出與訊號

```gdscript
static func build(view: Vector2 = Vector2(720, 1280)) -> Node:
```

A tiny HD-2D diorama made of kit modules only, from placeholder art drawn in code: the reference for how the
pieces fit, and what tests/test_proto_kit.gd and tools/hd2d_gallery.gd build. A game builds the same tree in its
own authoring script and saves it as scenes (hero-horde-idle stage.tscn, march_view.tscn are full examples).
var demo: Node = Hd2dDemo.build(Vector2(720, 1280))    # add to the tree; demo.step(game_delta) each frame
Layer stack, back to front: WorldEnvironment (hd2d_look) and the sun -> ground plane -> pixel_card3d props and
characters (sprite3d for crowds) -> ground_decal marks and pixel_vfx3d rings under the characters -> chunks ->
the vignette CanvasLayer -> the HUD (here a march_strip along the bottom).
Steps the demo on game time and pops an effect now and then.
Adds `child` to `parent`, owned by `parent` (so %Name lookups from `parent` find it).

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## hd2d_gallery

HD-2D 擷取工具；比較鏡頭與渲染預設

適用：比較鏡頭與渲染預設

入口：[addons/proto_kit/hd2d_gallery.gd](../../addons/proto_kit/hd2d_gallery.gd) · inspection · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：SceneTree 截圖工具，依 Hd2dDemo 組合，用固定 dt step 與實際 process_frame 混合。需要 renderer／窗口；Screenshot.save 的空回傳未檢查，quit 不能單獨當產圖成功。輸出資料夾取第一 user arg，會寫 PNG；不應作 runtime 元件。

### 使用範例

```gdscript
godot --path prototypes/godot-kit --resolution 720x1280 --script res://addons/proto_kit/hd2d_gallery.gd -- <out dir>
```

### 參數、輸出與訊號

```gdscript
```

Look at the HD-2D kit without a game: builds hd2d_demo.gd's diorama (look presets, sun, ground, pixel_card3d
props and figures, a ground_decal warning, pixel_vfx3d rings and chunks, the shot camera, the vignette, a
march_strip along the bottom) and saves frames as it plays (one with a camera shot). Needs a window (the Mobile or
Forward+ renderer for the depth of field):
godot --path prototypes/godot-kit --resolution 720x1280 --script res://addons/proto_kit/hd2d_gallery.gd -- <out dir>

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## hd2d_look

HD-2D 環境、景深與暗角資源；製作期保存外觀預設

適用：製作期保存外觀預設

入口：[addons/proto_kit/hd2d_look.gd](../../addons/proto_kit/hd2d_look.gd) · authoring · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：製作期 Resource factory；回傳新 Environment／CameraAttributes／ShaderMaterial，呼叫端保存為 .tres 後調校。未知 property 只 push_error 並繼續，沒有全有或全無設定驗證；有效欄位的型別／範圍也需呼叫端確認。預設值是特定 dusk 美術配方，renderer 的景深／光效差異須按消費者驗收。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/hd2d_look.gd")
var environment: Environment = Capability.environment({"fog_depth_begin": 12.0})
# 製作期保存成 .tres，再指派給 WorldEnvironment
```

### 參數、輸出與訊號

```gdscript
static func environment(overrides: Dictionary = {}) -> Environment:
static func camera_attributes(overrides: Dictionary = {}) -> CameraAttributesPractical:
static func vignette_material(overrides: Dictionary = {}) -> ShaderMaterial:
```

The HD-2D look as resources: `const Hd2dLook = preload("res://addons/proto_kit/hd2d_look.gd")`. Call these from a
headless authoring script and save the results (materials/stage_environment.tres, ...) so they are tuned in the
editor afterwards; the defaults are hero-horde-idle's dusk stage, which the author approved.
environment()        background, cool ambient, linear tonemap (the pixel art keeps its painted palette; only
HDR highlights such as motes, flashes and fire bloom), screen glow, depth fog that greys the
far set, a slight lift in brightness, contrast and saturation
camera_attributes()  far depth of field: the near field stays sharp, the backdrop goes soft (the tilt-shift read)
vignette_material()  for a full-screen ColorRect between the 3D view and the HUD (hd2d_vignette.gdshader):
cool dark corners and a faint warm wash from the top
Overrides: environment({"fog_depth_begin": 12.0, "background_color": Color.BLACK}) sets any Environment property.
Depth of field needs the Forward+ or Mobile renderer; Compatibility skips it (the stage then looks sharper).
A ShaderMaterial of the vignette; `overrides` sets its uniforms (corner_color, strength, radius, softness,
sun_wash, sun_wash_strength).

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## hd2d_stage

場景燈光取樣與火光變化；像素角色融入 3D 環境

適用：像素角色融入 3D 環境

入口：[addons/proto_kit/hd2d_stage.gd](../../addons/proto_kit/hd2d_stage.gd) · node · 來源靜態引用：hero-horde-idle；不代表本輪已做遊戲／真人驗收

限制／副作用：saved stage scene 的行為；sprite_light(p) 接 world position，step_lights(dt) 接 game seconds，由宿主每幀推進一次。只在 ready 收集 OmniLight 與基準能量，假設清單生命周期穩定，不支援動態刪增或第二個系統寫 flicker energy。%FlickerLights 子節點須為 OmniLight3D；%Sun 可選。逐 sprite 掃每個 light，複雜度依 actor/light 數相乘，尚無實測效能承諾。

### 使用範例

```gdscript
# 場景根 Node3D 掛此腳本，%Sun 與 %FlickerLights 留在 scene
var tint: Color = $Stage.sprite_light(Vector3.ZERO)
$Stage.step_lights(0.016)
```

### 參數、輸出與訊號

```gdscript
@export var sprite_key := Color(0.97, 0.93, 0.86)
@export var sprite_light_gain: float = 0.45
@export var flicker_amount: float = 0.22
func set_region_light(color: Color) -> void:
func step_lights(dt: float) -> void:
func sprite_light(p: Vector3) -> Color:
```

The root of an HD-2D diorama (Octopath / RO style: pixel-art sprites and cards in a lit 3D set). Everything static
lives in the stage scene: WorldEnvironment (hd2d_look.gd presets), the sun, the floor, cliffs, pixel_card3d props,
omni lights, the vignette. This script does the two things a scene file cannot:
sprite_light(p)  the tint for a sprite standing at p. Character sprites are unshaded pixel art (a lit flat card
reads as cardboard), so the coloured lights around them are added to their tint instead: the
key colour plus every visible OmniLight3D reaching p (quadratic falloff), times the region light.
step_lights(dt)  flickers the lights under %FlickerLights (braziers, torches) on its own clock.
set_region_light(c) recolours the sun (%Sun) and the sprites together, for one stage reused across regions.
extends "res://addons/proto_kit/hd2d_stage.gd"       # the game adds its own event lights (warnings, flashes)
army.lighting = stage.sprite_light                   # sprite3d crowd: multiply each instance colour by it
Omni lights are collected once in _ready: add lights to the scene, not at runtime.
The sprites' base light: the warm key the pixel art is painted for.
How strongly an omni light's colour adds to a sprite standing in it (at the light's centre, energy 1).
Flicker depth of the %FlickerLights (0 = steady).
The region's light: multiplies the sun and the sprites' light.
The lights that flicker: the children of %FlickerLights (override to name another group).
The stage's region light; white is the light the stage is built for.
Advances the stage clock and flickers the flicker lights. Call it every frame with game time.
Tint multiplier for a sprite at world point `p`: the key plus every visible omni light reaching it.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## loot_ledger

首領掉落、區域解鎖與裝備收藏；永久收集成長

適用：永久收集成長

入口：[addons/proto_kit/loot_ledger.gd](../../addons/proto_kit/loot_ledger.gd) · rule · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/loot_ledger.gd")
var ledger = Capability.new([{ "id": "forest", "tier": 0, "bosses": [] }])
var stats: Dictionary = ledger.worn_stats()
```

### 參數、輸出與訊號

```gdscript
var unlocked: int = 1
func _init(zones: Array) -> void:
func zone_ids() -> Array[String]:
func is_unlocked(zone_id: String) -> bool:
func defeat_final(zone_id: String) -> String:
func roll_drop(zone_id: String, boss_id: String, rng: RandomNumberGenerator, luck: float = 0.0) -> Dictionary:
func collect(item_id: String) -> bool:
func owns(item_id: String) -> bool:
func wear(item_id: String) -> bool:
func worn() -> Dictionary:
func worn_stats() -> Dictionary:
func progress(tier: int = -1) -> Vector2i:
func wanted(limit: int = 5) -> Array[Dictionary]:
func to_dict() -> Dictionary:
func from_dict(data: Dictionary) -> void:
```

Boss drops and the permanent gear collection of a survivor-like: zones in order, each with timed bosses that each
drop one item at a chance; collected items stay forever, one per slot is worn and adds its stats. Beating a zone's
final boss opens the next zone. `const LootLedger = preload("res://addons/proto_kit/loot_ledger.gd")`

var ledger := LootLedger.new([
{"id": "forest", "tier": 0, "bosses": [
{"id": "hogger", "at": 180, "chance": 0.6, "item": {"id": "recruit_helm", "slot": "head", "stats": {"hp": 20}}},
{"id": "vancleef", "at": 960, "final": true, "chance": 0.6, "item": {...}}]},
{"id": "duskwood", "tier": 1, "bosses": [...]}])
var item := ledger.roll_drop("forest", "hogger", rng)   # {} on a miss or an item already owned
if not item.is_empty(): ledger.collect(item.id)         # the game may show it first; collect() equips if the slot is free
ledger.defeat_final("forest")                           # unlocks "duskwood"
ledger.worn_stats()                                     # {"hp": 20}
ledger.wanted(5)                                        # the next items to farm, nearest zone first

An item's tier is its zone's tier unless the item sets one. `luck` adds to the drop chance (0.05 = +5 points).
Opens the zone after this one (the final boss died). Returns the zone id it opened, or "".
The boss's item if the roll succeeds and it is not owned yet; {} otherwise (show gold instead, for example).
Adds an item to the collection for good; wears it when its slot is empty. False if unknown or already owned.
Owned / total, overall or for one tier.
Items still missing in unlocked zones, zone order then boss time: what the next runs should farm.

測試引用（存在不等於本輪已重跑）：tests/test_survivor_modules.gd

## march_strip

放置行軍展示；把收益規則留在遊戲端

適用：把收益規則留在遊戲端

入口：[addons/proto_kit/march_strip.gd](../../addons/proto_kit/march_strip.gd) · node · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：這是可見時自動推進的展示模擬，不是權威戰鬥／離線結算。手動 step 時需停用自動 process，否則雙重推進。必需 %Far/%Ground 材質、%Heroes/%Enemy/%EnemyHp 與至少一個 %Popups Label；ground_px/ground_scale/death_time 與傷害基數需正值。popup 與展示戰鬥共用此元件的專屬 RNG，多播 popup 會改變後續展示序列。fell/hit 不應作為離線獎勵權威來源。at 是 strip local pixels；移動是展示狀態，不回寫 scene。

### 使用範例

```gdscript
# 遊戲保存 march_view scene，具備檔頭列出的唯一名稱節點
# 子類覆寫 fell() 接收益；不要把展示擊殺當真實戰鬥事件
$March.popup("+10", Color.WHITE, Vector2(100, 100))
```

### 參數、輸出與訊號

```gdscript
@export var walk_speed: float = 70.0
@export var far_rate: float = 0.15
@export var prop_rate: float = 0.55
@export var ground_px: float = 96.0
@export var ground_scale: float = 2.0
@export var hits_to_kill: float = 9.0
@export var hit_every: float = 0.32
@export var death_time: float = 0.45
@export var spawn_gap := Vector2(1.2, 2.4)
@export var crit_chance: float = 0.15
@export var crit_mult: float = 2.0
@export var contact_px: float = 24.0
@export var damage_color := Color.WHITE
@export var crit_color := Color("ffe9a8")
@export var rng_seed: int = 11
var kills: int = 0
var walking: bool = true
signal enemy_spawned
signal hit(damage: float, crit: bool)
signal enemy_fell
func step(dt: float) -> void:
func fell() -> void:
func popup(text: String, color: Color, at: Vector2) -> void:
func enemy_rect() -> Rect2:
```

An idle side-scroller strip (Taskbar Hero style, the 行軍 view of an idle RPG): the party walks right through the
region (the far picture, the props and the ground scroll at their own rates), meets a monster, stops and fights it
on its own (damage numbers, the monster's HP bar), the monster falls and they walk on. It only shows the idle
loop: what the march pays is the game's business (fell() is where it says so). Its own random numbers
(rng_seed), so the game's randf() is never touched; it runs only while visible, and step(dt) drives it in tests.
extends "res://addons/proto_kit/march_strip.gd"     # the game's view: looks, damage, texts

Scene (unique names; march_view.tscn in hero-horde-idle is a full example):
%Far     TextureRect, parallax_layer.gdshader material (tex = the far picture, mirror on), full rect
%Props   Control of TextureRects (trees, rocks) that drift left at prop_rate and wrap around
%Ground  TextureRect, parallax_layer.gdshader material (tex = the ground strip)
%Heroes  Control of the party's TextureRects, front one rightmost; hidden ones do not count
%Enemy   TextureRect of the monster, positioned in the same band as the heroes
%EnemyHp ProgressBar over the monster
%Popups  Control holding a few Labels reused for damage and reward numbers
Hooks for the subclass (all optional): _damage_base() (the hit size; a kill takes hits_to_kill of them),
_show_frames() (animate the party: `walking`, `_t`), fell() (a monster fell: count it, pop the reward).
Pixels per second the world moves while the party walks; the far picture and the props move slower.
The ground layer's texture width in px and its on-screen scale: its offset advances one tile per that many px.
Seconds of walking between a monster falling and the next appearing (random in the range).
How close (px) the monster comes to the front hero before the fight starts.
Advances the strip by dt seconds.
The size of one hit before the random spread (0.8-1.3) and crits. Override with the party's strength.
Animate the party here (run frames while `walking`, attack frames otherwise; `_t` is the strip's clock).
A monster fell: count it, show what it paid (popup()). Called after the killing hit's number popped.
Shows `text` in `color` rising from `at` (strip coordinates), reusing the oldest popup label.
Where the monster's body is, for popups over it.
The far picture keeps its own proportions at the strip's height and repeats (mirrored) across its width.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## music

背景音樂交叉淡入淡出；場景切換與暫停仍保持播放

適用：場景切換與暫停仍保持播放

入口：[addons/proto_kit/music.gd](../../addons/proto_kit/music.gd) · node · 來源靜態引用：erwin-run、survivor-series；不代表本輪已做遊戲／真人驗收

限制／副作用：scene Node 完成 _ready() 後才呼叫 play；至少兩個 AudioStreamPlayer（缺少時補建）。要在暫停時播放，宿主需設定 process_mode = ALWAYS；淡出入忽略 Engine.time_scale。OggVorbis/MP3/WAV 在私有副本啟用循環，不改傳入資源；其他 AudioStream 類型原樣使用，循環由呼叫者配置。track 保留傳入資源身分，同一資源再次 play 不重播。快速第三次換軌會重用最安靜 voice，可能截斷尚未淡完的曲目。

### 使用範例

```gdscript
# scene Node 掛此腳本；track.ogg 由遊戲提供
$Music.play(load("res://audio/track.ogg"))
$Music.stop()
```

### 參數、輸出與訊號

```gdscript
@export_range(-60.0, 0.0, 0.5) var volume_db: float = -12.0
@export_range(0.05, 5.0, 0.05) var fade_time: float = 0.8
var track: AudioStream
func play(new_track: AudioStream) -> void:
func stop() -> void:
```

Background music with crossfades: `play(track)` fades the old track out while the new one fades in,
`stop()` fades to silence. `const Music = preload("res://addons/proto_kit/music.gd")`, or put the script on a
Node of the game scene and call:

music.play(room_theme)       # a different track: the old one fades out, this one fades in, looped
music.play(room_theme)       # the same track again: nothing happens (walking from room to room keeps it)
music.stop()                 # fades to silence

The node uses the AudioStreamPlayer children it finds (two is enough: one fading out, one fading in) and adds
the missing ones itself. It runs while the game is paused (set process_mode ALWAYS on the node), and its fades
ignore Engine.time_scale, so a hit stop does not stretch them. A track imported without looping would end and
leave silence, so looping is enabled on a private stream copy. The caller's resource stays unchanged.
A game that needs named tracks (a room theme and a boss theme) extends this script and adds the exports:

extends "res://addons/proto_kit/music.gd"
@export var room_track: AudioStream
@export var boss_track: AudioStream
Volume of a track at full level. Keep it well below the sound effects.
Seconds the old track takes to fade out and the new one to fade in.
What is meant to be playing now (null = silence).
Starts `new_track`, looped, and fades whatever else plays out. Asking for the track that is already
playing changes nothing, so walking from room to room does not restart the music.
A player that is silent, else the quietest one (a third track in quick succession cuts the fading one).
Copy the supported stream before changing loop properties; keep track as the caller's identity for deduplication.
Other stream types pass through unchanged; their loop policy belongs to the caller.
Level 1 = `volume_db`, 0 = silent. Linear in amplitude, like a fade in an audio editor.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## nine_slice

PNG 九宮格 Theme 製作；保留既有主題其他設定

適用：保留既有主題其他設定

入口：[addons/proto_kit/nine_slice.gd](../../addons/proto_kit/nine_slice.gd) · authoring · 來源靜態引用：hero-horde-idle；不代表本輪已做遊戲／真人驗收

限制／副作用：製作期工具：box 回新 StyleBoxTexture；button_states 原地修改傳入 Theme 指定五個 states，呼叫端負責保存。slice 與 pad/sink 單位為像素，pad 順序 left/top/right/bottom；normal 缺失回 false 且不修改，其他 state 缺失退回 normal。pattern 須含可用的 %s；slice、texture size、sink 不造成負 margin 的條件需先驗證。只用既有 PNG，不產生或重畫美術。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/nine_slice.gd")
var texture: Texture2D = load("res://ui/frame.png") # 遊戲素材
var style: StyleBoxTexture = Capability.box(texture, 16, Vector4(20, 12, 20, 12))
```

### 參數、輸出與訊號

```gdscript
static func box(texture: Texture2D, slice: int, pad: Vector4, sink: float = 0.0) -> StyleBoxTexture:
static func button_states(theme: Theme, type: StringName, pattern: String, slice: int, pad: Vector4, sink: float = 2.0) -> bool:
static func frame(path: String) -> Texture2D:
```

9-slice frames from PNGs into a Theme: `const NineSlice = preload("res://addons/proto_kit/nine_slice.gd")`.
A frame image keeps its corners and edges `slice` px wide and stretches the middle, so one small PNG frames a
button or a dialog of any size (pixel art stays crisp with the project's nearest texture filter).

var theme: Theme = load("res://ui/theme.tres")
NineSlice.button_states(theme, &"Button", "res://ui/frame/button%s.png", 14, Vector4(20, 8, 20, 8))
theme.set_type_variation(&"Dialog", &"PanelContainer")
theme.set_stylebox(&"panel", &"Dialog", NineSlice.box(load("res://ui/frame/dialog.png"), 24, Vector4(34, 26, 34, 30)))
ResourceSaver.save(theme, "res://ui/theme.tres")

Run it from a headless tool script that loads the theme and sets only these entries, so the rest of the theme
(tuned in the editor) stays.
Button states and the file suffix each reads: hover_pressed shares the pressed frame.
A StyleBoxTexture of `texture` with `slice` px fixed at each edge. `pad` = content margins (left, top, right,
bottom); `sink` moves the content down that many px (a pressed button).
Sets the five button styleboxes of theme type `type` from `pattern` % suffix (STATES): pattern
"res://ui/frame/primary%s.png" reads primary.png, primary_hover.png, primary_pressed.png, primary_disabled.png.
A missing state file falls back to the normal frame. Pressed states sink the content by `sink` px.
Returns false (and sets nothing) when the normal frame is missing.
The texture at `path`: the imported resource, else a PNG read straight from the file (user://, or before the
first import); null when there is neither.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## orientation_guard

手機方向遮罩；阻擋錯誤方向下的點擊

適用：阻擋錯誤方向下的點擊

入口：[addons/proto_kit/orientation_guard.gd](../../addons/proto_kit/orientation_guard.gd) · node · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：場景擁有生命週期；依下方契約準備子節點與資源。每幀只能由一個時鐘推進，不可重複 auto/manual step。

### 使用範例

```gdscript
var guard = preload("res://addons/proto_kit/orientation_guard.tscn").instantiate()
add_child(guard)
```

### 參數、輸出與訊號

```gdscript
@export var want_landscape := true
@export_multiline var message := "請把手機轉成橫向\n才能遊玩"
@export var touch_only := true
static func is_touch_device() -> bool:
func wrong_way(size: Vector2) -> bool:
```

Covers the game and asks the player to rotate when a phone is held the wrong way (the game is laid out for one
orientation). Blocks input while shown. Touch devices only by default: desktop windows of any shape are left alone.
Instance orientation_guard.tscn at the root of the main scene; set `message` / `want_landscape` there.
Does not pause the game: a running round keeps going behind the cover.
Extracted from kagura-dango (2026-11-04).
false: also cover on desktop when the window has the wrong shape.
True when a viewport of this size has the wrong orientation.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## pet_care

寵物飢餓、餵食與進化；城鎮與野外養成

適用：城鎮與野外養成

入口：[addons/proto_kit/pet_care.gd](../../addons/proto_kit/pet_care.gd) · rule · 來源靜態引用：seal-meadow；不代表本輪已做遊戲／真人驗收

限制／副作用：這是 Seal 風格養成規則，含固定 egg group／XP 表，不是通用離線寵物引擎。tick(delta seconds,in_town) 每次至多結算一次飢餓，超大 delta 不補完多輪；feed/play 本身不檢查 town。foods/types 借用設定容器；RNG 由宿主持有並另存，to_dict 未保存 RNG 與完整設定。feed/evolve 不扣背包材料；recipe 以 membership 而非數量匹配，宿主須驗證與提交交易。evolve 的 false 可能已將 XP 歸零；from_dict 不做完整合法性驗證。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/pet_care.gd")
var rng = RandomNumberGenerator.new()
rng.seed = 42
var pet = Capability.new({"egg": "seed", "foods": ["apple"]}, rng)
var events: Array = pet.tick(1.0, false)
var result: Dictionary = pet.feed({"id": "apple", "price": 45})
```

### 參數、輸出與訊號

```gdscript
var egg: String
var stage: int = 1
var level: int = 0
var xp: int = 0
var hunger: float = 1.0
var type: String = ""
var rare: bool = false
var alive: bool = true
var wants: String = ""
func _init(options: Dictionary, rng: RandomNumberGenerator) -> void:
func xp_to_next() -> int:
func is_hungry() -> bool:
func tick(delta: float, in_town: bool = false) -> Array[Dictionary]:
static func food_xp(item: Dictionary) -> int:
func feed(item: Dictionary) -> Dictionary:
func play() -> void:
func reequip() -> void:
func can_evolve() -> bool:
func evolve(materials: Array, recipes: Array) -> Dictionary:
func stats() -> Dictionary:
func to_dict() -> Dictionary:
func from_dict(data: Dictionary) -> void:
```

A companion pet you keep alive and raise (Seal Online style): its hunger drains while you are out in the field,
it asks for a food it wants, feeding gives XP by the item's worth (more for the wanted food), it climbs levels
+0..+9 inside a stage, and at +9 with full XP it can try to evolve with materials into a type that sets its stats.
Starving costs XP and refills the bar; starving with under 2 % XP left, the pet runs away (unless the game passes
"can_run_away": false, which keeps it with the XP loss only).
`const PetCare = preload("res://addons/proto_kit/pet_care.gd")`

var pet := PetCare.new({"egg": "seed", "foods": ["apple", "fish", "bread"]}, rng)
for e in pet.tick(delta, in_town): ...       # "hungry" (with e.wants), "starved", "ran_away"
pet.feed({"id": "apple", "price": 45})        # -> {"xp", "level_up", "wanted"}
pet.feed({"id": "dusk_shield", "price": 5000, "kind": "equipment"})
if pet.can_evolve(): pet.evolve(["herb", "feather"], recipes)   # -> {"ok", "type", "rare"}
pet.stats()                                   # the type's stats x stage

XP needs (Seal Online's pet table): each stage uses a group whose first level costs base (30, 60, 120 ... doubling
through group G, then 5000, 5200, 8200); every level after costs 10 % of base more. Spare XP does not roll over.
Feeding XP from the sell price: < 15 → 1; < 80 → price / 15 + 1; else price / 20 + 2; equipment price / 1500 + 3.
Group index per stage (1..7) for each egg kind.
options: egg, foods (what it may ask for), drain (hunger lost per second, 1 / 600), hungry_below (0.66),
feed_refill (0.35), play_refill (0.08), wanted_mult (XP x for the wanted food, 2.0), starve_xp (share of the level's
need lost when hunger hits zero, 0.2), max_stage (7), types ({type: {stat: per stage}}).
XP needed from the current level to the next (at +9: to reach 100 % and be ready to evolve).
Hunger only drains in the field (towns pause the pet: no hunger, no growth, no death).
Playing keeps hunger up a little and gives no XP.
Unequipping and equipping again loses the XP of the current level (the level stays).
recipes: [{"materials": [...], "chance": 0.8, "types": {type: weight}, "rare": 0.05}]. The first recipe whose
materials are all given is used; with none, a poor fallback (chance 0.2, the type stays). On failure the pet keeps
its stage and must fill its XP again.
The type's per-stage stats x stage (x1.5 when rare).

測試引用（存在不等於本輪已重跑）：tests/test_mmo_modules.gd

## pixel_card3d

可編輯像素圖卡；HD-2D 道具、樹木與建築立片

適用：HD-2D 道具、樹木與建築立片

入口：[addons/proto_kit/pixel_card3d.gd](../../addons/proto_kit/pixel_card3d.gd) · node · 來源靜態引用：hero-horde-idle；不代表本輪已做遊戲／真人驗收

限制／副作用：單張靜態道具卡；m_per_px 世界公尺／像素，lean_deg 角度。export setter 與 ready 會重建 mesh/material，並覆寫 rotation.x、cast_shadow；手改這些產生資源會在重建時丟失。保留為明確的參數化 authoring component；若要自由編輯材質，需先 bake 成獨立 scene/resource。每張自行渲染，不作群體 actor 池；texture=null 清 mesh。

### 使用範例

```gdscript
# MeshInstance3D 掛此 @tool 腳本，Inspector 設 texture
$Prop.tint = Color.WHITE
var metres: Vector2 = $Prop.card_size()
```

### 參數、輸出與訊號

```gdscript
@export var m_per_px: float = 0.025:
@export var texture: Texture2D:
@export var tint := Color(1.0, 1.0, 1.0):
@export_range(0.0, 40.0) var lean_deg: float = 14.0:
@export var flip: bool = false:
func card_size() -> Vector2:
```

A pixel-art card standing on the ground of an HD-2D diorama: trees, rocks, pillars, gates, banners. Sized from its
texture at the stage's pixel density (m_per_px: the same for every card, sprite and ground texel, so all art shares
one pixel grid), leaned back toward a fixed camera so art drawn from ~45° above is not squashed, and casting a real
shadow from the sun with the art's outline (alpha scissor). Unshaded: the art is painted lit; `tint` grades it
into the scene's light. The node's origin is the base of the art (it stands on y = 0).
extends "res://addons/proto_kit/pixel_card3d.gd"    # scripts/prop.gd, scenes/prop.tscn; repeat @tool in it
Place instances under the stage scene and set texture / tint / flip in the inspector; it rebuilds in the editor.
For a crowd of moving characters use sprite3d (MultiMesh) instead: one card is one draw call.
Metres per art pixel. Keep one value per game (stage art, props, sprite cells).
Tilt back toward the camera (degrees), so art drawn from ~45° above is not squashed by the view.
Size of the card in metres (texture size x m_per_px); zero without a texture.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## pixel_vfx

2D 像素打擊特效；形狀、粒子與 shader 擴充

適用：形狀、粒子與 shader 擴充

入口：[addons/proto_kit/pixel_vfx.gd](../../addons/proto_kit/pixel_vfx.gd) · node · 來源靜態引用：erwin-run、survivor-series；不代表本輪已做遊戲／真人驗收

限制／副作用：Node2D 自動 _process；粒子／shape 以本地 draw 座標，effect() 卻把 at 設成 shader child.global_position；轉換根節點時不可假設一致。pixel>0、life>0、palette至少5色；部分容量拒絕可由 stats 查詢。tones 快取後改 palettes 不會自動失效，回傳容器亦非唯讀。shader children 自行 process，停 parent process 不代表停子特效；clear queue_free shader children，未重設 RNG。draw Callable 只可在繪製期間用 cell。

### 使用範例

```gdscript
# Node2D 掛此腳本
$Effects.burst(Vector2.ZERO, &"hit", 8)
$Effects.clear()
```

### 參數、輸出與訊號

```gdscript
@export var pixel: float = 2.0
@export var max_particles: int = 500
@export var max_shapes: int = 80
@export var max_shader_effects: int = 12
@export var ground_z_index: int = -1
@export var caption_interval: float = 0.45
@export var font: Font
@export var font_size: int = 11
@export var palettes: Dictionary = {
@export var fallback_palette: StringName = &"hit"
@export var shaders: Dictionary = {
var rng := RandomNumberGenerator.new()
var ground_layer: GroundLayer
func _init() -> void:
func clear() -> void:
func count() -> int:
func stats() -> Dictionary:
func tones(palette: StringName) -> Array:
func burst(at: Vector2, palette: StringName, amount: int = 8, speed: float = 55.0) -> void:
func spark(at: Vector2, direction: Vector2, palette: StringName, amount: int = 4) -> void:
func trail(at: Vector2, palette: StringName, kind: StringName) -> void:
func particle(at: Vector2, velocity: Vector2, color: Color, life: float, cells: int = 1, gravity: float = 0.0) -> void:
func ring(at: Vector2, from_radius: float, to_radius: float, palette: StringName, life: float = 0.3, thick: int = 1) -> void:
func slash(at: Vector2, angle: float, radius: float, arc: float, palette: StringName, heavy: bool = false) -> void:
func star(at: Vector2, palette: StringName, big: bool = false) -> void:
func pop(at: Vector2, palette: StringName, radius: float, life: float = 0.14) -> void:
func caption(at: Vector2, text: String, palette: StringName, life: float = 0.45) -> void:
func add_shape(kind: StringName, at: Vector2, palette: StringName, life: float, extra: Dictionary = {}) -> void:
func register(kind: StringName, draw: Callable) -> void:
func effect(name: StringName, at: Vector2, size: Vector2, life: float, palette: StringName, params: Dictionary = {}, pivot := Vector2(0.5, 0.5)) -> Node2D:
func count_effects() -> int:
func snap(at: Vector2) -> Vector2:
static func fade(left: float) -> float:
func cell(at: Vector2, color: Color, cells: int = 1, canvas: Node2D = null) -> void:
```

Pixel-art hit effects in one node, after PokéSurvivor: everything sits on one art-pixel grid (`pixel` world px
per art pixel), positions snap to it, angles snap to 22.5°, and fades step 1 → 0.66 → 0.33 instead of sliding.
Palettes are five tones: outline, dark, mid, light, white.

Two kinds of effect:
- Shapes, drawn by this node and its ground layer: square particles (burst, spark, trail) and shape entries (ring, slash,
star, pop, caption). Add your own with register(kind, draw) + add_shape(kind, ...).
- Shader effects: one child node per effect running a canvas shader from `shaders` (explosion, smoke, gas), with
`progress` driven 0 → 1 over its life. Add your own by putting a shader in `shaders`; see pixel_vfx.gdshaderinc.

Cosmetic randomness uses its own generator, so spawning effects never moves the game's global randf().
Put it above the actors (z_index) and call clear() when a run resets.
World px per art pixel (for a camera zoom z showing art at 2 screen px: 2 / z).
Absolute canvas layer for ground rings, below actors at z=0.
Caption font, drawn at 11 px so one font pixel is one art pixel; null uses the default theme font.
name: [outline, dark, mid, light, white] as colour strings. Unknown names fall back to `fallback_palette`.
Shader effects by name. Each shader includes pixel_vfx.gdshaderinc.
A running shader effect: draws one rect that its shader fills; progress goes 0 → 1 over `life` seconds.
Live particles, shapes and shader effects.
Renderer counts and rejected cosmetic requests, for telemetry and capacity tuning.
The five colours of `palette`.
Square particles flying out in every direction; `speed` in art px per second.
A few quick sparks thrown along `direction`, for ordinary hits.
Call every frame along a flying shot: "ember" rises, "drip" falls, anything else scatters.
One square particle (`cells` art pixels wide) with drag and optional gravity (world px/s²).
An expanding ring of grid squares, squashed to lie on the ground; `thick` 2 adds an inner row.
A directional swing. Collision code emits impact stars only when something is hit.
An eight-ray impact star; its second frame is wider and turned.
A solid flash that shrinks fast: white core, light and mid rings. `radius` in world px.
A pixel-font word that pops and rises ("BAM!").
A shape of a registered kind: drawn every frame by its draw callable until `life` runs out.
New shape kind: `draw` is called as draw.call(entry, left) inside this node's _draw, where `left` runs 1 → 0;
use cell(), snap() and fade() to stay on the grid. entry holds at, pal, life, t and add_shape's extra keys.
Plays shader effect `name` (a key of `shaders`) in a `size` rect at `at` for `life` seconds, coloured from
`palette`. `pivot` places the node in the rect; `params` sets extra shader uniforms. Returns the node, or null
when the cap is reached or the name is unknown.
`at` moved onto the art-pixel grid.
Stepped fade for `left` (1 → 0): 1, 0.66 or 0.33.
One square of `cells` art pixels at `at` (snapped). Only valid inside a draw callable.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## pixel_vfx3d

3D 像素碎片與地面波紋；立體打擊回饋

適用：立體打擊回饋

入口：[addons/proto_kit/pixel_vfx3d.gd](../../addons/proto_kit/pixel_vfx3d.gd) · node · 來源靜態引用：hero-horde-idle；不代表本輪已做遊戲／真人驗收

限制／副作用：必須 ready 後使用，%Chunks MultiMesh 及非空 %Rings、max_chunks>=1；palette至少5色，m_per_px/duration/drop seconds需正值。ring 設 global_position 並固定 world y=0.03；chunks 直接用輸入位置作 MultiMesh local transform，碰地y=0.02，非任意世界地形。前兩次 step 為預熱直接 return；clear 不重設 RNG 或重新啟動預熱。容量滿靜默略過，不是效果完整播放保證；共享 MultiMesh 必須由 scene 隔離。

### 使用範例

```gdscript
# Node3D 掛此腳本；由宿主每幀 step(delta)
$Effects.burst(Vector3.ZERO, 12, &"gold")
```

### 參數、輸出與訊號

```gdscript
@export var m_per_px: float = 0.025
@export var gravity: float = 14.0
@export var max_chunks: int = 320
@export var rng_seed: int = 7
var palettes: Dictionary = {
var rng := RandomNumberGenerator.new()
func clear() -> void:
func ring(at: Vector3, radius: float, palette: StringName, duration: float = 0.45) -> void:
func burst(at: Vector3, count: int, palette: StringName, speed: float = 3.0, up: float = 3.5, size_px: int = 3, life: float = 0.7) -> void:
func drop(at: Vector3, count: int, palette: StringName, seconds: float, height: float = 7.0, spread: float = 1.0, size_px: int = 6) -> void:
func sweep(from: Vector3, to: Vector3, count: int, palette: StringName, push: Vector3, size_px: int = 3) -> void:
func step(dt: float) -> void:
```

Pixel hit effects on the ground of an HD-2D diorama, on the pixel-vfx rules (pixel_vfx.gd and skill pixel-vfx: one
pixel grid, hard edges, 5-colour palettes, its own random numbers so the game's randf() and balance runs are not
touched). The 3D counterpart of pixel_vfx.gd:
ring()   a shockwave on the ground (a pool of quads under %Rings with pixel_vfx3d_ring.gdshader)
drop()   chunks falling from the sky onto a spot, timed to land after `seconds`
sweep()  chunks flung sideways along a line
burst()  pixel chunks thrown out with gravity and one bounce: rocks, dust, sparks, armour shards (%Chunks, one
MultiMesh). A chunk's life ends in three steps (shrinks 100 -> 66 -> 33%), never a soft fade.
The node needs two children (scene unique names): %Chunks, a MultiMeshInstance3D whose MultiMesh uses colours and a
small box mesh with an unshaded vertex-colour material; %Rings, a Node3D holding a few MeshInstance3D quads (1 x 1
PlaneMesh) sharing one ShaderMaterial of pixel_vfx3d_ring.gdshader. Call step(game_delta) every frame (game time,
so hit stop and pause freeze the effects) and clear() when a round restarts.
fx.burst(at, 30, &"rock", 4.5, 4.0, 4)       fx.ring(boss.global_position, 3.4, &"cyan", 0.5)
Metres per art pixel: chunk sizes and ring cells are counted in the game's pixels.
Downward pull on chunks, m/s².
Palettes by name, [outline, dark, mid, light, white]. Replace or add the game's own in _ready (before super()) or
from outside; these six are the defaults.
Frames left of the warm-up: one ring and one chunk drawn out of sight at start, so their shaders compile before the
first real hit instead of hitching on it.
A shockwave on the ground at `at`, `radius` metres at its widest. Skipped when every ring is busy.
`count` chunks from `at`: thrown out at up to `speed` m/s sideways and `up` m/s upward, `size_px` texels big.
`count` chunks falling from `height` m onto a disc of `spread` m around `at`, all landing after `seconds`.
`count` chunks along the line `from` -> `to`, flung toward `push` (m/s) and up a little.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## rarity

稀有度權重與加成；與選卡、技能升級組合

適用：與選卡、技能升級組合

入口：[addons/proto_kit/rarity.gd](../../addons/proto_kit/rarity.gd) · rule · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。 加權核心已改用 weighted_choice；有效分佈保留順序及一次 randf，無效分佈的防禦行為已調整，重構後測試暫緩。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/rarity.gd")
var rng = RandomNumberGenerator.new()
rng.seed = 42
var rarity = Capability.new()
var tier: int = rarity.roll(rng, 0.05)
var bonus: Dictionary = rarity.bonus(tier, "new")
```

### 參數、輸出與訊號

```gdscript
var tiers: Array[Dictionary]
func _init(custom: Array[Dictionary] = []) -> void:
func count() -> int:
func weights(luck: float = 0.0) -> Array[float]:
func roll(rng: RandomNumberGenerator, luck: float = 0.0) -> int:
func bonus(tier: int, kind: String = "new", rng: RandomNumberGenerator = null) -> Dictionary:
func roll_offer(ids: Array, rng: RandomNumberGenerator, luck: float = 0.0) -> Array[Dictionary]:
```

Card rarity for upgrade drafts: roll a tier per offered card, and turn the tier into the card's bonus, so the same
spell is worth more when it comes in a rarer color. Pairs with card_draft.gd (which card) and auto_caster.gd (what
the bonus does). `const Rarity = preload("res://addons/proto_kit/rarity.gd")`

var tiers := Rarity.new()                         # five default tiers, or Rarity.new(my_tiers)
var tier := tiers.roll(rng, luck)                  # 0 common .. 4 legendary; luck 0.05 = a "keen eye" perk
book.learn(spell, tiers.bonus(tier, "new"))        # {"damage": 0.34} for an epic new spell
book.rank_up(id, tiers.bonus(tier, "upgrade", rng))  # damage, or cooldown, or extra targets at high tiers

Tier fields: id, name, color, weight (draw weight), damage (bonus ratio), cooldown (reduction ratio), targets (+n,
offered on upgrades from that tier up). Luck moves weight from the lowest tier to the higher ones in proportion.
Draw weights after luck: `luck` (0..1) of the lowest tier's weight is spread over the higher tiers by their weight.
Returns -1 for invalid/all-zero weight distributions, without consuming RNG.
The bonus a card of this tier gives. "new": damage only (a fresh spell). "upgrade": one of damage, cooldown or
(when the tier offers targets) extra targets, picked with `rng`; without an rng, damage.
Rolls one tier for every offered card id: [{"id", "tier"}]. The draft decides which cards; this decides how good.

測試引用（存在不等於本輪已重跑）：tests/test_capability_composition.gd, tests/test_survivor_modules.gd

## refine_ladder

裝備精煉、失敗結果與成本估算；強化系統

適用：強化系統

入口：[addons/proto_kit/refine_ladder.gd](../../addons/proto_kit/refine_ladder.gd) · rule · 來源靜態引用：seal-meadow；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。 加權核心已改用 weighted_choice；有效分佈保留順序及一次 randf，無效分佈的防禦行為已調整，重構後測試暫緩。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/refine_ladder.gd")
var rng = RandomNumberGenerator.new()
rng.seed = 42
var ladder = Capability.new()
var result: Dictionary = ladder.attempt(4, rng)
```

### 參數、輸出與訊號

```gdscript
var steps: Array[Dictionary]
func _init(custom: Array[Dictionary] = []) -> void:
func max_level() -> int:
func step(level: int) -> Dictionary:
func chance(level: int, bonus: float = 0.0) -> float:
func attempt(level: int, rng: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
func expected_stones(from: int, to: int, rng: RandomNumberGenerator, runs: int = 2000, options: Dictionary = {}) -> Dictionary:
```

Equipment refining (+0 .. +12) as a ladder of gambles: each step names the stone it needs, a success chance and
what a failure does (keep the level and lose only the stone, fall back to a level, or destroy the item). Support
items raise the chance; protection items swap a harsh failure for a fall to a safe level.
`const RefineLadder = preload("res://addons/proto_kit/refine_ladder.gd")`

var ladder := RefineLadder.new()                      # Seal Online-like default, or RefineLadder.new(my_steps)
ladder.step(4)                                         # {"stone": "ruby", "chance": 0.6, "fail": {...}}
var r := ladder.attempt(4, rng, {"bonus": 0.05, "protect": {"floor": 7, "chance": 0.7}})
# r: {"ok", "level" (after), "destroyed", "stone"}
ladder.expected_stones(0, 9, rng)                     # Monte Carlo cost of reaching +9 from +0

Step (Dictionary, index = the level being refined from): stone, chance (0..1), fail: {"keep": w, "drop:3": w,
"destroy": w} weighted outcomes. "protect": a floor level and the chance the protection works; when it works, any
failure that would go below the floor (or destroy) lands on the floor instead.
Default steps after Seal Online's wiki: crystal +0..+3 always works; ruby +3..+6 at 70/60/50 % and only the ruby is
lost; diamond +6..+9 drops to +3, to +2 or destroys; pink diamond +9..+12 destroys. The wiki gives no diamond or
pink-diamond rates: those numbers are placeholders.
The step for refining from `level` to level + 1 ({} at the top).
One try. options: bonus (added to the chance), protect {floor, chance}. Never changes anything on its own:
the caller applies r.level / r.destroyed to its item and takes one r.stone from the bag.
Average stones spent (per stone kind) and the share of runs that destroyed the item, refining from `from` until
`to` (restarting from +0 after a destruction is not counted: a destroyed run just ends). For tuning tables.

測試引用（存在不等於本輪已重跑）：tests/test_mmo_modules.gd

## run_goals

局內／跨局目標與獎勵解鎖；事件式進度追蹤

適用：事件式進度追蹤

入口：[addons/proto_kit/run_goals.gd](../../addons/proto_kit/run_goals.gd) · rule · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/run_goals.gd")
var goals: Array[Dictionary] = [{"id": "first", "event": "kill", "need": 1}]
var tracker = Capability.new(goals)
tracker.begin_run()
var unlocked: Array = tracker.note("kill")
```

### 參數、輸出與訊號

```gdscript
func _init(goals: Array[Dictionary]) -> void:
func begin_run(tier: int = 0) -> void:
func note(event: String, amount: int = 1) -> Array:
func progress(id: String) -> Vector2i:
func claimed() -> int:
func total() -> int:
func rewards_unlocked() -> Array:
func to_dict() -> Dictionary:
func from_dict(data: Dictionary) -> void:
```

Run and lifetime goals from {id, tier, event, need, per_run, reward} records.
`const RunGoals = preload("res://addons/proto_kit/run_goals.gd")`
Completion unlocks rewards permanently; saves omit per-run counters.

測試引用（存在不等於本輪已重跑）：tests/test_genre_modules.gd

## run_timeline

局內事件與生怪預算；定時首領和難度曲線

適用：定時首領和難度曲線

入口：[addons/proto_kit/run_timeline.gd](../../addons/proto_kit/run_timeline.gd) · rule · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。 加權核心已改用 weighted_choice；有效分佈保留順序及一次 randf，無效分佈的防禦行為已調整，重構後測試暫緩。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/run_timeline.gd")
var rng = RandomNumberGenerator.new()
rng.seed = 42
var timeline = Capability.new({"duration": 60.0, "rate": [[0, 1.0]], "roster": [{"kind": "slime", "weight": 1}]}, rng)
var output: Dictionary = timeline.step(1.0, 0)
```

### 參數、輸出與訊號

```gdscript
var time: float = 0.0
var duration: float
var max_alive: int
func _init(config: Dictionary, rng: RandomNumberGenerator) -> void:
func step(delta: float, alive_count: int = 0) -> Dictionary:
func finished() -> bool:
func next_event(kind: String = "") -> Dictionary:
func roster_at(at: float = -1.0) -> Array:
func to_dict() -> Dictionary:
func from_dict(data: Dictionary) -> void:
static func sample(keys: Array, at: float) -> float:
```

The director of one timed survivor run: scripted events at fixed times (a boss every few minutes, a stampede, the
final boss), a spawn-rate curve, which enemy kinds appear in which minutes, and how often a spawn is an elite.
Pure logic: the game calls step() while the run is not paused (level-up cards pause it) and spawns what it returns.
`const RunTimeline = preload("res://addons/proto_kit/run_timeline.gd")`

var run := RunTimeline.new({
"duration": 960.0,                                          # 16:00, the final boss
"events": [{"at": 180, "id": "hogger", "kind": "boss"}, {"at": 75, "id": "stampede", "kind": "event"}],
"rate": [[0, 1.5], [300, 4.0], [900, 9.0]],                 # spawns per second, linear in between
"roster": [{"kind": "kobold", "from": 0, "to": 240, "weight": 3}, {"kind": "wolf", "from": 60, "weight": 2}],
"elite": [[0, 0.0], [120, 0.02], [900, 0.08]],              # chance that a spawn is an elite
"max_alive": 300,
}, rng)
var out := run.step(delta, alive_count)   # {"events": [event dicts], "spawns": [{"kind", "elite"}]}

Spawning is a budget: rate x delta accumulates and whole spawns are taken out, so a low rate still spawns, and a
long frame spawns its share at once. While alive_count >= max_alive the budget stops growing (no burst later).
Deterministic for a seeded RNG. `next_event()` feeds a "next boss in 02:52" label.
The next scripted event (or {}), for a countdown label: event.at - time seconds away.
Kinds that can spawn at `at` (default now), with their weights.
Linear interpolation over [[time, value], ...] keys (sorted by time); flat before the first and after the last.

測試引用（存在不等於本輪已重跑）：tests/test_survivor_modules.gd

## save_slots

JSON 版本、備份恢復與遷移鏈；跨版本進度存檔

適用：跨版本進度存檔

入口：[addons/proto_kit/save_slots.gd](../../addons/proto_kit/save_slots.gd) · rule · 來源靜態引用：seal-meadow；不代表本輪已做遊戲／真人驗收

限制／副作用：單寫入者、JSON envelope {version,data}，version 非負整數（保留 v0）；數字讀回可能為 float。restore(path,version,migrations={},validator=Callable()) 不寫磁碟，主／備份任一可辨識較新版本均拒絕；無效主檔可選備份。migration 為逐版純 Dictionary→Dictionary；validator 為目前版本純 Dictionary→bool，驗證失敗 error=invalid，回呼無效或型別錯誤亦拒絕，回呼自身腳本錯誤不捕捉。save(path,data,version,validator=Callable(),migrations={}) 驗證序列化後候選，寫入前查兩檔；較新版本 ERR_UNAVAILABLE、候選無效 ERR_INVALID_DATA。僅能通過遷移及驗證的主檔原始 bytes 輪替備份，否則保留原備份。省略 validator 只有 envelope 檢查。可能先成功更新備份再主檔寫入失敗；不保證跨檔原子性、跨程序鎖或 revision 競態防護。

### 使用範例

```gdscript
const Saves = preload("res://addons/proto_kit/save_slots.gd")
# 純回呼由遊戲提供，檢查目前 schema 的必要欄位／型別／範圍
var validator: Callable = validate_profile
var migrations: Dictionary = {} # 有舊版本時填逐版轉換
var restored: Dictionary = Saves.restore("user://profile.json", 1, migrations, validator)
# error == "" 才採用 restored.data；newer 必須停止自動存檔
# snapshot 為遊戲建立的 JSON Dictionary
var error: Error = Saves.save("user://profile.json", snapshot, 1, validator, migrations)
# error == OK 才顯示保存成功
```

### 參數、輸出與訊號

```gdscript
static func save(path: String, data: Dictionary, version: int, validator: Callable = Callable(), migrations: Dictionary = {}) -> Error:
static func restore(path: String, version: int, migrations: Dictionary = {}, validator: Callable = Callable()) -> Dictionary:
```

Versioned JSON snapshots. One writer per path; callbacks must be pure and must not write files.
validator(Dictionary) -> bool checks the CURRENT schema after migration / JSON serialization.
migrations: {from_version: Callable(Dictionary) -> Dictionary}, one version per step.
restore never writes. Either file from a newer version blocks restore AND save.
No cross-process lock or two-file transaction. AtomicFile commits each file separately.
Existing three-argument calls remain valid. Invalid snapshots never rotate backups.
ERR_UNAVAILABLE: newer on disk; ERR_INVALID_DATA: candidate rejected; other errors: file IO.
Only a valid main becomes .bak, preserving its original bytes. Otherwise retain the existing backup.
Returns {data, source: "main"|"backup"|"", error: ""|"missing"|"corrupt"|"newer"|"migration"|"invalid"}.
Invalid payload / migration may fall back to backup; newer in EITHER file always blocks.
data is detached from disk; no repair or automatic write occurs when selecting backup.
Checks numeric versions before conversion, including future envelopes with malformed payloads.

測試引用（存在不等於本輪已重跑）：tests/test_capability_composition.gd, tests/test_m0_modules.gd

## scene_builder

儲存可編輯場景與 owner 驗證；一次性製作工具

適用：一次性製作工具

入口：[addons/proto_kit/scene_builder.gd](../../addons/proto_kit/scene_builder.gd) · authoring · 來源靜態引用：debt-commission、dreamling-idle、erwin-run、hero-horde-idle、horde-25d、luffy-marineford、madara-survivor、seal-meadow、skybound-blades、star-tide-harbor、survivor-series；不代表本輪已做遊戲／真人驗收

限制／副作用：只在製作期產生或保存資源；正常啟動不重建已人工編輯的場景。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/scene_builder.gd")
# 僅在一次性製作工具內執行
var root := Node2D.new()
var result: Dictionary = Capability.save_scene(root, "res://scenes/new_scene.tscn")
# save_scene 取得 root 所有權並釋放；不得再次 free。已存在時 skip。
```

### 參數、輸出與訊號

```gdscript
static func save_scene(root: Node, path: String, options: Dictionary = {}) -> Dictionary:
static func open_scene(path: String) -> Dictionary:
static func put(parent: Node, child: Node, node_name: String, index: int = -1) -> Node:
static func own_nodes(root: Node) -> void:
static func count_nodes(node: Node) -> int:
static func instance(path: String) -> Node:
static func unique(node: Node) -> Node:
static func add(parent: Node, child: Node, node_name: String = "") -> Node:
```

Saves a node tree built in code as a .tscn from a headless generator script, then proves the file by
reloading it. `const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")`

Why a script: PackedScene.pack() writes what the editor writes, so the result opens and edits like any
scene. But pack() keeps only nodes whose `owner` is the scene root and silently drops the rest, so
save_scene() sets owners itself and then checks that the saved file holds what was built.

Owner rule: every node you built gets `owner = root`. A sub-scene instance (instance()) gets an owner on
its root only: its inner nodes belong to the sub-scene, and owning them would save them a second time
into this scene. So a node added *under* an instance is dropped by pack(); the node-count check reports it.

A generator is a one-time authoring tool: once its scenes are hand-edited, re-running would erase the
edits. save_scene() therefore skips files that already exist unless options.overwrite is true. Put a note
in the header of every generator that has been applied, e.g.
## Applied 2026-10-03. Re-running is rejected: the scenes exist and were edited by hand; do not overwrite.

Mini generator (godot --headless --path . --script res://tools/build_menu.gd):
extends SceneTree
const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
func _initialize() -> void:
_build.call_deferred()
func _build() -> void:
var menu := Control.new()
menu.name = "Menu"
SceneBuilder.add(menu, SceneBuilder.unique(Label.new()), "Title")   # reachable as %Title
SceneBuilder.add(menu, SceneBuilder.instance("res://ui/panel.tscn"), "Panel")
var result := SceneBuilder.save_scene(menu, "res://ui/menu.tscn", {"expected_refs": ["res://ui/panel.tscn"]})
quit(0 if result.ok else 1)
Gives `root` and everything under it the owner rule above, writes `path`, reloads it and checks it. Always
frees `root`. Returns {"ok", "skipped", "nodes", "refs", "error"}: `nodes` is how many nodes were built
(0 when skipped), `refs` the distinct sub-scene paths the saved file references, `error` empty on success.
A failure also push_errors and deletes the file if this call created it, so a rerun does not skip a bad scene
(an overwritten file is already replaced and stays).

options:
"overwrite": true      replace an existing file (default: skip it and return ok + skipped)
"expected_refs": [..]  sub-scene paths that must appear in the saved scene
Opens a saved scene for a script to change and save back, the way the editor opens it: sub-scene instances
stay references, and the root is a plain node rather than an instance of `path` (which pack() would save as a
scene that inherits itself). Returns {"root": Node, "refs": Array[String]}, `refs` being the sub-scene paths
the file references now; pass them (plus any you add) as expected_refs when saving it back:
var opened := SceneBuilder.open_scene(HUD)
...change opened.root...
SceneBuilder.save_scene(opened.root, HUD, {"overwrite": true, "expected_refs": opened.refs})
A missing or broken file gives {"root": null, "refs": []}.
Adds `child` to `parent` as `node_name` at child index `index` (-1 = last). A node of that name already there is
freed and `child` takes its place (and its index, when `index` is -1), so a patch script can run again.
Sets `owner` on every node under `root` (not into sub-scene instances) and turns unique() marks into
unique_name_in_owner. save_scene() calls this; call it yourself only to inspect the tree before saving.
Counts `node` and all its descendants, including the inner nodes of sub-scene instances.
Instantiates a saved scene with the editor's edit state. pack() then writes a clean reference to `path`
plus only the properties you change; a plain instantiate() would copy the sub-scene root's position,
modulate and so on into this scene as overrides, and later edits to the sub-scene would not show through.
Marks `node` to become a %UniqueName in the saved scene; returns `node` so it chains inside add().
add_child with a readable name: `node_name` if given, else the node's own name or type, numbered on a
clash. Returns `child`.
Reloads `path` from disk and returns what is wrong with it; fills `refs` with its sub-scene paths.

測試引用（存在不等於本輪已重跑）：tests/test_genre_modules.gd, tests/test_proto_kit.gd

## scene_loader

背景載入與顯示進度；自訂載入畫面的邏輯

適用：自訂載入畫面的邏輯

入口：[addons/proto_kit/scene_loader.gd](../../addons/proto_kit/scene_loader.gd) · rule · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：一個實例只持有一個請求；is_loading() 包含滿格停留期間。忙碌時 request() 回傳 false 且不改動現有 path/進度/failed；非忙碌的啟動失敗才設 failed。step(delta) 接受有限非負秒數，非法值回傳 null 且不更新；PackedScene 只交付一次。path/shown/failed 作為唯讀狀態使用。cancel() 收取並丟棄結果，可能阻塞等載入完成，不是中止背景工作。fail() 僅用於收取場景後宿主切換失敗。時間設定使用有限非負值，fill_speed > 0。無執行緒 Web 的 request 可能同步阻塞，先讓載入畫面繪製兩幀。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/scene_loader.gd")
var loader = Capability.new()
var accepted: bool = loader.request("res://main.tscn")
# 每幀：var scene = loader.step(delta)；非 null 才交給 SceneTree
# 離開載入畫面：loader.cancel()
# accepted == false 時先看 is_loading()：true 為忙碌，false 再看 failed
# cancel() 可能等待，不能當成即時取消
```

### 參數、輸出與訊號

```gdscript
var min_show_time: float = 1.2
var fill_speed: float = 2.5
var hold_at_full: float = 0.2
var shown: float = 0.0
var failed: bool = false
var path: String = ""
func is_loading() -> bool:
func request(scene_path: String) -> bool:
func step(delta: float) -> PackedScene:
func fail() -> void:
func cancel() -> void:
```

The logic of a loading screen: loads a scene on a thread and says what the screen may show. The look (a bar,
a percentage, tips, an error and a retry button) is the game's own scene. `const SceneLoader = preload("res://addons/proto_kit/scene_loader.gd")`

var loader := SceneLoader.new()
loader.request("res://main.tscn")              # false if busy (unchanged), otherwise failed on load failure
func _process(delta: float) -> void:
var packed: PackedScene = loader.step(delta)   # null until the scene is loaded AND the bar has been full for a moment
bar.value = loader.shown * 100.0
if loader.failed: show the error and a retry button that calls loader.request(path) again
elif packed != null and get_tree().change_scene_to_packed(packed) != OK: loader.fail()   # loaded, cannot be instantiated
func _exit_tree() -> void:
loader.cancel()                                 # collect/discard the pending result; may wait for loading

What `shown` does, and why: it only moves forward; it never gets ahead of the real load; and it never gets ahead of
the clock either (`min_show_time`), so the screen is no flash and a load that finishes at once (a web build without
threads loads inside the request) still fills the bar over that time. It moves at most `fill_speed` of the bar's
length per second, and the full bar holds for `hold_at_full` seconds before `step` hands the scene over.
Only the status LOADED lets the switch go ahead: the progress can read 1.0 a moment before the status says so.
On a web build without threads, give the screen two frames to be drawn before calling request(): it loads inside the call.
Seconds the screen is never up for less than.
The bar moves at most this much of its length per second, and never backwards.
The full bar stays this long before the switch.
What the bar may show, 0..1.
The accepted request failed. A request rejected while busy does not change this flag.
The scene being loaded.
True until the pending result has been collected, including the loading bar's hold period.
Starts loading `scene_path`. While busy, returns false without changing the current request or progress.
Otherwise resets the clock/bar and sets failed if loading cannot start. Cancel/collect before starting another.
Once per frame, with the frame's delta. Returns the loaded scene once the bar has been full for `hold_at_full`
seconds, else null (loading, failed, or not started). Call fail() if the game cannot use the scene it gets.
The game could not use what it was given (change_scene_to_packed refused it).
Collects/discards a pending result; may wait for completion. This does not abort the underlying load.
Call when the owner leaves, or before replacing a request. Repeated calls are harmless.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## scene_router

淡出換場與一次性交接資料；畫面導航

適用：畫面導航

入口：[addons/proto_kit/scene_router.gd](../../addons/proto_kit/scene_router.gd) · node · 來源靜態引用：hero-horde-idle；不代表本輪已做遊戲／真人驗收

限制／副作用：場景擁有生命週期；依下方契約準備子節點與資源。每幀只能由一個時鐘推進，不可重複 auto/manual step。

### 使用範例

```gdscript
# CanvasLayer 掛此腳本，子 ColorRect 設唯一名稱 %Fade
var success: bool = await $Router.go("res://scenes/main.tscn", {&"stage": 3})
```

### 參數、輸出與訊號

```gdscript
@export var fade_seconds: float = 0.2
signal screen_changed(path: String)
func go(path: String, hand: Dictionary = {}) -> bool:
func busy() -> bool:
func take(key: StringName, default: Variant = null) -> Variant:
```

Moving between screens with a fade, plus values handed to the next screen. Make it the script (or the base of
the script) of an autoload scene: a CanvasLayer with a high `layer` and a full-rect ColorRect child that is a
%Fade unique name, colour set in the scene. Without %Fade it switches at once.
extends "res://addons/proto_kit/scene_router.gd"      # scripts/app.gd: add the game's shared state

App.go("res://scenes/main.tscn", {&"stage": 3})       # fade out, change scene, fade in
var stage: int = App.take(&"stage", 1)                # in the next screen's _ready; the default when run alone

The fades run on PROCESS_MODE_ALWAYS and unpause the tree before the change, so a pause menu can go(). While a
change is under way (busy()), another go() is ignored and the fade swallows taps. Screens should still run without
the autoload (tests instantiate them directly): take() is the only coupling, and it has a default.
Seconds of each half of the fade.
Fades out, switches to the scene at `path`, fades in. `hand`: values for the next screen's take(). Returns false
when a change is already under way or `path` cannot be loaded (the current screen stays).
A change is under way.
A value handed over by go() for this screen (removed once taken), or `default`.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## screenshot

Viewport 圖片擷取；多解析度畫面檢查

適用：多解析度畫面檢查

入口：[addons/proto_kit/screenshot.gd](../../addons/proto_kit/screenshot.gd) · inspection · 來源靜態引用：hero-horde-idle；不代表本輪已做遊戲／真人驗收

限制／副作用：需要 renderer；headless 或空影像回空字串。save 立即讀目前 Viewport，不自行等待 frame_post_draw；宿主先等待正確畫面。out_dir 取第一個使用者參數；檔名 widthxheight_label.png，重複呼叫同 label 可覆寫。label 沒有檔名清理，不接任意不可信路徑；mkdir/save 失敗只以空字串與 push_error 表達。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/screenshot.gd")
# 需要實際 renderer；放在已進樹的 Node 中
var output: String = Capability.save(get_viewport(), "user://shots", "home")
```

### 參數、輸出與訊號

```gdscript
static func out_dir(fallback: String = "user://shots") -> String:
static func save(viewport: Viewport, dir: String, label: String) -> String:
```

Screenshots for capture tools and reviews: `const Screenshot = preload("res://addons/proto_kit/screenshot.gd")`.
Files are named <width>x<height>_<label>.png, so shots of the same moment at several --resolution sizes sit side
by side. It needs a renderer: run the tool with a window (godot --path . --resolution 390x844 --script ...), not
--headless, whose viewport texture is empty.

extends SceneTree
const Screenshot = preload("res://addons/proto_kit/screenshot.gd")
func _initialize() -> void:
_run.call_deferred()
func _run() -> void:
var out := Screenshot.out_dir()                 # first argument after --, else user://shots
change_scene_to_file("res://scenes/home.tscn")
for k in 10: await process_frame
Screenshot.save(root, out, "home")             # -> <out>/390x844_home.png
quit()
The output folder: the first user argument (after `--` on the command line), else `fallback`.
Saves what `viewport` shows now as <dir>/<w>x<h>_<label>.png (the folder is made if missing) and prints the path.
Returns the path, or "" when there was nothing to save (headless) or the write failed.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## sfx_bank

依事件名播放音效、後備與聲道節流；遊戲音效接線

適用：遊戲音效接線

入口：[addons/proto_kit/sfx_bank.gd](../../addons/proto_kit/sfx_bank.gd) · node · 來源靜態引用：dreamling-idle、erwin-run、hero-horde-idle、luffy-marineford、madara-survivor、seal-meadow、skybound-blades、survivor-series；不代表本輪已做遊戲／真人驗收

限制／副作用：場景擁有生命週期；依下方契約準備子節點與資源。每幀只能由一個時鐘推進，不可重複 auto/manual step。

### 使用範例

```gdscript
# 遊戲腳本繼承 sfx_bank.gd；在 super._ready() 前設定後備音表
$Sfx.play(&"hit")
var source: String = $Sfx.source_of(&"hit")
```

### 參數、輸出與訊號

```gdscript
@export var sound_dir: String = "res://assets/sfx"
@export var voices: int = 10
@export_range(-40.0, 6.0, 0.5) var volume_db: float = -6.0
var fallback: Dictionary[StringName, StringName] = {}
var long_sounds: Dictionary = {}
signal played(sound: StringName)
func play(sound: StringName, min_gap: float = 0.035) -> void:
func stream_for(sound: StringName) -> AudioStream:
func source_of(sound: StringName) -> String:
func refresh() -> void:
```

Sound for a game's events, played by name round-robin on a few voices: `sfx.play(&"hit")`.
A game extends this script (there is no class_name) and fills the three tables that are its own: `_streams`
(placeholder sounds), `fallback` (which event sounds like which) and `long_sounds` (which sounds are cut short).

extends "res://addons/proto_kit/sfx_bank.gd"           # game/sfx.gd, on a Node of the main scene
const Synth = preload("res://addons/proto_kit/synth.gd")
func _ready() -> void:
_streams = {&"hit": Synth.click(0.05, 0.3, 40.0), &"boom": Synth.click(0.35, 0.5, 9.0)}
fallback = {&"enemy_die": &"boom"}                          # no sound of its own: plays boom's
long_sounds = {&"boom": {"seconds": 0.5, "gain_db": -3.0}}  # cut after 0.5 s, 3 dB quieter, never stacked
super()                                                     # builds the voices: fill the tables first
# anywhere: sfx.play(&"hit"), sfx.play(&"enemy_die", 0.0), sfx.played.connect(func(sound): ...)

An event's sound is looked up in this order:
1. a file in `sound_dir` named after the event: <event>.ogg, else <event>.wav
2. the placeholder stream registered under that name in `_streams`
3. the event it borrows from (`fallback`): a file or placeholder of that other name
4. nothing: playing an event nobody has a sound for is silent, never an error (`played` is still emitted).
So dropping a file named like an event into `sound_dir` replaces its sound without touching code.

`play()` thins a burst of hits by wall-clock time (Time.get_ticks_msec) on purpose: what the ear hears is real
time, so an audio throttle should be too. Do not copy that for gameplay. A lock or cooldown measured in wall time
breaks under `--fixed-fps` tests, where game time runs far faster than the wall clock, and swallows every input.
Gameplay timing uses game time, e.g. `create_timer(seconds, true, false, true)`.
Emitted for every play() call, even for events with no sound. Tests and debugging listen to it.
Where <event>.ogg and <event>.wav are looked for. Call refresh() after changing it.
Events that sound like another event when they have no sound of their own (no file, no placeholder).
The borrowing must not loop (a borrows from b, b from a).
Sounds that outlast the moment they belong to, as {event: {"seconds": float, "gain_db": float}}. They are cut
after `seconds` (with a CLIP_FADE fade-out), play `gain_db` quieter or louder than the rest, and never stack:
while one is sounding, the same event is skipped. For example a 5 s engine loop used for a 0.7 s wind-up.
Builds the voices. A subclass fills its tables first and then calls super().
`min_gap` (seconds, wall clock) keeps a burst of hits from stacking into noise.
The sound an event plays right now, or null if it has none.
Where an event's sound comes from: the file path, "synth", "<event> (borrowed)" or "" for none.
Forget what was found, so files added or removed since are noticed (dropped-in files are otherwise
picked up the next time the game starts). Also needed after changing a table or `sound_dir` once an
event has been looked up.
A file the editor has imported loads normally. One that was just dropped in and not imported yet
(running the game before the editor has looked at the folder) is read straight from disk.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## shot_camera

固定構圖鏡頭演出與優先權；HD-2D 戰鬥運鏡

適用：HD-2D 戰鬥運鏡

入口：[addons/proto_kit/shot_camera.gd](../../addons/proto_kit/shot_camera.gd) · node · 來源靜態引用：hero-horde-idle；不代表本輪已做遊戲／真人驗收

限制／副作用：場景擁有生命週期；依下方契約準備子節點與資源。每幀只能由一個時鐘推進，不可重複 auto/manual step。

### 使用範例

```gdscript
# Camera3D 掛此腳本；shot 是 camera_shot Resource
var shot = preload("res://addons/proto_kit/camera_shot.gd").new()
var seconds: float = $Camera3D.play(shot, Vector3.ZERO)
$TimeControl.hit_stop(seconds)
```

### 參數、輸出與訊號

```gdscript
@export var shake_m := Vector2(0.2, 0.16)
@export var trauma_decay: float = 1.8
@export var release_seconds: float = 0.25
func play(shot: Shot, focus: Vector3) -> float:
func release(seconds: float = -1.0) -> void:
func reset() -> void:
func add_trauma(amount: float) -> void:
func busy() -> bool:
```

The gameplay camera of a fixed-framing HD-2D scene (an idle push, a tactics board, a boss arena). It rests on the
framing saved in the scene; events ask it for a shot (camera_shot.gd: a short push-in or small orbit toward a focus
point, with an optional hit stop and shake) and for shake. Only this script moves the camera.
Readability first: release() eases back home whenever the player needs the whole field (a telegraph went up), and
a stronger shot (priority) is not cut by a weaker one. Rays for taps use the live camera, so picking stays right
during a shot. play() returns the shot's hit stop for the game's time control (time_control.gd).
extends "res://addons/proto_kit/shot_camera.gd"     # or set it as the Camera3D's script directly
var stop := camera.play(preload("res://camera/volley.tres"), boss.global_position)
Shake here is its own two-sine offset on h_offset / v_offset (trauma squared), like camera_shake.gd but built in,
so one script owns the camera. A follow camera (survivors, chase) is a different rig: see the README.
Shake: offsets in metres at trauma 1 (trauma is squared, so small hits stay calm).
Weight when the shot started easing out, so a release from mid-move eases from where it is.
Starts `shot` toward world point `focus` unless a stronger shot is playing. Returns the shot's hit stop.
Ease back to the gameplay framing now (a telegraph went up, or the push is over).
The shot's peak framing: orbit the home camera around the focus by yaw/pitch, then dolly toward the focus. The
camera keeps its home orientation relative to the orbit, so the field stays on screen.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## song_clock

歌曲聽覺時間與拍子換算；節奏遊戲判定

適用：節奏遊戲判定

入口：[addons/proto_kit/song_clock.gd](../../addons/proto_kit/song_clock.gd) · node · 來源靜態引用：kagura-dango；不代表本輪已做遊戲／真人驗收

限制／副作用：場景擁有生命週期；依下方契約準備子節點與資源。每幀只能由一個時鐘推進，不可重複 auto/manual step。

### 使用範例

```gdscript
# scene Node 掛此腳本；檔案由遊戲提供
$SongClock.load_song({"bpm": 120, "offset": 0.05, "music": "res://audio/song.ogg"})
$SongClock.play()
var beat: float = $SongClock.beat_at($SongClock.time())
```

### 參數、輸出與訊號

```gdscript
@export var use_audio_position := true
var bpm := 120.0
var offset := 0.0
var music_start := 0.0
var clock := Callable()
@export var level_db := 0.0
@export var bus := &"Master"
func load_song(chart: Dictionary) -> void:
func play(from := -1.0, fade_in := 0.0) -> void:
func stop() -> void:
func duck(on: bool) -> void:
func song_length() -> float:
func playing() -> bool:
func wall_time() -> float:
func audio_time() -> float:
func time() -> float:
func beat_time(beat: float) -> float:
func beat_at(t: float) -> float:
```

Song clock for rhythm games: plays one song and says where in it we are, in song-file seconds aligned with what
the player hears. Gameplay reads time(), never the frame clock. bpm/offset turn beats into seconds.
const SongClock = preload("res://addons/proto_kit/song_clock.gd")
var clock := SongClock.new(); add_child(clock); clock.load_song({bpm = 120, offset = 0.05, music = "res://x.mp3"})
clock.play(); ... clock.time(), clock.beat_at(clock.time())
Native builds read the audio stream position. The web build (Sample playback) cannot: its reported position trails
the sound by about a second and the first play() blocks ~0.8 s, so it uses the wall clock anchored after play().
Tests set `clock` to a game-time Callable so they run the same under --fixed-fps.
Extracted from kagura-dango (scripts/conductor.gd extends this).
Native builds: read the song position from the audio stream (true) or from the moment play() returned (false).
Where in the song file playback starts (seconds), e.g. a round that plays only part of the song.
time() keeps counting in song-file seconds, so offset (beat 0) is also a song-file time.
Song level under a spoken line (duck).
Trim for the song itself (commercial songs are often mastered near -7 LUFS and clip against SFX at 0 dB).
Audio bus the song plays on.
Plays from music_start, or from `from` (song-file seconds, e.g. a chart editor's cursor). fade_in > 0 raises the
song from silence over that many seconds.
Lowers the song under a spoken line (on) and brings it back (off). Ignored while stopped or fading out.
Ducking and the fades are separate amounts added together, so a line said during the fade-in does not cut it.
Length of the loaded song file in seconds (0 without one).
Song seconds. Never goes backwards within one play.

測試引用（存在不等於本輪已重跑）：tests/test_song_clock.gd

## sprite3d_actor

單位 billboard 動畫與朝向；主角、首領、NPC

適用：主角、首領、NPC

入口：[addons/proto_kit/sprite3d_actor.gd](../../addons/proto_kit/sprite3d_actor.gd) · node · 來源靜態引用：luffy-marineford、seal-meadow、skybound-blades；不代表本輪已做遊戲／真人驗收

限制／副作用：個別 actor scene，群體用 MultiMesh＋Sprite3DSheet。ready 複製 ShaderMaterial，避免 runtime frame 狀態共享；size_from_sheet=true 會改 Sprite/Xray/Shadow scale。auto_advance=false 才由宿主 step(game seconds)，不可雙重推進；ticks 每秒60。facing 為 world XZ，使用目前 viewport camera。sheet 型別宣告為 Resource 但實際需提供 Sprite3DSheet 協定；設定有效性需先驗證。finished 是查詢而非完成 signal；null/空動畫回 true，loop 永不完成。

### 使用範例

```gdscript
var actor = preload("res://addons/proto_kit/sprite3d_actor.tscn").instantiate()
# 指派遊戲的 sprite3d_sheet Resource 後加入場景
actor.sheet = load("res://resources/hero_sheet.tres")
add_child(actor)
actor.play(&"walk")
```

### 參數、輸出與訊號

```gdscript
@export var sheet: Resource:
@export var anim: StringName = &"idle"
@export var facing: Vector3 = Vector3(0.0, 0.0, 1.0)
@export var outline: Color = Color(1.0, 1.0, 1.0, 0.0)
@export var auto_advance: bool = true
@export var sprite_path: NodePath = ^"Sprite"
@export var xray_path: NodePath = ^"Xray"
@export var shadow_path: NodePath = ^"Shadow"
@export var ghost_paths: Array[NodePath] = []
@export var size_from_sheet: bool = true
var flash: float = 0.0
var dissolve: float = 0.0
var ticks: float = 0.0
var direction: int = -1
var drawn: Vector2i = Vector2i.ZERO
func step(delta: float) -> void:
func play(anim_name: StringName, restart: bool = false) -> void:
func finished() -> bool:
```

One sprite actor (player, boss, ally, NPC): picks the direction row from the camera and plays an animation of a
sprite3d_sheet. Crowds do not use this: they fill a MultiMesh with the same sheet math.
Spec: skill sprite-actors-3d.

Actor (Node3D, this script)
├── Sprite  MeshInstance3D: QuadMesh center_offset (0, 0.5, 0), ShaderMaterial sprite3d.gdshader, cast_shadow off
├── Shadow  MeshInstance3D: PlaneMesh 1x1, ShaderMaterial sprite3d_shadow.gdshader
└── Xray    MeshInstance3D (optional, the player): same QuadMesh, sprite3d_xray.gdshader, render_priority 1

actor.facing = velocity          # world direction; keep it when the actor stops
actor.play(&"attack")            # restarts only when the animation changes; one-shots hold their last frame
actor.flash = 1.0                # the script does not fade it: whoever hits fades it

Time: by default the actor advances itself in _process (Engine time: follows Engine.time_scale and pausing).
A game whose simulation has its own clock (hit stop or a level-up pause that only slows its own delta) sets
`auto_advance = false` and calls `step(game_delta)` from its update, so animation frames stay in step with hits.

Materials: at run time each actor draws with its own copies (made in _ready), so many instances of one scene can
show different frames and stand at different heights. In the editor the actor never touches its materials or
nodes on its own: the scene shows what is saved in it (set the preview `frame` on the material). Setting `sheet` in
the editor is an authoring step: it gives this actor its own copies of the materials (an actor sharing a material
or a .tres is left alone), writes the atlas, grid and foot strip into them and, with `size_from_sheet`, the quad
size; all of it is saved with the scene.
World-space facing (only XZ is used).
Sets the quad (and xray, shadow) size from the sheet when the sheet is set. Off: keep the sizes in the scene.
Ticks since the animation started (1 tick = 1/60 s of the clock that advances the actor).
Current direction index (keeps the hysteresis); -1 until the first frame.
Vector2i(cell, facing) drawn this frame.
Advances the animation by `delta` seconds of game time and redraws. 0 keeps the frame (a paused world).
Starts an animation (no restart when it is already playing, unless `restart`).
True once a one-shot animation has shown its last frame for its full time. Loops never finish.
Sprite, xray and ghosts (they take the sheet and frame); with `with_shadow`, the shadow too (copied, not drawn).

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## sprite3d_gallery

sprite3d 展示擷取；製作期檢查視角與動畫

適用：製作期檢查視角與動畫

入口：[addons/proto_kit/sprite3d_gallery.gd](../../addons/proto_kit/sprite3d_gallery.gd) · inspection · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：SceneTree 視覺診斷工具，程序建立 placeholder sheet／actors／crowd；等 frame_post_draw 拍四面板。需要 renderer；輸出是首參數檔案，未自行建父資料夾／檢查 save_png 結果，exit0不保證檔案成功。不能用佔位圖驗收正式美術或以程序畫面取代保存遊戲場景。

### 使用範例

```gdscript
env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1600x1600x24" godot --path <project> --resolution 480x360 \
  --rendering-method gl_compatibility -s res://addons/proto_kit/sprite3d_gallery.gd -- /tmp/sprite3d.png
```

### 參數、輸出與訊號

```gdscript
var out: String
var camera: Camera3D
var shots: Array[Image] = []
var crowd: MultiMeshInstance3D
var actors: Array[Node3D] = []
```

Renders the sprite3d shaders for judging them without a game: a ring of eight placeholder actors, each facing
outward (so the one nearest the camera faces it, the right one faces screen right...), seen from three camera
pitches, plus a MultiMesh crowd showing outline roles, a hit flash and a dissolve. Saves one PNG of four panels.
Each placeholder row shows its row number as a pixel digit (a mirrored row shows the digit flipped) and a nose
on the side it faces. Renders, so run it on a virtual display, never on the user's desktop:
env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1600x1600x24" godot --path <project> --resolution 480x360 \
--rendering-method gl_compatibility -s res://addons/proto_kit/sprite3d_gallery.gd -- /tmp/sprite3d.png
Five drawn rows (front, front-right, right, back-right, back), one frame each: a body with the row digit and a
nose on the facing side (front rows: low, back rows: none).

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## sprite3d_sheet

圖集、方向與動畫資料資源；單位與 MultiMesh 共用規格

適用：單位與 MultiMesh 共用規格

入口：[addons/proto_kit/sprite3d_sheet.gd](../../addons/proto_kit/sprite3d_sheet.gd) · resource · 來源靜態引用：hero-horde-idle、luffy-marineford、seal-meadow、skybound-blades；不代表本輪已做遊戲／真人驗收

限制／副作用：可存成 .tres；多實例修改前 duplicate，避免共享資源互相污染。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/sprite3d_sheet.gd")
var sheet = Capability.from_json("res://assets/sprites/sheets.json", "hero")
# hero 是遊戲圖集 manifest 的角色鍵
if sheet != null:
    var cell: Vector2i = sheet.cell(&"walk", 0, 0)
```

### 參數、輸出與訊號

```gdscript
@export var atlas: Texture2D
@export var columns: int = 1
@export var rows: int = 1
@export var cell_px: int = 96
@export var foot_px: int = 4
@export var meters_per_px: float = 0.025
@export_enum("1:1", "4:4", "8:8") var directions: int = 8
@export var mirror: bool = true
@export var anims: Dictionary = {}
@export var hysteresis: float = 6.0
static func view_angle(facing: Vector3, camera_basis: Basis) -> float:
func logical_count() -> int:
func direction(angle: float, previous: int = -1) -> int:
func resolve(anim: StringName) -> Dictionary:
func cell(anim: StringName, dir: int, tick: int) -> Vector2i:
static func frame_index(a: Dictionary, tick: int) -> int:
static func length_ticks(a: Dictionary) -> int:
func foot_gutter() -> float:
func size_m() -> float:
func apply(material: ShaderMaterial) -> void:
static func instance_custom(cell_index: int, flash: float, facing: int, phase: float, dissolve: float = 0.0) -> Color:
static func instance_color(tint: Color, role: int) -> Color:
static func from_json(path: String, character: String) -> Resource:
```

One character's sprite sheet for sprite3d.gdshader: which atlas cell to draw for an animation, a camera-relative
direction and a time. Spec: skill sprite-actors-3d.
`const Sprite3DSheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")`

var sheet := Sprite3DSheet.from_json("res://assets/sprites/sheets.json", "luffy")   # tools/sprite_atlas.py output
sheet.apply(material)                                     # atlas, grid and foot strip into a sprite3d material
var angle := Sprite3DSheet.view_angle(facing, camera.global_basis)
dir = sheet.direction(angle, dir)                         # keep `dir` per actor: it carries the hysteresis
var drawn := sheet.cell(&"walk", dir, ticks)              # Vector2i(cell, facing): facing -1 = mirrored row
multimesh.set_instance_custom_data(i, Sprite3DSheet.instance_custom(drawn.x, flash, drawn.y, phase))
multimesh.set_instance_color(i, Sprite3DSheet.instance_color(Color.WHITE, Sprite3DSheet.ROLE_ELITE))

Directions are counted from the camera, not the world: 0 faces the camera, then clockwise as seen from above
(8 directions: 1 front-right, 2 right, 3 back-right, 4 back, 5 back-left, 6 left, 7 front-left; 4 directions:
front, right, back, left). With `mirror` only the camera-right half is drawn (8: rows front, front-right, right,
back-right, back; 4: front, right, back) and the left half is those rows flipped. One direction with `mirror`
means one row drawn facing right, flipped when the actor faces screen left.

An animation is a block of cells: `cell` is its first cell, its frames run left to right and its stored direction
rows top to bottom (cell + row * columns + frame). `d` is how many ticks (1/60 s of game time) each frame stays.
Atlas grid.
Transparent strip under the feet in every cell (px), cut off by the shader so the feet touch the ground.
World size of one source pixel; the same for every character of a game (pokebonk.com 0.074).
name -> {"cell": int, "n": int, "d": Array (ticks per frame), "loop": bool}
Degrees past a border before the direction changes, so an actor facing along a border does not flicker.
Camera-relative angle (degrees, 0..360) of a world-space facing: 0 = toward the camera, 90 = screen right.
Cameras without roll. Looking straight down, the camera's forward has no ground direction, so screen up stands in.
Directions an actor can show: `directions`, or 2 (right, flipped left) for one row with `mirror`.
Direction index for a camera-relative angle. Pass the actor's previous index to keep it until the angle is
`hysteresis` degrees past the border; -1 for a fresh pick.
The animation actually played for a name: itself, else "walk", else the first one; {} when there are none.
cell() and an actor's finished() both go through this, so they agree on what is on screen.
The cell to draw and the facing to give the shader: Vector2i(cell, 1), or Vector2i(cell, -1) for a mirrored row.
A missing animation plays resolve()'s fallback; with no animations at all, cell 0.
Frame of an animation after `tick` ticks: looping, or held on the last frame.
An animation by name, whether the dictionary was written with String or StringName keys.
Ticks an animation takes once through (for one-shots: attack, hurt). Without `d`, one tick per frame, as
frame_index() plays it.
Shader foot strip as a fraction of the cell, and the quad's world size (scale a sprite node by it).
Puts the atlas, grid and foot strip into a sprite3d, xray or ghost material.
INSTANCE_CUSTOM for a MultiMesh instance (use_instance_custom): facing is the sign from cell().
Instance colour (use_instance_color): rgb tints the sprite, alpha carries the outline role (ROLE_*), so the
default white instance colour means no outline.
Reads one character from a tools/sprite_atlas.py sheets file (JSON). The atlas path in it is relative to the file.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## sprite_check

圖集裁切、空白幀與腳底跳動檢查；素材品質驗證

適用：素材品質驗證

入口：[addons/proto_kit/sprite_check.gd](../../addons/proto_kit/sprite_check.gd) · inspection · 來源靜態引用：skybound-blades；不代表本輪已做遊戲／真人驗收

限制／副作用：唯讀像素診斷而非視覺品質保證。格子按 atlas 尺寸÷columns/rows，要求正整數 grid；並非完整 schema validator。bbox 用 alpha>0，feet 用 alpha>0.5，只有淡像素視為 empty；腳底容許差2px。動畫格序沿用 Sheet.resolve/cell fallback，鏡像相同格列去重。輸出 level/anim/dir/frame/cell/text，未提供穩定 diagnostic code；error/warn 不代表人物動作自然或材質正確。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/sprite_check.gd")
var sheet: Resource = load("res://resources/hero_sheet.tres")
var issues: Array = Capability.check_sheet(sheet)
```

### 參數、輸出與訊號

```gdscript
static func direction_name(sheet: Resource, dir: int) -> String:
static func atlas_image(sheet: Resource) -> Image:
static func cell_count(sheet: Resource) -> int:
static func cell_rect(sheet: Resource, cell: int, image_size: Vector2i) -> Rect2i:
static func cell_info(sheet: Resource, image: Image, cell: int) -> Dictionary:
static func frames(sheet: Resource, anim: StringName, dir: int) -> Array:
static func check_sheet(sheet: Resource) -> Array:
```

Checks a sprite3d_sheet against its atlas pixels: cells out of range, empty frames, art touching a cell edge
(cut in the wrong place or bleeding into the neighbour), and feet that move between the frames of one animation.
It only reads: frame order, frame sizes and the sheet itself are never changed. Used by sprite_inspector and tests.

const SpriteCheck = preload("res://addons/proto_kit/sprite_check.gd")
var image := SpriteCheck.atlas_image(sheet)                 # decompressed copy of the atlas
var info := SpriteCheck.cell_info(sheet, image, 7)          # {rect, empty, bbox, foot_y, foot_x, touches}
var issues := SpriteCheck.check_sheet(sheet)                # [{level, anim, dir, frame, cell, text}]

Pixel coordinates are inside the cell: (0, 0) is its top-left, foot_y is the lowest opaque row, the expected foot
line is cell_px - foot_px (the shader cuts the strip below it).
Alpha (0..1) above which a pixel counts as art.
Feet may differ by this many source pixels between frames of one animation before it is reported.
The atlas as an uncompressed Image, or null when the sheet has no atlas.
Cell rectangle in atlas pixels (the atlas may be larger than columns x cell_px: the grid comes from the sheet).
What is drawn in one cell. touches = sides ("left", "right", "top", "bottom") where art reaches the cell edge.
Frames of one animation in one stored direction row, in the sheet's own order: [{frame, cell, ticks, flip}].
Every problem in the sheet. level: "error" (wrong cell or empty frame) or "warn" (edge contact, foot drift).

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## sprite_inspector

可互動 sprite 檢查場景；逐幀、方向、洋蔥皮檢查

適用：逐幀、方向、洋蔥皮檢查

入口：[addons/proto_kit/sprite_inspector.gd](../../addons/proto_kit/sprite_inspector.gd) · inspection · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：唯讀開發場景，需要完整 %unique node 樹。自動發現目前只讀包含 sprite3d_sheet.gd 的 .tres 與 sheets.json，未如檔頭宣稱自動掃 .res；.res 可用 --sheet 指定。第一個 font 未驗 CJK。動畫名用空格切字，帶空格名稱有歧義；空 sheet 清單時方向鍵仍可能讀 null。預覽總是 modulo 循環且每 process 最多走一幀，不可當 one-shot/低FPS runtime 正確性證明。方向按鈕與縮圖仍 runtime 建立，待維護時改 item scene。

### 使用範例

```gdscript
godot --path prototypes/<game> res://addons/proto_kit/sprite_inspector.tscn
godot --path prototypes/<game> res://addons/proto_kit/sprite_inspector.tscn -- --sheet res://resources/sheets/leader.tres
godot --path prototypes/<game> res://addons/proto_kit/sprite_inspector.tscn -- --json res://assets/sprites/sheets.json
```

### 參數、輸出與訊號

```gdscript
var sheets: Array = []
var sheet: Resource
var image: Image
var image_size: Vector2i
var anim: StringName = &""
var dir: int = 0
var frame: int = 0
var playing: bool = true
func pick_font() -> Font:
func discover() -> Array:
func select_sheet(index: int) -> void:
func select_anim(anim_name: StringName) -> void:
func select_direction(d: int) -> void:
func set_playing(on: bool) -> void:
func step_frame(delta: int) -> void:
func show_frame(index: int) -> void:
func current_zoom() -> float:
```

Sprite animation test page (sprite_inspector.tscn): pick a sheet, an animation and a direction; play it at any
speed or step frame by frame; check cuts, wrong frames and foot jumps against the grid. Read-only: it never resizes
a character per frame, never reorders frames, never writes the sheet.

godot --path prototypes/<game> res://addons/proto_kit/sprite_inspector.tscn
godot --path prototypes/<game> res://addons/proto_kit/sprite_inspector.tscn -- --sheet res://resources/sheets/leader.tres
godot --path prototypes/<game> res://addons/proto_kit/sprite_inspector.tscn -- --json res://assets/sprites/sheets.json

Sheets come from every sprite3d_sheet .tres/.res under res:// and every sheets.json (tools/sprite_atlas.py), except
addons/ and folders with a .gdignore. Keys: Space play/pause, ←/→ frame, ↑/↓ direction, [ ] speed, O onion skin,
G grid overlays, Z zoom.
[{label, sheet}]
A font with CJK glyphs: the project's custom GUI font, else the first .ttf/.otf in the project, else a system font.
`-- --sheet <res path>` or `-- --json <res path>` puts those first.
One zoom for every frame: the chosen factor, or the factor that fits the whole cell in the view.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## sprite_inspector_atlas

sprite 檢查器的圖集子元件；由檢查場景組合

適用：由檢查場景組合

入口：[addons/proto_kit/sprite_inspector_atlas.gd](../../addons/proto_kit/sprite_inspector_atlas.gd) · internal · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：Inspector 內部 Control。需要合法正 grid、非零 image_size／控制項尺寸；GUI mouse 點擊轉圖集 cell，僅 emit index，不修正資料。公開 sheet/marks/anim_cells 由父場景持有；更新後需 queue_redraw。純檢視器，不是 atlas editor 或自動切格工具。

### 使用範例

```gdscript
# 由宿主 scene 配置此腳本；使用 vfx.library 或 sprite_inspector.tscn 入口
# 參照下方節點屬性與原始碼契約；此為場景行為，非獨立服務。
```

### 參數、輸出與訊號

```gdscript
var sheet: Resource
var image_size: Vector2i
var anim_cells: Array = []
var current_cell: int = -1
var marks: Dictionary = {}
signal cell_clicked(cell: int)
```

The whole atlas with its cell grid (as the sheet's columns x rows divide it), cell numbers, the cells the current
animation uses and the cell on screen now. Click a cell to report it (cell_clicked).
cell -> "error" or "warn": cells with problems get a coloured fill.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## sprite_inspector_frame

sprite 檢查器的單幀子元件；固定比例查看幀

適用：固定比例查看幀

入口：[addons/proto_kit/sprite_inspector_frame.gd](../../addons/proto_kit/sprite_inspector_frame.gd) · internal · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：Inspector 內部 Control。傳入合法 Sheet、image_size、cell、zoom與像素診斷；父層以同一 zoom 比較各幀，不能逐幀縮放掩蓋尺寸差異。onion_cell／grid 等直接繪製，不驗完整資料。只 emit clicked；不修改或儲存 sheet，公開資料變更後由宿主 queue_redraw。

### 使用範例

```gdscript
# 由宿主 scene 配置此腳本；使用 vfx.library 或 sprite_inspector.tscn 入口
# 參照下方節點屬性與原始碼契約；此為場景行為，非獨立服務。
```

### 參數、輸出與訊號

```gdscript
var sheet: Resource
var image_size: Vector2i
var cell: int = -1
var flip: bool = false
var zoom: float = 1.0
var onion_cell: int = -1
var onion_flip: bool = false
var info: Dictionary = {}
var reference_foot_y: int = -1
var show_cell_border: bool = true
var show_pixel_grid: bool = true
var show_foot_line: bool = true
var show_bbox: bool = true
var show_center: bool = true
var selected: bool = false
var caption: String = ""
signal clicked
func cell_origin() -> Vector2:
```

One cell of a sprite3d_sheet drawn as the shader would pick it (same cell, same mirror), at one uniform zoom for
every frame, so size and foot changes between frames stay visible. Overlays for checking cuts and feet.
Used by sprite_inspector for the big view and for the frame strip thumbnails.
Source pixels -> screen pixels. Never chosen per frame: the inspector sets one value for all frames.
Foot of the animation's first frame (cell pixels), drawn as a reference line; -1 = none.
Top-left of the cell on screen: centred in the control.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## store_front

模擬購買與獎勵廣告介面；開發測試與未來 SDK adapter

適用：開發測試與未來 SDK adapter

入口：[addons/proto_kit/store_front.gd](../../addons/proto_kit/store_front.gd) · node · 來源靜態引用：hero-horde-idle；不代表本輪已做遊戲／真人驗收

限制／副作用：場景擁有生命週期；依下方契約準備子節點與資源。每幀只能由一個時鐘推進，不可重複 auto/manual step。 只有模擬交易；正式金流、收據驗證與發獎冪等性未提供。

### 使用範例

```gdscript
# 此為測試商店，沒有真實扣款；CanvasLayer 腳本由遊戲繼承
if $Store.is_test():
    print("測試商店")
var paid: bool = await $Store.buy("gems_100") # products 必須先登記
```

### 參數、輸出與訊號

```gdscript
var products: Dictionary = {}
var test_file: String = "user://store_test.json"
var ad_seconds: float = 3.0
var busy: bool = false
func is_test() -> bool:
func buy(product_id: String) -> bool:
func restore() -> PackedStringArray:
func show_ad(placement: String, skip: bool = false) -> bool:
```

In-app purchases and rewarded ads behind one interface, so a real billing and ad SDK can replace the test store
without touching the screens. This script is the test store; make it the base of an autoload's script:
extends "res://addons/proto_kit/store_front.gd"       # scripts/store.gd
func _ready() -> void:
products = {"gems_100": CONSUMABLE, "no_ads": NON_CONSUMABLE}
super()
func _ad_card_shown(placement: String) -> void: %AdOverlay.visible = true   # the game draws its own ad card
func _ad_card_tick(seconds_left: int) -> void: %AdCount.text = "%d" % seconds_left
func _ad_card_hidden() -> void: %AdOverlay.visible = false

Screens call (a screen run without the autoload should treat every call as a success):
await Store.buy(id)               -> true when paid; the game then grants the product and saves
await Store.restore()             -> the non-consumable ids bought (恢復購買 / Restore Purchases)
await Store.show_ad(place, skip)  -> true when the ad ran to the end; skip = the player owns 免廣告, no ad shown
Store.is_test()                   -> true here: every surface that sells should say so
What a product holds, its price and name stay in the game's own data; the store only knows ids and kinds.

The test store charges nothing: buy() succeeds at once, a non-consumable is remembered in test_file (as a store
account would), and an ad is the game's card counting down ad_seconds of game time (paused time does not count).
A real backend overrides _charge, _restore_ids and _play_ad, and is_test.
Product id -> CONSUMABLE or NON_CONSUMABLE. buy() refuses ids not listed.
Where the test store remembers non-consumables bought on this device (tests point it elsewhere).
Seconds of game time a test ad runs (0 = no card; tests set it).
Set while an ad is showing; another show_ad() is refused meanwhile.
Shows a rewarded ad for `placement`; `skip` (the player owns 免廣告) gives the reward without one.
The ad card: the game shows and fills its own overlay in these.
Test backend: paid at once; a non-consumable is written to test_file.
Test backend: the card counts down ad_seconds of game time, a second at a time.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## synth

程序合成 WAV 佔位音；不依賴音效素材的原型開發

適用：不依賴音效素材的原型開發

入口：[addons/proto_kit/synth.gd](../../addons/proto_kit/synth.gd) · rule · 來源靜態引用：debt-commission、dreamling-idle、erwin-run、hero-horde-idle、luffy-marineford、madara-survivor、pachinko、pixel-monster、seal-meadow、skybound-blades、star-tide-harbor、survivor-series；不代表本輪已做遊戲／真人驗收

限制／副作用：同步生成 22050Hz、16-bit mono PCM，耗時與記憶體隨秒數／音符數線性增加；不要每個 hit 重建。click 使用新 RNG 固定 seed，不耗玩法 RNG。duration/note_dur、頻率、curve 等未驗有限與合理範圍，呼叫端須限制；to_stream 假設 bytes 已是相符 PCM 格式，不檢查長度。回新 AudioStreamWAV，不寫檔、不播放；平台聽感未在本輪驗證。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/synth.gd")
var sound: AudioStreamWAV = Capability.click(0.08, 0.4)
# 將 sound 指派給 scene 內 AudioStreamPlayer.stream
```

### 參數、輸出與訊號

```gdscript
static func ramp(freq_a: float, freq_b: float, dur: float, vol_a: float = 0.5, vol_b: float = 0.5, curve: float = 1.0) -> AudioStreamWAV:
static func click(dur: float, vol: float = 0.4, decay: float = 24.0) -> AudioStreamWAV:
static func notes(freqs: Array, note_dur: float, soft: bool = false) -> AudioStreamWAV:
static func to_stream(data: PackedByteArray) -> AudioStreamWAV:
```

Procedural placeholder audio: 16-bit mono AudioStreamWAV at 22050 Hz, no asset files.
`const Synth = preload("res://addons/proto_kit/synth.gd")`, then `player.stream = Synth.ramp(...)`.

Web exports play streams in Sample mode, which drops runtime pitch/volume control on the
player. Bake sweeps into the samples (ramp) instead of animating the player.
A sine sweep from freq_a to freq_b with a volume ramp; curve > 1 steepens the tail.
A decaying noise burst for hits and clicks. Seeded, so every call returns the same sound.
Notes played back to back, each note_dur long, with a fast attack and quadratic decay.
soft keeps pure sines; otherwise each wave is pushed toward a square for a chiptune edge.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## talent_tiers

分系天賦、前置與多套配置；長期角色成長

適用：長期角色成長

入口：[addons/proto_kit/talent_tiers.gd](../../addons/proto_kit/talent_tiers.gd) · rule · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/talent_tiers.gd")
var talents: Array[Dictionary] = [{"id": "power", "tree": "arms", "row": 0, "max_rank": 3, "effect": {"damage": 0.02}}]
var tree = Capability.new(talents)
var stats: Dictionary = tree.stats()
```

### 參數、輸出與訊號

```gdscript
var max_points: int
var row_points: int
var points_earned: int = 0
var xp: float = 0.0
var loadout: int = 0
func _init(talents: Array[Dictionary], options: Dictionary = {}) -> void:
static func run_xp(run: Dictionary, weights: Dictionary = {}, mult: float = 1.0) -> float:
func xp_to_next() -> float:
func add_xp(amount: float) -> int:
func rank(id: String) -> int:
func spent(tree: String = "") -> int:
func available() -> int:
func can_add(id: String) -> bool:
func add(id: String) -> bool:
func can_remove(id: String) -> bool:
func remove(id: String) -> bool:
func reset() -> void:
func use_loadout(index: int) -> void:
func stats() -> Dictionary:
func milestones() -> Array[String]:
func to_dict() -> Dictionary:
func from_dict(data: Dictionary) -> void:
```

Class talent trees in the classic three-tree style: a talent sits in a tree and a row, a row opens once
`row_points` points are in the rows above it in that tree, a talent may need another one maxed first, and tree
totals reach milestones (10 / 20 / 30 points) that change how spells play. Points come from talent XP earned by
runs. Removing a point is refused when it would strand a talent lower in the tree. Several loadouts; reset is free.
`const TalentTiers = preload("res://addons/proto_kit/talent_tiers.gd")`

var t := TalentTiers.new(talents, {"max_points": 51, "row_points": 5,
"milestones": {"arms": {10: "deep_wounds", 20: "sweeping", 30: "mortal_wounds"}},
"xp_curve": {"base": 80, "growth": 1.12}})
t.add_xp(TalentTiers.run_xp({"seconds": 128, "kills": 195, "bosses": 0, "victory": false}))
if t.can_add("cleave_dmg"): t.add("cleave_dmg")
var stats := t.stats()             # {"damage": 0.06, ...}: rank x per-rank effect, summed
t.milestones()                     # ["deep_wounds"]: what a spell checks to play differently

Talent: {id, tree, row (0 = top), max_rank, effect: {stat: per rank}, requires: id (that talent maxed)}.
XP for one run. weights: per second survived, per kill, per boss, for a victory; mult: the zone's difficulty.
XP needed for the next point.
Adds XP and returns how many points it earned (capped at max_points).
Takes one point back unless a talent lower in the tree, or one that requires this one, would lose its access.
Summed effects of the active loadout: rank x per-rank value.
Milestone ids reached in the active loadout, in tree and threshold order.

測試引用（存在不等於本輪已重跑）：tests/test_survivor_modules.gd

## tap_picker_3d

螢幕點選角色與地面；手機 3D 選取

適用：手機 3D 選取

入口：[addons/proto_kit/tap_picker_3d.gd](../../addons/proto_kit/tap_picker_3d.gd) · rule · 來源靜態引用：seal-meadow；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/tap_picker_3d.gd")
# 由宿主 scene 配置此腳本；使用 vfx.library 或 sprite_inspector.tscn 入口
# 參照下方節點屬性與原始碼契約；此為場景行為，非獨立服務。
```

### 參數、輸出與訊號

```gdscript
static func pick_actor(camera: Camera3D, screen: Vector2, candidates: Array, radius_px: float, aim: Callable = Callable()) -> Node3D:
static func ground(camera: Camera3D, screen: Vector2, mask: int = 1, length: float = 400.0) -> Variant:
```

Turns a screen tap into "this actor" or "this ground point" for a 3D view.
`const TapPicker3D = preload("res://addons/proto_kit/tap_picker_3d.gd")`

Actors are picked on screen, not by physics: the nearest aim point within `radius_px` wins,
so small or overlapping sprites stay tappable with a finger. Read taps in _unhandled_input,
so Controls with mouse_filter STOP (HUD buttons) swallow them first.
`candidates`: Node3D list. `aim`: Callable(node) -> Vector3 world point to measure from
(default: the node's origin). Nodes behind the camera are skipped. Returns null when none.
Ray from the tap into the physics world. Returns the hit position, or null.

測試引用（存在不等於本輪已重跑）：tests/test_m0_modules.gd

## test_kit

Godot headless 測試基底；斷言、等待與輸入模擬

適用：斷言、等待與輸入模擬

入口：[addons/proto_kit/test_kit.gd](../../addons/proto_kit/test_kit.gd) · inspection · 來源靜態引用：debt-commission、dreamling-idle、erwin-run、hero-horde-idle、horde-25d、kagura-dango、luffy-marineford、madara-survivor、seal-meadow、seichi-pov、skybound-blades、survivor-series、taskbar-hero；不代表本輪已做遊戲／真人驗收

限制／副作用：僅 SceneTree 測試 runner，不能掛遊戲 Node。註冊全域 Logger 並在 _finish 移除；收集 SCRIPT ERROR，其他錯誤與啟動前 parse error 需外層 runner 判斷。_until 使用 wall-clock timeout，等待 process_frame；不是整個程序 watchdog。_finish 在零 checks 且無錯時也會 PASS。_tap/_drag 是滑鼠事件，非多點觸控；_press 經 Input。這是工具研究，未新增或執行測試。

### 使用範例

```gdscript
extends "res://addons/proto_kit/test_kit.gd"
func _init() -> void:
    _expect(2 + 2 == 4, "arithmetic")
    _finish("EXAMPLE")
```

### 參數、輸出與訊號

```gdscript
var failures: Array[String] = []
var checks: int = 0
```

Base for headless test scripts: `godot --headless --path . --script res://tests/test_x.gd`.
`extends "res://addons/proto_kit/test_kit.gd"`, run the suite from _init (or a deferred
_run for UI tests that need the tree), then call _finish("SUITE NAME").

A SCRIPT ERROR anywhere during the run (a null access in the game or the test) counts as a failure, so a
suite whose test function died halfway never prints PASSED. Parse errors stop the script before it runs at
all, so a runner should still grep the log for "Parse Error".
Registered from the member initializer: subclasses define their own _init without calling super().
Records a failure on timeout instead of hanging the suite.
_mouse, _move, _tap and _drag push events straight into the root viewport, at
viewport coordinates. Use them for gestures on arbitrary points.
Press at from, move to to in six steps, hold, release. Covers long-press, swipe and drag.
Clicks a button the way a player does: scrolls it into view, then sends hover, down and
up through Input, so hover, focus and ScrollContainer handling all run.

測試引用（存在不等於本輪已重跑）：tests/test_capability_composition.gd, tests/test_genre_modules.gd, tests/test_m0_modules.gd, tests/test_mmo_modules.gd, tests/test_proto_kit.gd, tests/test_song_clock.gd, tests/test_survivor_modules.gd, tests/test_three_ports.gd, tests/test_vfx.gd, tests/test_vfx_library.gd

## time_control

牆上時間驅動 hit stop；集中管理 Engine.time_scale

適用：集中管理 Engine.time_scale

入口：[addons/proto_kit/time_control.gd](../../addons/proto_kit/time_control.gd) · node · 來源靜態引用：erwin-run、seal-meadow、skybound-blades、survivor-series；不代表本輪已做遊戲／真人驗收

限制／副作用：場景擁有生命週期；依下方契約準備子節點與資源。每幀只能由一個時鐘推進，不可重複 auto/manual step。 修改 Engine.time_scale，整個遊戲只設一個擁有者；離樹會重設。

### 使用範例

```gdscript
# 在 scene 中把腳本掛於 %TimeControl；只設一個擁有者
%TimeControl.hit_stop(0.06)
%TimeControl.reset()
```

### 參數、輸出與訊號

```gdscript
@export var hit_stop_scale: float = 0.05
@export var hit_stop_cooldown: float = 0.25
var clock: Callable
func hit_stop(duration: float, force: bool = false) -> void:
func reset() -> void:
```

The one place that touches Engine.time_scale: hit stops, the few frozen frames that make an impact land.
Menu pauses use tree.paused instead, so the two never fight over the same switch.
`const TimeControl = preload("res://addons/proto_kit/time_control.gd")`, or put the script on a Node of the game
scene (process_mode ALWAYS, so it keeps running while the tree is paused) and call:

time_control.hit_stop(0.06)          # an ordinary impact
time_control.hit_stop(0.2, true)     # a boss death: skips the cooldown, only ever lengthens a running stop
time_control.reset()                 # a restart, or leaving the scene

Hit stops are throttled: inside `hit_stop_cooldown` after the last one a request is ignored, so a room full of
kills does not freeze the game every frame. They run on the wall clock, not on game time: how long the freeze
lasts is what the player feels, and a slowed game clock would stretch it. Do not use this for gameplay timers.
Leaving the tree puts Engine.time_scale back to 1.
How slow the game runs during a stop (0.05 = almost frozen; 0 would stop the engine's own timers too).
Seconds after a stop ends during which an ordinary request is ignored.
Milliseconds for the rules. Empty = the wall clock. Tests set one they can move by hand.
Freezes the game (almost) for `duration` real seconds. Inside the cooldown after the last stop it
is ignored, unless `force` is set (boss death): a forced stop skips the cooldown and only ever
lengthens a stop that is still running, never shortens it.

測試引用（存在不等於本輪已重跑）：tests/test_proto_kit.gd

## ui.ui_theme

從樣式資料製作 Theme；手機 UI 版型的主題來源

適用：手機 UI 版型的主題來源

入口：[addons/proto_kit/ui/ui_theme.gd](../../addons/proto_kit/ui/ui_theme.gd) · rule · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：由固定 ui_styles.json 建立新 Theme；tokens 每次讀檔，不驗 JSON schema。unknown style 回 null，缺欄位可能直接報錯。使用 SystemFont 與系統 CJK fallback，不保證 Web 字型存在；應由消費者換成隨包字型。屬無材質圖的 UI 配方，不替代 debt-commission 已驗收和紙 PNG 介面。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/ui/ui_theme.gd")
var ids: Array = Capability.ids()
if not ids.is_empty():
    var theme: Theme = Capability.build(ids[0])
```

### 參數、輸出與訊號

```gdscript
static func tokens() -> Dictionary:
static func ids() -> Array:
static func build(style_id: String) -> Theme:
```

Texture-free themes from ui_styles.json; title/caption labels use matching type variations.
`const UiTheme = preload("res://addons/proto_kit/ui/ui_theme.gd")`
System fonts use the catalog family when installed, with CJK system fallbacks otherwise.

測試引用（存在不等於本輪已重跑）：tests/test_genre_modules.gd

## upgrade_tree

永久升級與天賦相鄰圖；購買預覽、退款與屬性加總

適用：購買預覽、退款與屬性加總

入口：[addons/proto_kit/upgrade_tree.gd](../../addons/proto_kit/upgrade_tree.gd) · rule · 來源靜態引用：dreamling-idle；不代表本輪已做遊戲／真人驗收

限制／副作用：呼叫端持有狀態；輸入 Dictionary 欄位與錯誤結果依下方原碼契約。需要 RNG 時使用專屬亂數流，不與特效共用。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/upgrade_tree.gd")
var nodes: Array[Dictionary] = [{"id": "power", "max_level": 3, "cost_base": 10.0, "effect": {"attack": 2.0}}]
var tree = Capability.new(nodes)
var result: Dictionary = tree.buy("power", 100)
# result.ok 才把遊戲貨幣設成 result.remaining
```

### 參數、輸出與訊號

```gdscript
var configuration_error: String = ""
func _init(nodes: Array[Dictionary], options: Dictionary = {}) -> void:
func cost(id: String) -> int:
func is_available(id: String) -> bool:
func can_buy(id: String, currency: int) -> bool:
func buy(id: String, currency: int) -> Dictionary:
func preview(id: String, currency: int) -> Dictionary:
func totals() -> Dictionary:
func count_bought() -> int:
func respec() -> int:
func to_dict() -> Dictionary:
func from_dict(data: Dictionary) -> void:
```

Permanent upgrades from {id, max_level, cost_base, cost_growth, adj, effect} nodes.
`const UpgradeTree = preload("res://addons/proto_kit/upgrade_tree.gd")`
Edges are undirected; a graph requires an explicit root. Costs may override each level.

測試引用（存在不等於本輪已重跑）：tests/test_genre_modules.gd

## vfx.2d.sheet_effect

2D 圖集特效場景行為；完成訊號與生命週期

適用：完成訊號與生命週期

入口：[addons/proto_kit/vfx/2d/sheet_effect.gd](../../addons/proto_kit/vfx/2d/sheet_effect.gd) · node · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：AnimatedSprite2D 保存場景的播放器。ready 時在動畫存在且非空才自動播放；無效動畫不回結構化錯誤。非 loop 完成先 emit finished 再按 free_on_finish queue_free，回池必須預先設 false；loop 由 owner 停止／釋放。使用引擎動畫時鐘，沒有 step(delta) 介面；不能與手動步進 VFX 一律等同處理。

### 使用範例

```gdscript
# 由宿主 scene 配置此腳本；使用 vfx.library 或 sprite_inspector.tscn 入口
# 參照下方節點屬性與原始碼契約；此為場景行為，非獨立服務。
```

### 參數、輸出與訊號

```gdscript
@export var play_on_ready: bool = true
@export var free_on_finish: bool = true
signal finished
```

Assign SpriteFrames in the inspector; instance this saved scene at the hit position.
Loops remain alive until the owner frees them. One-shots emit finished then free.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## vfx.3d.00gamedevs.impact_demo

命中特效展示宿主；只用於預覽

適用：只用於預覽

入口：[addons/proto_kit/vfx/3d/00gamedevs/impact_demo.gd](../../addons/proto_kit/vfx/3d/00gamedevs/impact_demo.gd) · internal · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：僅 demo：ready 對 %Impact.trigger(center UV 0.5,0.5)；不負責正式 subject mask、敵人選取或傷害。需要保存展示場景；不要把它接到遊戲取代 impact_frame。

### 使用範例

```gdscript
# 由宿主 scene 配置此腳本；使用 vfx.library 或 sprite_inspector.tscn 入口
# 參照下方節點屬性與原始碼契約；此為場景行為，非獨立服務。
```

### 參數、輸出與訊號

```gdscript
```

Preview-only bright target. The actual effect does not create host subjects.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## vfx.3d.00gamedevs.impact_frame

全畫面命中效果；中心、方向與遮罩參數

適用：中心、方向與遮罩參數

入口：[addons/proto_kit/vfx/3d/00gamedevs/impact_frame.gd](../../addons/proto_kit/vfx/3d/00gamedevs/impact_frame.gd) · node · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：場景擁有生命週期；依下方契約準備子節點與資源。每幀只能由一個時鐘推進，不可重複 auto/manual step。

### 使用範例

```gdscript
# 使用已保存的 impact frame scene
var accepted: bool = $Impact.trigger(Vector2(0.5, 0.5), Vector2.RIGHT)
```

### 參數、輸出與訊號

```gdscript
@export var auto_step: bool = true
@export_range(0.0, 1.0) var threshold: float = 0.5
@export_range(0.0, 1.0) var softness: float = 0.05
@export_range(0.0, 1.0) var stroke_length: float = 0.65
@export_range(0.0, 1.0) var ink_density: float = 0.65
@export_range(0.0, 1.0) var background_suppression: float = 0.9
@export_range(0.0, 3.0) var star_size: float = 1.0
@export_range(0.0, 3.0) var star_strength: float = 1.0
@export var subject_mask: Texture2D
var elapsed: float = 0.0
var active: bool = false
var is_finished: bool = true
var duration: float = 24.0 / 60.0
var current_pose: int = 0
signal finished
func trigger(center: Vector2 = Vector2(0.5, 0.5), attack_direction: Vector2 = Vector2.ZERO) -> bool:
func reset() -> void:
func step(delta: float) -> void:
func set_subject_mask(mask: Texture2D) -> void:
```

Native 00GameDevs impact-frame, MIT. Add to the target viewport then trigger on confirmed hits.
UV coordinates use Godot top-left origin. Optional subject_mask must match viewport/camera/occlusion.
No automatic subject selection or gameplay event binding is performed.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## vfx.3d.00gamedevs.source_effect

原生 mesh／shader 特效播放；投射物、光束與命中

適用：投射物、光束與命中

入口：[addons/proto_kit/vfx/3d/00gamedevs/source_effect.gd](../../addons/proto_kit/vfx/3d/00gamedevs/source_effect.gd) · node · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：場景擁有生命週期；依下方契約準備子節點與資源。每幀只能由一個時鐘推進，不可重複 auto/manual step。

### 使用範例

```gdscript
# 由 vfx.library 取得原生效果 scene，保留 Parts/Motion 子節點
$Effect.auto_step = false
$Effect.reset()
$Effect.step(0.016)
$Effect.stop()
```

### 參數、輸出與訊號

```gdscript
@export var auto_step: bool = true
@export var free_on_finish: bool = false
@export_range(0.25, 2.0) var speed: float = 1.0
@export_storage var effect_id: String = ""
@export_storage var burst: bool = false
@export_storage var duration: float = 5.0
@export_storage var start_duration: float = 0.35
@export_storage var end_duration: float = 0.8
@export_storage var kind: int = 0
@export_storage var variant: int = 0
var elapsed: float = 0.0
var phase: StringName = &"starting"
var is_finished: bool = false
signal finished
func reset() -> void:
func step(delta: float) -> void:
func stop() -> void:
func set_direction(direction: Vector3, travel_speed: float = 4.0) -> void:
func set_endpoints(from: Vector3, to: Vector3) -> void:
func hit(world_point: Variant = null, world_normal: Variant = null) -> void:
```

Native meshes/shaders from 00GameDevs MIT exports; no Three.js at runtime.
Saved Parts and Motion nodes remain editable in Godot.
step(dt), stop(), reset(), hit(world_point?, world_normal?), set_endpoints(a,b).
Endpoints are in the parent's coordinate space, as in the original export.
Confirmed hit only; no collision or gameplay damage is inferred by the effect.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## vfx.3d.00gamedevs.spell_indicator

地面圓形／扇形預警；手動進度與遊戲時鐘

適用：手動進度與遊戲時鐘

入口：[addons/proto_kit/vfx/3d/00gamedevs/spell_indicator.gd](../../addons/proto_kit/vfx/3d/00gamedevs/spell_indicator.gd) · node · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：XZ 地面、扇形朝 +X，旋轉根節點瞄準。auto_step=false 才由宿主 step(seconds)；manual_progress=true 只外部推進 progress，達1後仍需 step 完成0.15秒尾段，stop 是0.12秒取消淡出而非立即隱藏。finished 不區分完成／取消，不可直接當攻擊命中。借用 %Surface 材質，必須 scene-local；circle scene 已靜態確認 local，不宣稱所有副本已驗。

### 使用範例

```gdscript
# 使用已保存的 spell indicator scene；不要只 new 腳本
$Warning.auto_step = false
$Warning.manual_progress = true
$Warning.set_progress(0.5)
$Warning.stop()
```

### 參數、輸出與訊號

```gdscript
@export_range(0.25, 20.0) var radius: float = 3.0
@export_range(5.0, 360.0) var angle_degrees: float = 360.0
@export_range(0.1, 30.0) var warning_duration: float = 2.0
@export_range(0.25, 2.0) var detail: float = 1.0
@export var color: Color = Color("ff303e")
@export var manual_progress: bool = false
@export var auto_step: bool = true
@export var free_on_finish: bool = false
var progress: float = 0.0
var elapsed: float = 0.0
var is_finished: bool = false
var phase: StringName = &"active"
signal finished
func reset() -> void:
func set_progress(value: float) -> void:
func stop() -> void:
func step(delta: float) -> void:
```

Godot port of 00GameDevs createSpellIndicatorEffect (MIT).
Place on XZ ground (+X is sector centre); rotate the root to aim.
Automatic warning: reset(). Authoritative game clock: auto_step=false, step(dt).
Manual warning: manual_progress=true, set_progress(0..1). stop() cancels.
Three.js uses HSL in linear RGB; preserve its edge-colour calculation.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## vfx.3d.00gamedevs.trail_demo

拖尾展示宿主；只用於預覽

適用：只用於預覽

入口：[addons/proto_kit/vfx/3d/00gamedevs/trail_demo.gd](../../addons/proto_kit/vfx/3d/00gamedevs/trail_demo.gd) · internal · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：僅 demo：ready 將 %Weapon local base/tip 綁 %Trail，播放 %Swing 的 swing。正式遊戲由宿主綁真實武器與動畫；不要同時使用示例 Swing 控制遊戲 transform。

### 使用範例

```gdscript
# 由宿主 scene 配置此腳本；使用 vfx.library 或 sprite_inspector.tscn 入口
# 參照下方節點屬性與原始碼契約；此為場景行為，非獨立服務。
```

### 參數、輸出與訊號

```gdscript
```

Preview-only weapon motion; gameplay owners attach their real weapon instead.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## vfx.3d.00gamedevs.weapon_smear

武器拖尾；綁定真實武器的世界座標軌跡

適用：綁定真實武器的世界座標軌跡

入口：[addons/proto_kit/vfx/3d/00gamedevs/weapon_smear.gd](../../addons/proto_kit/vfx/3d/00gamedevs/weapon_smear.gd) · node · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：場景擁有生命週期；依下方契約準備子節點與資源。每幀只能由一個時鐘推進，不可重複 auto/manual step。

### 使用範例

```gdscript
# 使用已保存的 weapon smear scene
var attached: bool = $Trail.attach_weapon($Sword, Vector3.ZERO, Vector3.UP)
$Trail.stop()
```

### 參數、輸出與訊號

```gdscript
@export var auto_step: bool = true
@export var free_on_finish: bool = false
@export_range(0.25, 2.0) var speed: float = 1.0
@export_range(0.25, 1.0) var coverage: float = 1.0
@export var color: Color = Color("2878ff")
@export_range(0.25, 2.0) var detail: float = 1.0
@export_range(0.125, 1.0) var density: float = 0.5
var elapsed: float = 0.0
var is_finished: bool = false
var phase: StringName = &"active"
signal finished
func attach_weapon(weapon: Node3D, base: Vector3 = Vector3.ZERO, tip: Vector3 = Vector3.UP) -> bool:
func detach_weapon() -> void:
func reset() -> void:
func stop() -> void:
func step(delta: float) -> void:
```

00GameDevs weapon-smear, MIT. Three native shader layers, 64 world-space samples.
Attach after animation: attach_weapon(sword, Vector3.ZERO, Vector3(0,1,0)).
A stationary/unbound weapon emits nothing. stop() drains the 0.18 s history.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## vfx.3d.pixel_burst

3D 像素爆發場景 adapter；自動或手動步進

適用：自動或手動步進

入口：[addons/proto_kit/vfx/3d/pixel_burst.gd](../../addons/proto_kit/vfx/3d/pixel_burst.gd) · node · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：PixelVfx3D 的保存場景與自動 step adapter；自有遊戲時鐘時先 auto_step=false。繼承 base 的池容量、palette、座標與預熱限制，沒有額外完成事件。此 scene 的 MultiMesh 已靜態確認 resource_local_to_scene=true；仍需消費者場景／GPU 驗證。

### 使用範例

```gdscript
# 由宿主 scene 配置此腳本；使用 vfx.library 或 sprite_inspector.tscn 入口
# 參照下方節點屬性與原始碼契約；此為場景行為，非獨立服務。
```

### 參數、輸出與訊號

```gdscript
@export var auto_step: bool = true
```

Saved scene for the kit's native volumetric chunks and ground shockwaves.
fx.burst(position, 24, &"gold"); fx.ring(position, 2.0, &"cyan")
Disable auto_step when the game's own clock calls step(delta).

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## vfx.3d.sheet_effect

3D billboard 圖集特效；共用 SpriteFrames

適用：共用 SpriteFrames

入口：[addons/proto_kit/vfx/3d/sheet_effect.gd](../../addons/proto_kit/vfx/3d/sheet_effect.gd) · node · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：AnimatedSprite3D 保存場景的播放器；pixel_size 為公尺／像素。ready 可自動播放；非 loop 完成 emit finished 後預設 queue_free，池化須先 free_on_finish=false。loop 不靠完成訊號收尾。時鐘由引擎推進，無統一 manual step；billboard／材質等依保存 scene，不因腳本存在就保證每個場景配置相同。

### 使用範例

```gdscript
# 由宿主 scene 配置此腳本；使用 vfx.library 或 sprite_inspector.tscn 入口
# 參照下方節點屬性與原始碼契約；此為場景行為，非獨立服務。
```

### 參數、輸出與訊號

```gdscript
@export var play_on_ready: bool = true
@export var free_on_finish: bool = true
signal finished
```

Same SpriteFrames as 2D. pixel_size controls metres per pixel; billboard faces camera.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## vfx.gallery

特效場景瀏覽器；開發者預覽

適用：開發者預覽

入口：[addons/proto_kit/vfx/gallery.gd](../../addons/proto_kit/vfx/gallery.gd) · inspection · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：開發資產瀏覽場景，固定 %節點與 SubViewport，會刪除 holder 現有 child 再實例化。依 DETAILS.duration 排自動重播，非用 finished 判斷；若修改 SpriteFrames 個別 frame duration，估時可能不同。stop/reset/hit 以 duck typing 分流，語義未統一；weapon與impact包專屬demo。不能複製成通用遊戲效果生命週期管理器。

### 使用範例

```gdscript
# 由宿主 scene 配置此腳本；使用 vfx.library 或 sprite_inspector.tscn 入口
# 參照下方節點屬性與原始碼契約；此為場景行為，非獨立服務。
```

### 參數、輸出與訊號

```gdscript
@export_enum("2d", "3d") var dimension: String = "2d"
var effect_ids := PackedStringArray()
var selected: String = ""
var current_effect: Node
```

Developer asset browser: choose a ready scene, inspect its source, replay.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## vfx.library

以 ID 取得 2D／3D 特效場景；素材目錄入口

適用：素材目錄入口

入口：[addons/proto_kit/vfx/library.gd](../../addons/proto_kit/vfx/library.gd) · rule · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：靜態 PackedScene 目錄，EFFECTS 使用 preload，引用此腳本會建立整份靜態資源依賴；不是按需下載／lazy registry。get_scene 未知ID或dimension回null；ids 只按dimension列現有順序、不排序。DETAILS 的loop/duration是展示 metadata，不保證效果所有生命週期相同。查詢方法與載入結構已讀，未逐筆重審全部metadata／素材／授權。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/vfx/library.gd")
var ids: PackedStringArray = Capability.ids("2d")
if not ids.is_empty():
    var scene: PackedScene = Capability.get_scene(ids[0], "2d")
    if scene != null:
        add_child(scene.instantiate())
```

### 參數、輸出與訊號

```gdscript
static func get_scene(id: String, dimension: String = "2d") -> PackedScene:
static func ids(dimension: String = "2d") -> PackedStringArray:
```

Native scene catalog; original notices retained in licenses/.

測試引用（存在不等於本輪已重跑）：tests/test_three_ports.gd, tests/test_vfx_library.gd

## vfx.preview_2d

2D 特效預覽宿主；配合 gallery

適用：配合 gallery

入口：[addons/proto_kit/vfx/preview_2d.gd](../../addons/proto_kit/vfx/preview_2d.gd) · inspection · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：開發預覽 scene 專用：依賴 %NativeEffects/%Replay，ready 連 timer 並立即播放固定示例。不是通用 spawn facade，不對外回傳 gameplay 事件，不作遊戲正式自動觸發器。

### 使用範例

```gdscript
# 由宿主 scene 配置此腳本；使用 vfx.library 或 sprite_inspector.tscn 入口
# 參照下方節點屬性與原始碼契約；此為場景行為，非獨立服務。
```

### 參數、輸出與訊號

```gdscript
```



測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## vfx.preview_3d

3D 特效預覽宿主；配合 gallery

適用：配合 gallery

入口：[addons/proto_kit/vfx/preview_3d.gd](../../addons/proto_kit/vfx/preview_3d.gd) · inspection · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：開發預覽 scene 專用：依賴 %NativeEffects/%Replay，只連 timeout；首次播放依 Timer 配置。固定座標與 palette 用作展示，重複 tick 不代表回合生命週期。

### 使用範例

```gdscript
# 由宿主 scene 配置此腳本；使用 vfx.library 或 sprite_inspector.tscn 入口
# 參照下方節點屬性與原始碼契約；此為場景行為，非獨立服務。
```

### 參數、輸出與訊號

```gdscript
```



測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## vfx.sheet_frames

橫向圖集轉 SpriteFrames；2D／3D 動畫共用

適用：2D／3D 動畫共用

入口：[addons/proto_kit/vfx/sheet_frames.gd](../../addons/proto_kit/vfx/sheet_frames.gd) · rule · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：純製作 helper；只切水平單排、等寬 PNG。count 1..4096、fps 有限且正、寬可整除 count，無效回 null。回新的 SpriteFrames，但各 AtlasTexture 借用同一輸入 Texture2D，不複製像素。只建立 default 動畫，不自動存檔、不包含 pivot／多排／trim；來源管理與 ResourceSaver 由外層工具負責。

### 使用範例

```gdscript
const Capability = preload("res://addons/proto_kit/vfx/sheet_frames.gd")
var image := Image.create(32, 16, false, Image.FORMAT_RGBA8)
var texture := ImageTexture.create_from_image(image)
var frames: SpriteFrames = Capability.build(texture, 2, 12.0, false)
```

### 參數、輸出與訊號

```gdscript
static func build(texture: Texture2D, count: int, fps: float, looped: bool = false) -> SpriteFrames:
```

Horizontal PNG strip -> shared SpriteFrames for 2D and 3D.
var frames = SheetFrames.build(texture, 18, 15.0, false)
Invalid dimensions/timing return null without writing files.

測試引用（存在不等於本輪已重跑）：tests/test_vfx.gd

## vfx_gallery

2D 特效比較擷取；固定時間點輸出圖片

適用：固定時間點輸出圖片

入口：[addons/proto_kit/vfx_gallery.gd](../../addons/proto_kit/vfx_gallery.gd) · inspection · 未找到遊戲自有程式／場景的直接引用；可能經間接引用或只存在副本；不代表本輪已做遊戲／真人驗收

限制／副作用：SceneTree 像素效果截圖工具；實際按 process delta 到達四個時點後抓圖，非精準離散時間重播。最多3x3格，shader slots最多4個；extra參數須 name=path，目前未防缺等號。save_png 未查錯誤、未建父資料夾；正常退出不保證產圖。正式玩法不能依賴此工具。

### 使用範例

```gdscript
env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1600x1600x24" godot --path <project> --resolution 480x480 \
  -s res://addons/proto_kit/vfx_gallery.gd -- /tmp/vfx.png [extra shader effect names to show: name=res://x.gdshader]
```

### 參數、輸出與訊號

```gdscript
var fx: Node2D
var out: String
var time: float = 0.0
var shots: Array[Image] = []
var started: bool = false
```

Renders every PixelVfx effect (built-in shapes and every shader in `shaders`) on a plain background and saves
one PNG of four moments side by side (0.05, 0.2, 0.5 and 0.9 s), for judging effects without a game.
Renders, so run it on a virtual display, never on the user's desktop:
env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1600x1600x24" godot --path <project> --resolution 480x480 \
-s res://addons/proto_kit/vfx_gallery.gd -- /tmp/vfx.png [extra shader effect names to show: name=res://x.gdshader]
Lays the effects out on a 3×3 grid once the window has its real size.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## weighted_choice

有序浮點權重抽取；共用單一演算法並保留亂數消耗契約

適用：稀有度、寶箱、生怪與精煉使用相同嚴格邊界的抽取；不包含保底或可選資格

入口：[addons/proto_kit/weighted_choice.gd](../../addons/proto_kit/weighted_choice.gd) · rule · 本輪已由 rarity、chest_shop、run_timeline、refine_ladder 實際引用；依使用者指示暫緩重構後測試

限制／副作用：權重必須有限、非負、總和為正；非法回 -1 且不消耗 RNG。有效抽取只 randf 一次、保留順序與嚴格 < 0 邊界；sample=1 保留舊版最末項 fallback。不要替換整數 gacha 或 <= 邊界的 card_draft。

### 使用範例

```gdscript
const Choice = preload("res://addons/proto_kit/weighted_choice.gd")
var rng = RandomNumberGenerator.new()
rng.seed = 42
var ids: Array[String] = ["common", "rare"]
var index: int = Choice.sample_index([9.0, 1.0], rng)
if index >= 0:
    print(ids[index])
var deterministic: int = Choice.index_at([9.0, 1.0], 0.95) # 1
```

### 參數、輸出與訊號

```gdscript
static func sample_index(weights: Array, rng: RandomNumberGenerator) -> int:
static func index_at(weights: Array, unit_sample: float) -> int:
```

Ordered floating-weight selection shared by rarity, chests, encounter rosters and refinement.
No item IDs, currency, pity or eligibility rules: caller filters candidates and owns the RNG.
weights: finite nonnegative int/float values with a finite positive sum.
Invalid/empty/all-zero distributions return -1; sample_index does not consume RNG on rejection.
Valid sample_index consumes exactly one randf(), preserving the strict `< 0` legacy selection.
Keep order stable when replaying saves; do not replace integer gacha or inclusive card_draft draws.
Pure deterministic variant; unit_sample in [0,1]. At exactly 1 the final index is returned
(legacy endpoint fallback, including a trailing zero weight). No mutation or random draws.

測試引用（存在不等於本輪已重跑）：無直接引用；可能由場景或上層測試涵蓋，需個別驗證。

## 製作與維護工具

以下命令由 godot-kit 目錄執行；外部檔案路徑為使用者提供的輸入。

### tool.sprite_atlas

角色圖集打包

輸入：manifest.json 路徑；--out 輸出資料夾；cell_px、columns、foot_px、meters_per_px、characters 見腳本 manifest 規格

輸出：atlas.png + sheets.json；錯誤以非零退出，不靜默縮圖

限制：需要 Pillow；讀 manifest 相對圖片路徑，固定角色 scale，trim 與 canvas 對齊政策不同。直接先寫 atlas.png 再寫 sheets.json，會覆寫且不是雙檔原子提交；IO 中斷可留下不同版本。AtlasError exit1，JSON/IO/型別錯誤未統一格式。格數／尺寸有上限，但完整 schema（正 cell/columns、非空動畫、正 ticks、合法 align）未全面驗證。

```sh
uv run --with pillow tools/sprite_atlas.py manifest.json --out /tmp/hero-atlas
```

### tool.subset_font

CJK 字型子集

輸入：--project 遊戲路徑；--source 字型；--out 輸出；--weight 可選；--check 唯讀

輸出：子集字型或唯讀缺字報告；缺字 exit1，正常生成模式仍寫輸出

限制：需要 fonttools；--check 不寫檔，缺字 exit1。正常模式即使發現缺字仍會寫子集，再 exit1，非零不代表沒有產物。--skip-dir 取代預設列表，不是追加；掃描忽略讀檔／UTF-8 失敗且不驗 project 存在，空掃描不等於成功。輸出覆寫；source/out 只用 abspath 比較，不解析符號連結。保留 name records 不等於工具自動審查授權；動態文字需另補集合。

```sh
python3 tools/subset_font.py --project ../pixel-monster --source /path/font.ttf --check
```

### tool.build_web

Web 匯出與 IDBFS 補丁

輸入：遊戲目錄；--zip-name 可選；GODOT_BIN 與 FETCH_ARGS 環境變數

輸出：build/web/index.html 與 ZIP；可能部分產物，exit0不等於匯出／啟動驗收

限制：會下載模板、匯入專案、寫 build/.gdignore、覆寫 build/web 與 ZIP，非部署。主腳本只取引擎 major.minor 給 fetch helper；helper 的版本匹配需另審。export pipeline 以 || true 消化錯誤，後續以 index.html 存在繼續，不能保證所有匯出錯誤都讓 CLI 失敗；只移除舊 index.html，其他 stale build 檔可能進 ZIP。zip_name 必須是受控檔名，現行未驗路徑／空白檔名。使用專用輸出目錄，失敗可能留下部分產物。

```sh
bash tools/web/build_web.sh ../my-game --zip-name my-game-web
```

### tool.run_tests

嚴格 headless 測試執行

輸入：project；suite[:fps] 清單；GODOT_BIN、TEST_TIMEOUT

輸出：暫存目錄日誌；失敗非零；檢查 PASSED 與腳本錯誤

限制：需 timeout；先匯入後跑 suites，會執行任意遊戲測試及其 user:// 寫入，應用隔離測試存檔。suite exit0、無指定錯誤字樣且含 PASSED 才過；PASSED 子字串並非 assertion 數驗證。import 只驗 process exit／timeout，未同樣掃 import log。TEST_TIMEOUT 每次 import／suite 各計，非總時間。參數 name/fps 應受控；本輪未執行此工具。

```sh
bash tools/run_tests.sh . capability_composition
```

### tool.capture

固定影格遊戲錄影

輸入：project、output、frames 可選；-- 後傳遊戲參數；GODOT_BIN

輸出：f*.png、f.wav；有 ffmpeg 時 video.mp4

限制：需 renderer，可能開窗口並執行遊戲。會先刪 output 下 f*.png/f.wav，ffmpeg -y 覆寫 video.mp4；僅用專用錄影資料夾。固定30fps與 Compatibility renderer；畫面尺寸依遊戲 viewport，非必為 --resolution 值。ffmpeg 可選；缺少 ffmpeg 時不會更新既有 video.mp4，不能把舊影片當本次結果。WAV 參數經未引用命令展開，帶空白 output 路徑有風險。

```sh
bash tools/capture.sh ../my-game /tmp/my-game-capture 180
```

### tool.audit_copies

共用副本差異盤點

輸入：--check、--json；原型名稱或外部專案路徑

輸出：SHA-256 與差異分類；--check 發現差異 exit 1

限制：唯讀 SHA-256 來源比較，無語義或採用判定。relative project 基於 prototypes，absolute 可指外部；缺 copy 以 argparse exit2，--check 有差異 exit1，無 --check 即使 drift 仍exit0。沒有忽略規則，會包含輸出／隱藏檔；符號連結檔案可能讀到外部內容。對照結果不授權同步。

```sh
python3 tools/audit_copies.py --check --json seal-meadow
```

### tool.sync

安裝或更新共用庫副本

輸入：原型名稱或絕對路徑；--check 唯讀

輸出：目的專案 addons/proto_kit；check 差異 exit 1

限制：修改模式使用整包 rsync -a --delete，刪除目標 kit 多餘檔；不合併修改、不做備份、不檢查相容性。沒有指定 target 會更新所有已有副本，故 AI 應明列單一目標。--check 唯讀呼叫 audit_copies；需先確認目標 project.godot。相對名稱基於 prototypes，支援 absolute；不應直接改目的副本。

```sh
bash sync.sh --check seal-meadow
```

### tool.vfx_import_strip

橫向 PNG 圖集匯入

輸入：七個位置參數：res://sheet.png res://output.tres frame_count fps once|loop source_url license_note；先執行 PNG 匯入

輸出：SpriteFrames 與來源 SHA-256；非法切格拒絕

限制：需 Godot 與已匯入 PNG，僅水平等寬 strip；七個參數完整，source/license_note 只需非空，不代表授權已核實。拒絕既有 .tres 或 .source.json；先存 resource 再寫來源。來源檔開啟失敗會嘗試刪新 resource，但沒有查 store_string/close 寫入錯誤或 rollback 結果；不是 crash-safe 雙檔交易。res:// 前綴檢查不是完整路徑沙箱。

```sh
godot --headless --path . --script res://tools/vfx/import_strip.gd -- res://assets/fire.png res://assets/fire.tres 18 15 once SOURCE_URL LICENSE_NOTE
```

### tool.capabilities

能力探索、契約同步與盤點

輸入：list --query；show ID；plan ID...；build；check；inventory

輸出：JSON 契約／依賴計畫或 Markdown；check 過期 exit 1

限制：只有 build 寫生成檔；check 比較 capabilities/resources/REFERENCE，不比較 inventory.json 新鮮度，也不執行 schema.json 完整驗證。list/show/plan 重新讀取目前來源，非直接信任舊 catalog。api 是 regex 擷取，不涵蓋繼承／內部類全部 API，註解也會進靜態引用。plan 不解析 Python import、shader include 或動態載入，非安裝 manifest。build 多檔逐寫，非原子。

```sh
python3 tools/capabilities.py show fixed_step
```
