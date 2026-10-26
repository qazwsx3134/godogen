# 既有原型與共用模組盤點

盤點：2026-10-27當前工作樹。結論：**本案並非從零開始；多數系統已有基礎實作，但尚未依這份新遊戲規格整合驗收。**

先前「尚未實作」描述的是本新案的交付狀態，不能用來表示整個repo沒有相關功能。本文件補足兩個不同維度：既有程式做了什麼、本案還缺什麼。可玩原型、共用模組、局部規則與完成新案是不同狀態。

## 1. 如何解讀狀態

| 標記 | 意義 |
|---|---|
| K | kit已有獨立模組，可評估引用；不是表示已接入本案 |
| P | 其他prototype已有實際功能，需要處理依賴／規則／場景適配 |
| L | 只有相關局部能力，或遊戲規則顯著不同 |
| N | 本次盤點未找到能覆蓋本案要求的完整實作；需要新增或先做風險驗證 |

下表標記允許並存，不將「有一個檔案」換算成完成百分比。MVP／VS／Alpha是需求優先級，不是repo程式成熟度。

## 2. 最有價值的既有來源

### Taskbar Hero：最接近橫向戰鬥表現的原型

[README](../../../prototypes/taskbar-hero/README.md)與實際程式相符：已有一主角＋四怪獸出陣、怪獸EXP、付費訓練、裝備穿卸／強化、波次、行軍視差、七頁可編輯UI及v2存檔／v1遷移。

具體來源：

- [wave_arena.gd](../../../prototypes/taskbar-hero/scripts/wave_arena.gd)：清場→行軍1.15秒→下一波；每關3波；近景／遠景不同移動速度；換頁保留同一戰場。
- [combat_unit.gd](../../../prototypes/taskbar-hero/scripts/combat_unit.gd)：找最近對手、接敵、攻擊、HP、死亡與復活。
- [game.gd](../../../prototypes/taskbar-hero/autoload/game.gd)：train、equip／unequip、upgrade_equipment、toggle_deployment、monster EXP及角色屬性。
- [progression_catalog.gd](../../../prototypes/taskbar-hero/domain/progression_catalog.gd)：成長曲線、裝備槽、裝備加成與價格。
- [save_manager.gd](../../../prototypes/taskbar-hero/autoload/save_manager.gd)：格式驗證、版本、備份與異常檔案政策。
- [reference_arena.tscn](../../../prototypes/taskbar-hero/scenes/combat/reference_arena.tscn)：已保存的角色與敵方場景實例。

名稱雖是Taskbar Hero，目前產品是直式941×1672的Godot原型；**不能因此宣稱已做出桌面透明置頂小視窗。** 戰鬥HP／計時仍依場景Node管理，不能不改接就當作本案無畫面的批次／離線模擬核心。

### Skybound Blades：最值得評估的領域邏輯來源

[README](../../../prototypes/skybound-blades/README.md)及`domain/`已有純模擬、AI隊友、補血、技能、背包、裝備實例、掉落去重、倉庫、首領與保存。

- [battle.gd](../../../prototypes/skybound-blades/domain/battle.gd)：固定步進、command／event、自動選敵、坦克／補師AI、技能命中、首領預警、補給與撤退。
- [run.gd](../../../prototypes/skybound-blades/domain/run.gd)：gain_exp、kill receipt、物品消耗、裝備實例與穿戴、隊伍數值、任務獎勵及貢獻統計。
- [profile.gd](../../../prototypes/skybound-blades/domain/profile.gd)：金幣、物品、裝備存取倉庫。
- [stepper.gd](../../../prototypes/skybound-blades/domain/stepper.gd)：畫面delta轉固定步數。
- [skills.gd](../../../prototypes/skybound-blades/domain/skills.gd)：技能學習、欄位、熟練、連接與冷卻相關規則。
- [save_service.gd](../../../prototypes/skybound-blades/domain/save_service.gd)／[save_schema.gd](../../../prototypes/skybound-blades/domain/save_schema.gd)：存檔、備份、schema與永久死亡保護。

它的規則包含2D地面空間、隊長＋兩名固定職能隊友、撤退及永久死亡；本案是水平戰鬥、可收集個體與不同戰敗政策。因此應移植合適部分，不能整包照搬。

