# Godot 架構提案

本文件全為P。沿用repo kit的Godot 4.7／GDScript作候選基準；新遊戲尚未建專案，須在M1釘選實際引擎版本及renderer。不能由截圖推斷原作用Godot。

既有實作基線：Taskbar Hero的橫向波次與saved scenes、Skybound Blades的純domain／隊友戰鬥可作適配候選；逐系統程式證據與差距見[重用盤點](reuse-audit.md)。本文件描述目標分工，不表示這些基礎不存在。

## 1. 核心分工

```text
          已存檔的Control／Node2D scenes（一般視窗內）
             │ command                 ↑ 投影／事件
             ↓                         │
       Application：交易協調、換關、獎勵、存檔快照
             │                         ↑
             ↓                         │
       Domain：時鐘、戰鬥、屬性、隊伍、經濟、養成
             │                         ↑
             └──── Definition資料＋可序列化State ───┘

       Save Adapter／Audio Adapter
       分別處理檔案與聲音，不成為戰鬥權威
```

Domain以型別化GDScript與RefCounted為主，不要求Sprite／Timer／視窗存在才能算一場戰鬥。資料定義用Resource方便Inspector維護；執行狀態另持有，禁止戰鬥直接改共享`.tres`。UI送command、讀view model；上層composition root連接signal。這是本案架構選擇，符合官方鼓勵的自足scene與由上層提供依賴的方向。[Godot Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)

## 2. 可編輯的scene交付

```text
main.tscn（Control，組裝服務與一般視窗畫面）
├─ SimulationDriver（Node，唯一模擬推進者）
├─ BattleStrip（Control，battle_strip.tscn）
│  ├─ World（Node2D，battle_lane.tscn）
│  │  ├─ BackgroundLayers／Ground／SpawnMarkers
│  │  ├─ Actors（代表性友方／敵方scene instance）
│  │  └─ FxLayer
│  └─ HUD（Control，血條／區域名／管理入口）
├─ Management（Control，management_panel.tscn）
│  └─ MarginContainer／VBoxContainer
│     ├─ Header／Tabs
│     ├─ Content（saved panel scenes）
│     └─ Summary／Feedback
└─ Audio（Node，音樂與有限voice的scene）
```

這是scene清單提案，尚未有這些檔案。主要panel包括character_sheet、formation、inventory、equipment、map、talent_graph、workshop、codex、settings、offline_summary；重複物件包括unit_actor、unit_card、item_slot、talent_node、stage_row、recipe_slot、tooltip、toast、damage_number。

每個主要scene在編輯器未執行時有可見版面、靜態文字、Theme及代表性物件。容器與anchor負責UI幾何；腳本用 `%UniqueName` 取得子節點並連signal。戰鬥actor的移動屬於runtime位置，與UI排版規則不同。

新建／大改scene以Godot編輯器或一次性工具的`PackedScene.pack()`＋`ResourceSaver.save()`保存；驗證owner、子scene instance關係與存前後node數；正常執行不自動重建scene。README要列可調欄位，並驗證手改間距後執行仍保留。編輯器預覽狀態不可寫回玩家存檔或原始scene。

## 3. 目前的視窗範圍

2026-10-27使用者指定桌面置頂／透明／焦點管理先不製作。S03標為Deferred，不排入M1～M6。畫面採單一一般Godot視窗，戰鬥帶與管理面板在同一視窗內，以Control與saved scenes組成。

本階段不建立DesktopHost；桌面穿透、原生多視窗、工作區吸附與多螢幕位置管理一併留在S03。一般UI仍需可縮放、可關閉管理面板與正常退出。

一般視窗可先驗證橫向戰鬥、養成、編成與收益循環；關閉管理面板不重建戰鬥或增加driver。開關遊戲及睡眠期間的時間政策由S02／S24定義。

遊玩載體及匯出目標可隨原型選擇；桌面特殊能力不列入當前平台承諾或驗收門檻。

## 4. 模擬、動畫與事件順序

建議原型以20Hz固定模擬步長測試，畫面30fps起；兩者均為待量測P。一個driver累積單調時間並依次執行tick；UI更新、視窗數量與動畫幀率都不能增加收益。休眠／超大delta交由catch-up policy處理，禁止一口氣逐幀重播幾小時。

```text
Tick開始 → 接收合法command → 套用上一tick的build快照
     → 移動／選敵 → 準備技能與攻擊 → 依穩定順序結算效果
     → 有上限的反應佇列 → 死亡／勝敗 → 去重獎勵 → 發送投影
```

同tick順序須記錄`tick、phase、source_id、sequence`。例如HP到0立即標記不可成為新技能目標，死亡事件在該次效果後結算；是否允許救起等規則由GDD定義。動畫只消費事件，不能再透過動畫call track扣第二次血。RNG分combat、loot、cosmetic；增加特效粒子不改掉率。