特別注意：Stepper超過`max_catch_up`時會捨棄多餘時間；這適合目前原型避免卡死，**不是本案完整的背景收益時鐘**。

### Godot Kit：已有模組，與「原型尚未採用」分開看

[kit README](../../../prototypes/godot-kit/README.md)裡的「尚未採用」指尚未接入某個prototype，並不是沒有寫程式。

| 模組 | 已有能力 | 本案差距 |
|---|---|---|
| [auto_caster.gd](../../../prototypes/godot-kit/addons/proto_kit/auto_caster.gd) | 自動施法、冷卻、選敵、DoT、暈眩、buff、吸血、優先首領 | 治療隊友、雙方陣營、治療觸發連鎖需改接；heal_ratio是依傷害自補，不能當隊友治療 |
| [upgrade_tree.gd](../../../prototypes/godot-kit/addons/proto_kit/upgrade_tree.gd) | 花貨幣升級、價格曲線、相鄰解鎖、效果預覽、加成加總、退款、序列化 | 相鄰任一可達不等於「指定前置點滿」；角色等級門檻、slot政策與交易去重要補 |
| [talent_tiers.gd](../../../prototypes/godot-kit/addons/proto_kit/talent_tiers.gd) | 點數、三系、前置、階層、方案 | 與本案金幣星圖不同，不能只換外觀視為完成 |
| [loot_ledger.gd](../../../prototypes/godot-kit/addons/proto_kit/loot_ledger.gd) | 區域解鎖、首領掉落、永久收藏、穿戴與完成度 | 現規則避免重複掉落；本案需要重複個體、UID、素材與進化 |
| [rarity.gd](../../../prototypes/godot-kit/addons/proto_kit/rarity.gd) | 卡牌稀有度權重與相關加成 | 不等於夢靈個體品階與進化規則 |
| [pet_care.gd](../../../prototypes/godot-kit/addons/proto_kit/pet_care.gd) | 寵物EXP、餵食、階段、材料配方進化 | 養成寵物不同於重複夢靈融煉，沒有本案完整容器／裝備保留交易 |
| [atomic_file.gd](../../../prototypes/godot-kit/addons/proto_kit/atomic_file.gd) | 原子檔案寫入、完整性讀回 | 業務schema、跨owner交易、receipt仍屬新遊戲責任 |
| [save_slots.gd](../../../prototypes/godot-kit/addons/proto_kit/save_slots.gd) | JSON版本、備份、逐步遷移、拒絕較新版本 | 當前工作樹新增模組；仍需本案domain validator、schema與交易一致性規格 |
| [game_clock.gd](../../../prototypes/godot-kit/addons/proto_kit/game_clock.gd) | 前景遊戲時間、失焦暫停、恢復幀、大delta上限 | 當前工作樹新增模組；預設與桌面掛機需求不同，不可直接採其失焦／截斷政策 |
| [sfx_bank.gd](../../../prototypes/godot-kit/addons/proto_kit/sfx_bank.gd)／[music.gd](../../../prototypes/godot-kit/addons/proto_kit/music.gd) | 事件聲、voice限制、音樂淡入淡出 | 要接本案事件、低打擾與失焦策略 |
| [scene_builder.gd](../../../prototypes/godot-kit/addons/proto_kit/scene_builder.gd)／[test_kit.gd](../../../prototypes/godot-kit/addons/proto_kit/test_kit.gd) | saved scene製作檢查、headless斷言／互動測試 | 本案scene、資料與驗收情境仍要製作 |

`game_clock.gd`、`save_slots.gd`及`test_m0_modules.gd`盤點時尚未追蹤於Git，本報告以工作樹版本為準；不把它們描述為已正式發布／已接入遊戲。

### 其他局部來源

- [Hero Horde Idle的push_sim.gd](../../../prototypes/hero-horde-idle/domain/push_sim.gd)已有補師選低HP比例、範圍治療、復活、光環、自動技能與各英雄戰報。其長期養成、行軍與離線在[README](../../../prototypes/hero-horde-idle/README.md)仍分為未實作規格，不能把整份v2設計當已完成。
- [Pixel Monster的time_service.gd](../../../prototypes/pixel-monster/domain/time_service.gd)已有時間高水位、上限、分段離線需求結算與休眠；[evolution_service.gd](../../../prototypes/pixel-monster/domain/evolution_service.gd)已有時間／訓練門檻、進化分支與收藏。這些是寵物照護／成長規則，不是本案的戰鬥收益模型與重複角色融煉。
- [Debt Commission的tutorial_overlay.gd](../../../prototypes/debt-commission/scripts/tutorial_overlay.gd)與[saved overlay scene](../../../prototypes/debt-commission/scenes/ui/tutorial_overlay.tscn)提供引導元件來源；引導條件與UI風格需本案重做，不沿用其他遊戲專屬外觀。

## 3. 對照本案30個系統

| 系統 | 現況 | 現有基礎 | 本案新增／改接重點 |
|---|---|---|---|
| S01 資料定義 | P／L | Taskbar UnitData／registry／catalog；Skybound tuning／schema | 統一跨系統ID、定義版本、參照／循環驗證與完整內容包 |
| S02 模擬時鐘 | P／K／L | Skybound固定步長＋Stepper；kit GameClock | 常駐失焦繼續、休眠區間、不可丟收益時間、RNG分流與唯一driver |
| S03 桌面整合 | Deferred | 2026-10-27使用者指定先不製作 | 一般Godot視窗即可進行目前玩法工作；桌面專屬能力不列入Gate |
| S04 橫向表現 | P | Taskbar波次、行軍、近遠景視差與saved actor scene | 一般視窗中的窄帶構圖、核心事件投影與本案素材 |
| S05 個體／性格 | P／L | Taskbar角色／怪獸；Hero Horde職業／稀有；Pixel寵物 | 多個同物種UID、性格、閃光、物種／種族／屬性／職業分離 |
| S06 屬性加成 | P／L | Taskbar成長＋裝備；Skybound member_stats／暫時效果 | 來源可追溯的modifier、統一乘區、預覽與build版號 |
| S07 選敵／移動 | P | Taskbar水平追打；Skybound友敵AI／補師選人 | 本案單線站位、職能與穩定平手規則 |
| S08 傷害／生命 | P | 兩原型有傷害、HP、死亡；Skybound治療與命中排程 | 統一事件raw／applied、免疫優先序、戰敗／重試政策 |
| S09 技能／冷卻 | K／P | AutoCaster；Skybound技能；Hero Horde自動治療技能 | 抽出陣營／目標契約、補血／打斷政策與事件接入 |
| S10 關鍵詞連鎖 | L／N | AutoCaster狀態／DoT；Hero Horde光環；Skybound技能連接 | 治療轉傷害等事件反應圖、cause鏈、重入／深度限制；技能連段不等於事件反應 |
| S11 編成 | P | Taskbar多怪獸出陣；其他原型隊伍／區位 | 有限解鎖slot、同UID唯一、下一遭遇整份build提交 |
| S12 種族／屬性羈絆 | L／N | Hero Horde同區職業光環 | 2／3人種族與屬性門檻、重複物種計數、最高階／累計與來源顯示 |
| S13 等級／詞綴 | P／L | Taskbar怪獸EXP與等級；Skybound成長／技能欄解鎖 | 天生詞綴生成／門檻、多級EXP、資料版本與明確分配 |
| S14 取得／Roster | L | 初始怪獸、掉落收藏；Pixel孵化取得 | 本案夢靈來源、同物種多UID、隨機個體生成、鎖定／待領 |
| S15 融煉／進化 | K／P／L | kit PetCare配方進化；Pixel階段／分支進化 | 重複個體材料交易、主體保留欄位、閃光與裝備不遺失 |
| S16 裝備 | P | Taskbar穿脫／移交／強化；Skybound裝備實例與穿戴 | 本案部位／職業限制、預覽、UID及退裝容量政策 |
| S17 背包／倉庫 | P／L | Taskbar物品管理；Skybound堆疊／裝備／倉庫存取 | 有界容量、待領箱、跨用途reservation、批次原子交易 |
| S18 掉落／經濟 | K／P | Taskbar擊殺金幣；Skybound kill receipt；LootLedger／ChestShop | 多owner獎勵原子提交、本案池與source／sink、離線共用receipt |
| S19 地圖／首領 | K／P | Taskbar關卡波次；Skybound守門者／首通任務；LootLedger區域解鎖 | 選關／刷關策略、Boss鑰匙交易、難度與完整首通政策 |
| S20 天賦星圖 | K | UpgradeTree；TalentTiers是另一種規則 | 本案前置滿級／等級門檻、上陣格、金幣交易與saved星圖UI |
| S21 工坊 | N | 原子寫檔／物品消耗／升級等底層能力可參考 | 製作配方、預留、自動選料、熟練、跨階結果與回滾整合 |
| S22 圖鑑／閃光 | K／P／L | LootLedger完成度；Pixel成熟體收藏 | 物種／屬性／職業篩選、曾獲得vs持有、閃光、進化／來源查詢 |
| S23 存檔 | K／P | AtomicFile／SaveSlots；Taskbar v1→v2；Skybound schema／bak | 本案完整schema、owner一致快照、receipt與watermark遷移 |
| S24 離線收益 | P／L／N | Pixel離線照護高水位；現有save／clock工具 | 戰鬥收益率校準、凍結build、互斥區間、滿包與領取去重 |
| S25 管理UI | P | Taskbar七頁saved UI；Skybound角色／物品列與營地面板 | 一般視窗內的戰鬥／管理IA、tooltip、篩選、preview／active區分與本案Theme |
| S26 引導 | P／L | Debt Commission overlay、教學資料與測試 | 本案角色／裝備／羈絆解鎖流程，不照搬劇情遊戲條件 |
| S27 設定 | P／L | 各原型暫停、存檔、音量／畫面設定的局部能力 | UI縮放、低打擾、動態／閃光控制與一般退出操作 |
| S28 日誌／統計 | P／L | Hero Horde戰報；Skybound輸出／治療／死因／測試工具 | 統一事件trace、金／EXP每分、build與版本分段、有界buffer |
| S29 音訊 | K／P | kit SfxBank／Music／Synth與既有原型接入 | 本案事件表、背景靜音、稀有提示與通知節流 |
| S30 長時間品質 | P／L | Taskbar 600秒模擬長跑；既有測試／效能工具 | 8小時soak、實際CPU／GPU／記憶體、睡眠與管理面板反覆開關 |