UI編輯隊伍／裝備時建立待提交build；戰鬥只在安全邊界（原型先用下一遭遇）接受整份快照，避免半套羈絆與半套裝備。詳細屬性頁同時顯示「編輯預覽」及「目前戰鬥生效」以免玩家誤解。

## 5. 資料擁有者與契約

| 擁有者 | 核心資料 | 必要介面／事件（提案） |
|---|---|---|
| ContentRegistry S01 | Unit／Skill／Effect／Item／Stage／Recipe／Talent定義 | `validate_catalog`、ID查詢、content_version |
| Simulation S02／S08 | tick、RNG、actor HP／位置／冷卻、遭遇狀態 | `advance_ticks`、CombatEvent、EncounterEnded |
| Roster S05／S14／S15 | 每隻夢靈UID、種族ID、性格、稀有、閃光、等級 | AcquireUnit／EvolveUnit、RosterChanged |
| Build S06／S11／S12／S16／S20 | 位置、裝備引用、modifier來源、隊伍build版本 | PreviewBuild／CommitBuild、BuildCommitted |
| Inventory S17／S18／S21 | item UID／堆疊、容器、金幣帳本、製作預留 | PlanTransaction／CommitTransaction、TransactionCommitted |
| Progression S13／S19／S22／S26 | 等級、關卡解鎖、收藏旗標、教學步驟 | GrantXp／CompleteStage、ProgressChanged |
| Persistence S23／S24 | 存檔版本、快照revision、收益cursor、離線receipt | SaveSnapshot／ReconcileOffline、SnapshotSaved |

S18是獎勵交易協調者，不自行成為第二套角色或物品資料庫；領取時透過Application一次更新各owner後保存同一revision。S23序列化這些owner，戰鬥等domain不反向呼叫存檔工具。

## 6. 交易與存檔

背包移動、換裝、進化、製作、領獎都使用驗證→預留／計畫→一次提交的流程。單機同步交易即可先落地，不先建伺服器。每筆有command_id；相同請求重送回傳既有結果。禁止「先扣錢、稍後才發現背包滿」而沒有回滾。

快照包括schema/content版本、全局state_revision、各owner資料、收益watermark與已處理離線receipt。任何獎勵的狀態與receipt同一份原子快照保存；沒有必要先加一個獨立資料庫。進程中途退出時，要能回到同一合法revision。

## 7. godot-kit對照

| 現有模組 | 本案使用判斷 |
|---|---|
| `atomic_file.gd` | 可重用底層原子寫檔；schema、交易與離線去重仍由新遊戲負責 |
| `save_slots.gd` | 工作樹已有版本化JSON、bak與逐步遷移，相關測試通過；仍需本案schema驗證與業務交易整合 |
| `game_clock.gd` | 工作樹已有前景時鐘；預設失焦暫停且截斷大delta，與桌面掛機收益需求不同，須改政策或另作適配 |
| `test_kit.gd`、`scene_builder.gd`、`font_check.gd` | 可直接作測試／製作工具候選；scene工具只在製作時執行 |
| `upgrade_tree.gd` | 有相鄰解鎖、成本、預覽與退款，可評估天賦；需核對是否支援本案所有前置與等級門檻 |
| `auto_caster.gd` | 借鏡冷卻、目標與效果資料；現版為survivors語意，未證明支援隊友治療、雙方陣營與反應連鎖，先做適配測試 |
| `rarity.gd` | 現版卡牌稀有度不等同角色品階／進化；不可直接沿用數值語意 |
| `loot_ledger.gd` | 現版避免重複掉落；本案需要重複角色，不能直接套原規則 |
| `talent_tiers.gd` | 三系點數天賦不同於畫面中的星圖金幣解鎖；不作預設依賴 |
| `sfx_bank.gd`、`music.gd` | 可作聲音路由候選；背景模式預設低打擾 |
| `sprite_inspector.tscn`、`pixel_vfx.gd` | 可檢查角色圖與效果預算；不是本作已採用的結論 |
| kit手機直式UI layouts | 結構可參考，一般視窗的橫向戰鬥與管理面板需自己的saved scenes與Theme |

依據：[kit README](../../../prototypes/godot-kit/README.md)、[Godot實務摘要](../../../prototypes/godot-kit/GODOT_BEST_PRACTICES.md)。真正實作時才sync到指定遊戲，副本不直接修改，不全量同步其他原型。

## 8. 最早必做的技術驗證

一般視窗中的單一模擬、管理面板開關不重置戰鬥、改渲染fps不改收益、存檔中斷回復、重複請求去重、連鎖事件上限，以及編輯器手改scene仍保留。CPU／GPU與記憶體預算見S30；此文件沒有宣稱已量測通過。