## 4. 這次實際驗證到哪裡

本次讀取相關原始碼與測試，並重跑以下7個既有測試套件，全數通過。引擎、指令、結果摘要及暫存log位置見[實測紀錄](evidence/reuse-test-results.json)。測試使用各自獨立`XDG_DATA_HOME`，未使用玩家profile。

| 專案 | 這次重跑的套件 | 結果 |
|---|---|---|
| godot-kit | genre_modules、survivor_modules、m0_modules | 3／3 PASS |
| taskbar-hero | progression_v2、waves | 2／2 PASS |
| skybound-blades | battle、run | 2／2 PASS |

原始碼盤點不等於完整code review；7套通過不代表其他所有套件或平台都通過。此次未做原生桌面透明／焦點／穿透測試，未執行8小時soak，也未驗證新案的整合。Pixel Monster、Hero Horde與Debt Commission只盤點相關程式／既有測試入口，沒有在這輪重跑它們的完整驗收。

## 5. 應如何修正實作順序

2026-10-27範圍決定：S03延期，一般Godot視窗即可開始下列適配；桌面殼不納入這輪工作。

```text
Kit共用工具 ───────────────→ 引用與本案契約測試
Taskbar橫向波次／saved scenes → 顯示層適配候選
Skybound純domain ──────────→ 模擬核心適配候選
                                  │
                                  ↓
                  單一時鐘／單一戰鬥權威的新案
                                  │
                                  ↓
                 補羈絆、反應、工坊與離線規則
```

M1先以最小接入測試判定底座：Taskbar的呈現最接近參考；Skybound的domain分離較接近本案模擬需求。兩者擇適用部分改接，不能讓Taskbar node與Skybound core同時各跑一份扣血／收益。

重用應省掉已驗證的基礎算法與工具重寫，但仍要做依賴切割、資料遷移、規則差異與整合測試。因此原roadmap保留里程碑／驗收條件，工作包改解讀為「盤點→選底座→移植／適配→補缺口」。人日需在M1接入量測後重估，現在不憑檔案數直接聲稱節省某個百分比。
