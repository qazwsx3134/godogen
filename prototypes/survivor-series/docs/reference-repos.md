# 參考 repo 研究：四個 survivor-like 專案

2026-10-07 由子 agent 讀原始碼整理（`git clone --depth 1`），使用者提供的四個 repo。結論：**全部只借概念，不複製程式碼**。

> 主對話註記：第 6 節第 1 項說我們「沒有經驗曲線與多級升級佇列」，這是只讀規格造成的誤判。`data/progression.tres` 已有分段曲線（5 起跳、每級 +6、20 級後再 +4），`run_build.gd` 的 `pending_choices` 會依序彈出多次選卡。第 2 項「寶箱 1／3／5 次選卡」已在本輪採用；其餘列入 [TODO.md](../TODO.md) 的 T-106～T-110。
>
> 驗收（另一個 fresh-context agent，2026-10-07）：四個授權、寶箱機率（Roo `SkillManager.cs:232-247`）、另外隨機抽 3 個 file:line 引用，全部 PASS。

## 0. 先講結論

- 四個 repo 都**沒有** reroll、banish、skip（Clone 只有 `AbilityManager.cs:52` 一行註解提到 "Skip" 是跳過已擁有的起始武器）。這個缺口參考不到，只能自己設計。
- 四個 repo 都**沒有** hit stop、震屏、音效節流。我們規格的「每格合併打擊回饋」已經比它們完整，不用借。
- 四個 repo 都**沒有**用 MultiMesh、批次更新。大量敵人的效能做法，我們（每格重建空間格子）已領先；只有 Clone 的 SpatialHashGrid 值得對照。
- 真正值得借的是：經驗曲線數字、選卡池規則、寶箱掉落量變化、被動屬性清單（尤其 Curse、Luck、Amount）、刷怪的平滑插值、角色／關卡資料化、Boss 腳本。
- Clone（Unity）有 20+ 種武器／被動；Roo 的 kit 有完整局外成長與進化邏輯。進化邏輯只有 Roo 有（Clone 沒有進化）。

## 1. 總覽表

| | Capybara-Survivor | survivors-roguelike-kit (Roo) | VampireSurvivorsClone | SurvivorsStarterKit |
|---|---|---|---|---|
| 引擎／語言 | Godot 4.4（`project.godot` features）GDScript，約 1558 行 | Unity 6、C#，遊戲碼 `Assets/RGame/RoguelikeKit/Scripts/` | Unity 2021.3+、C#，`Assets/Scripts/` 約 7450 行 | Godot 4.6 C#、3D、Jolt（`project.godot:89`），1188 行 |
| 授權 | **無授權檔，不可複製程式碼**（`git ls-files` 無 LICENSE/COPYING；另外 `survivors_game.gd:20-22` 含商業歌曲 mp3） | MIT，`LICENSE:1-3` © 2026 Roo-Roo-Roo；`README.md:129-145`：第三方素材與 DOTween 要另外確認，像素與 UI 圖是 AI 生成 | MIT，`LICENSE` © 2024 Matthias Broske；`README.md:32-37` 美術 Kenney、Bonsaiheldin，字型 Noto Sans TC（素材授權另查） | MIT，`LICENCE.md:1-3` © 2023 Curtis Pelissier；`README.md` Credits 列 KayKit、Kenney、Jolt |
| 規模／可信度 | 大學數值分析課作業，3 武器 5 道具，品質低 | 完整模板（原 Asset Store 售 30 美元），最完整 | 手機向，20+ 武器，2 Boss，繁中在地化 | 起手式，4 法術、5 種敵人、設計很簡 |
| 對我們的價值 | 只有「自適應難度」概念 | 局外成長、進化、寶箱、屬性清單 | 選卡池規則、刷怪插值、撿取手感、Boss | 「玩家升級配敵人強化」概念 |

引擎相容性：兩個是 Unity（只能借概念），兩個是 Godot，但 Capybara 無授權、StarterKit 是 3D C#，也只能借概念。**四個都不建議直接複製程式碼**；下面「是否只借概念」欄一律標註。

## 2. Capybara-Survivor-GodotGame（Godot GDScript，無授權）

- 刷怪與難度（`survivors_game.gd`、`survivors_game.tscn`）：
  - 固定間隔刷（`Timer` wait_time 2.0，`.tscn:43-45`），3 色史萊姆各約 1/3 機率（`.gd:44-50`），沿 `PathFollow2D` 環形隨機點生成並用物理查詢避開障礙（`.gd:52-60`、`:131-144`，每次生成一個 `intersect_shape`，成本高）。
  - **自適應難度**：每 10 秒記一次分數（`RegresionTimer` 10 秒，`.tscn:39-41`），湊滿 5 筆做線性回歸求斜率（`.gd:172-206`），斜率 <7 不動、7–10 / 10–14 / ≥14 三段乘上傷害倍率並縮短刷怪間隔（`.gd:107-129`），≥14 還會多刷一個 14 隻方陣（`spawn_bunch_mob`，`.gd:84-103`）。Boss 出現後就不再調（`.gd:206`）。
  - 注意：README 寫「Boss 5 分鐘」「每 40 秒更新」，但程式是 `BossTimer` 240 秒（`.tscn:54-56`），x 軸用 15 秒間隔（`.gd:184`）與 10 秒計時器不一致。README 與程式有出入，不能當設計依據。
  - 只有一隻 Boss，沒有精英、沒有包圍事件。
- 經驗與選卡（`entitys/player/player.gd`、`utils/`）：
  - 升級所需經驗 ×1.3 幾何成長（`player.gd:71`），起始 20（`:53`）；寶石每顆隨機 1/2/3/10（`experience_low_drop.gd:3,12-13`）。
  - 選卡：均勻抽 3 張（`object_randomizer.gd:22-33`，`shuffle`），無權重、無 reroll；武器 3 種、道具 5 種，沒有進化。
  - **升級佇列**：吃一顆寶石跨多級時，把待選的升級排隊逐一彈出（`player.gd:29-30,60-67,101-113`；`level_up_menu.gd:54-62`）。這是唯一值得記下的做法。
- 掉落：只有經驗寶石（碰到才收，沒有磁吸、沒有合併、沒有寶箱、沒有回血）。
- 局外成長：無。
- 效能：每隻敵人 `CharacterBody2D`＋`move_and_slide`（`entitys/enemys/slime/mob.gd:25-32`），沒有物件池，死亡 `queue_free`（`:40-43`）。
- 回饋：擊退 0.2 秒計時（`mob.gd:15-17,26-28,55-57`），死亡煙霧粒子，沒有傷害數字。
- 耐玩度：單角色單地圖，3 首隨機背景音樂（`.gd:19-28`）。

## 3. survivors-roguelike-kit（Roo，Unity，MIT）

路徑簡寫：`K/` = `Assets/RGame/RoguelikeKit/Scripts/`。

- 刷怪（`K/System/Stage/StageManager.cs`、`SpawnSet.cs`）：
  - 資料是多個 `SpawnSet` 資產，每個有 `StartTime/EndTime`、`IntensityCurve`（0–1 曲線）、`BaseRatePerSecond`、權重表（`SpawnSet.cs:38-54`）。
  - **預算累加器**：每格 `rate × curve × curse × dt` 累加，滿 1 就生一隻，小數不會丟（`StageManager.cs:99-121`）。
  - 三種型態：隨機（螢幕外環形 14–16 單位，`:181-189`）、**圓環**（等角度排一圈，`:136-151,198-211`）、**密集團**（0.3 間距方陣，從一個方向衝進來，`:153-168,213-237`）（`SpawnSet.cs:17-22`）。
  - **Curse 屬性**直接乘上刷怪速度（`:108,110`）。這是玩家自選的「更難更多獎勵」旋鈕。
  - 實際資料：`Assets/RGame/RoguelikeKit/ScriptableObjects/DataSO/Level/Stages/StageSet/`，如 `BoyFairy/BoyFairy*.asset` 是 120–420 秒每 60 秒一圈 20 隻；`Fairy.asset` 等精英型約 240–720 秒每 2 分鐘 1 隻；`Slime.asset` 開局 0–10 秒 2 隻/秒、`Slime1.asset` 360–720 秒 2 隻/秒。沒有真正的 Boss。
  - 勝利條件：全部 SpawnSet 開跑完且場上清空才算贏（`StageManager.cs:177-178`），和我們「撐滿 10 分鐘」不同。
- 經驗與選卡（`K/System/Skill/SkillManager.cs`、`K/SOData/Exp/ExpConfig.cs`）：
  - 曲線線性：`100 + 50×(L-1)`（`ExpConfig.cs:15,33`），經驗乘 `Growth`（`K/Game/DropOut/Exp/Exp.cs:12`，`LevelManager.cs:26-37`）。
  - 升級選卡：可用技能均勻抽 3 張（`SkillManager.cs:193-228`），不是權重；武器、被動各 6 格上限（`:202-203`，與我們規格相同）；沒卡可選時補「錢袋」（+50 金，`:220-225`、`SkillDataSO.cs:115-124`），對應我們的滷肉飯／零錢。
  - **進化（Mix）**：攻擊技能滿級（`SkillDataSO.cs:91-106`）且對應被動技能「已擁有（等級不限）」就標成 `WaitMix`（`SkillManager.cs:102-113`），再次選到就 `MixSkill()`（`:89-92`）。**與我們規格的進化條件完全相同**。
  - **寶箱**：隨機決定給 1/3/5 個獎勵（機率 2/6、3/6、1/6，`:232-247`）；先放進「待進化」的技能（`:251-257`），再填一般升級，都沒有就補錢袋（`:269-347`）。
  - 沒有 reroll、banish、skip。
- 屬性清單（`K/SOData/Skill/SkillDataSO.cs:18-34`）：Might、Armor、HPMax、Recovery、Cooldown、Area、SkillSpeed、**Duration、Amount**、MoveSpeed、Magnet、Growth、Greed、**Curse**。比我們規格的 8 種被動多出 Amount、Duration、Recovery、SkillSpeed、Curse（我們缺 Luck；Roo 也沒有 Luck）。
- 掉落（`K/Game/DropOut/`）：
  - 敵人死亡時依 `_dropKeys` 從池子取掉落物（`BaseEnemy.cs:86-96`）。
  - 磁吸：**每顆寶石在自己的 FixedUpdate 算與玩家距離**（`IDropOut.cs:31-54`），吸力半徑 = `Magnet×0.015`（`:39`）。O(寶石數) 每格，反例。
  - 吸塵器（`SuckExp.cs:13-15`）用 `FindGameObjectsWithTag("Exp")` 全找一遍，也是反例。
  - **可破壞道具**：地圖上撒 `PropCount`（預設 15，`MapConfigSO.cs:19`、`MapManager.cs:86-105`）個箱子，被技能碰到就依機率表掉東西（`DropBox.cs:22-75`），讓玩家有繞圖的理由。
  - 寶箱：玩家碰到就開（`TreasureBox.cs:14-21`）。
- 局外成長（`K/System/PowerUp/AttributeSO.cs:12-29`、`K/UI/MainMenu/PowerUp/PowerUpAttributeUpgrade.cs:25-26`、`K/System/Save/SaveGame.cs:30-44`）：14 個屬性各自有等級與 `mRequireGold` 每級價格表；角色用金幣解鎖（`CharacterSelectConfigSO.cs:17`，`SaveGame.cs:43-44` 存解鎖旗標）；存檔 JSON。沒找到退費／重置、成就系統。
- 效能：字串 key 的物件池，`Dictionary<string, Queue<GameObject>>`（`K/../RSOFramework/Pool/PoolRuntimeSO.cs:16,86,101`）；敵人池化復活（`BaseEnemy.cs:98-104`）。最近敵人查詢是整個列表排序（`EnemySystem.cs:39-70`，O(n log n)，反例）。無空間分割。
- 回饋：受擊動畫資產（`Hit/EnemyHit.cs:41-59`）、傷害數字池化上飄 1 秒淡出（`Utility/DamagePopup.cs:44-60`）、設定裡有「顯示傷害數字」開關（`SaveGame.cs:19`）。沒有震屏、hit stop。
- 耐玩度：多角色（金幣解鎖）、多關卡（`LevelConfigSO`、`MapConfigSO` 加權地磚）、Buff 系統（燃燒、冰凍、減速，`K/System/Buff/`）、敵人狀態機（衝刺、遠程、瞬移）。

## 4. VampireSurvivorsClone（Unity，MIT）

路徑簡寫：`S/` = `Assets/Scripts/`。

- 刷怪（`S/Monsters/MonsterSpawnTable.cs`、`S/Gameplay/LevelManager.cs`、`S/Monsters/EntityManager.cs`）：
  - **三條關鍵影格曲線，t 為 0–1 的關卡進度**：刷怪速率、各敵人機率、各敵人血量加成，每段**線性插值**（`MonsterSpawnTable.cs:12-22,64-76,78-82`）。不是一分鐘一格的階梯，沒有邊界跳變。
  - 刷怪迴圈：速率 → 延遲 → 到時間才生一隻（`LevelManager.cs:59-73`），用 `Mathf.Repeat` 保留餘數（`:71`）。
  - 小 Boss 到點出現（`:75-79`），**最終 Boss 在關卡時間到時出現，殺掉才過關**（`:81-87`；`LevelBlueprint.cs:10` 預設 600 秒）。
  - 寶箱每 30 秒補 2 個（`:89-97`，`LevelBlueprint.cs:22-23`）；開局送 25 顆寶石與 1 個寶箱（`:38,40`，`LevelBlueprint.cs:24-26`）。
  - **刷怪位置依玩家移動方向加權**，背對的三邊拆分剩餘權重（`EntityManager.cs:229-272`；靜止時四邊均等 `:213-227`），讓怪總是從前方壓過來。
  - 沒有包圍事件。
- 經驗（`S/ScriptableObjects/CharacterBlueprint.cs:21-31`、`S/Character/Character.cs`）：
  - 起始 5（`Character.cs:31-32`），之後每級「增量」：Lv<10 +10、<20 +13、<30 +16、其後 +20（`CharacterBlueprint.cs:21-31`；`Character.cs:147-148`），也就是**分段線性、後期趨緩**，近似 VS。
  - **一次吃多級的處理**：用協程佇列依序執行（`Character.cs:125-155`、`CoroutineQueue.cs`），先填滿一級、彈卡、再繼續。
- 選卡（`S/Character/Abilities/AbilityManager.cs`、`Ability.cs`、`S/UI/AbilitySelectionDialog.cs`）：
  - **稀有度權重**：Common 50、Uncommon 25、Rare 15、Legendary 9、Exotic 1（`Ability.cs:91-98`）；加權抽取（`AbilityManager.cs:183-198`）。
  - **3 張，運氣機率多給第 4 張**（`:89`，`FourChance = 1 - 1/Luck`，`:213-216`）。
  - **最多 2 張是已擁有可升級的**，機率隨等級奇偶變化（`:91-97`、`OwnedChance` `:204-208`），其餘從未擁有池補；不夠再用已擁有補（`:99-111`）。
  - **被動只在相關時出現**：`RequirementsMet()` 讓「投射物速度」只在有投射武器時出現（`ProjectileSpeedAbilityUpgrade.cs:5-9`；`AOEUpgradeAbility.cs:5-9`、`KnockbackUpgradeAbility.cs:5-9`）；滿級的不再出現（`Ability.cs:79-82`）。
  - 被動實作成「對所有已註冊的同型數值欄位一次加成」（`AbilityManager.cs:61-75`；`UpgradeableValues.cs:44-57`），武器的數值欄位用反射自動註冊（`Ability.cs:45-52`）。
  - 沒進化、沒 reroll/banish/skip。
  - 沒卡可選時：從寶箱開卡就改掉物品（`Chest.cs:64-65`），從升級開則生一個保底寶箱（`AbilitySelectionDialog.cs:47-48`）。
- 掉落：
  - 經驗寶石分 1/2/10/50 四階（`ExpGem.cs:6-12`），由怪物自己的機率表決定（`Monster.cs:175-181`、`LootTable.cs:30-45`），**沒有合併**。
  - 撿取手感：掉落時彈跳（`Collectable.cs:134-148`），被收時用 EaseInBack 緩動飛向玩家，速度依距離（`:80-105`）。
  - **磁鐵**：一次收所有寶石與金幣（`Magnet.cs:5-9` → `EntityManager.cs:127-135`），並觸發背景震波（`:130`）。**炸彈**：全螢幕敵人受傷＋白閃（`:137-146`、`:157-168`，用 unscaled time）。回血 +30（`Health.cs:7-13`）。
  - 磁鐵道具存在 `magneticCollectables` 清單，只有這些會被「全收」（`Collectable.cs:41-42`）。
- 局外成長：金幣存 `PlayerPrefs`（`LevelManager.cs:100-114`），商店只能買**角色**（`Main Menu/CharacterCard.cs:99-105`、`CharacterBlueprint.cs:9-10`）。沒有永久屬性商店、成就。
- 效能：
  - 所有東西都池化：怪物、投射物、投擲物、迴力鏢、寶石、金幣、寶箱、傷害數字（`EntityManager.cs:19-37,105-108`；`S/Gameplay/Pools/` 共 10 個池，各 48 行樣板）。
  - `FastList`（`S/Utilities/FastList.cs`）存活怪物與磁吸物。
  - **SpatialHashGrid**（`S/Spatial/SpatialHashGrid.cs:62-119`）用 `QueryID` 避免重複、玩家靠近邊緣才重建（`EntityManager.cs:115-122`）。**但只用在武器找目標**（`BoomerangAbility.cs:55`、`MolotovAbility.cs:18`、`BazookaGunAbility.cs:45`）；怪物推擠仍是 `Rigidbody2D` 物理（`MeleeMonster.cs:24-29`，碰撞傷害 `:51-58`），範圍武器用 `Physics2D.OverlapCircleAll`（`GarlicAbility.cs:53`）。所以它自己也不是大量敵人的好範本。
- 回饋：白閃 0.15 秒（`Monster.cs:124-130`）、擊退速度加成乘 `sqrt(drag)`（`:100-121`）、死亡粒子（`:143-157`）、傷害數字池（`EntityManager.cs:365-375`，每次受傷一個，沒合併）。沒有震屏、hit stop、音效節流。
- 耐玩度：角色資料（HP、回復、護甲、移速、運氣、起始武器，`CharacterBlueprint.cs:11-19`）、`LevelBlueprint` 一個資產定義整關（時間、背景、武器池、怪物、Boss、刷怪表、寶箱，`LevelBlueprint.cs:6-26`）、**Boss 用技能分數加權隨機決定下一招**（`S/Monsters/BossMonster.cs:51-60`，另有衝鋒、霰彈、彈幕、手榴彈等 5 招）、多語。

## 5. SurvivorsStarterKit（Godot C# 3D，MIT）

- 刷怪（`Scripts/GameManager.cs`、`Scripts/Enemies/EnemyManager.cs`）：
  - 固定間隔每次 1 隻（`GameManager.cs:76-88`），**同屏上限 200**（`:82`）；難度完全由玩家的選擇推動（見下）。
  - 敵人在玩家周圍 30 單位圓周隨機點（`EnemyManager.cs:7,74`、`GameManager.cs:175-179`）；Boss 只能由「敵人強化卡」召喚（`EnemyManager.cs:89-91`）；無精英、無包圍。
- 經驗與選卡（`GameManager.cs`）：
  - 曲線 `round(log10(L^10 × 10) × 5)`（`:185`，近似 `50·log10(L)+5`，後期非常平緩）；**升級後經驗歸零不結轉**（`:172`，溢出就丟）。
  - **每次升級給 3 組「玩家強化＋敵人強化」配對讓玩家選一組**（`:131-150`，`Choice(Powerup, EnemyPowerup, value)`）：選一張玩家升級，同時被迫接受一個敵人變強（解鎖兵種、提升血量／傷害／移速／刷怪速率、直接召 Boss）（`EnemyManager.cs:76-108`）。每項有 `MaxCumul`／`MaxStack` 上限（`Powerup.cs:25-43`、`EnemyPowerup.cs:18-32`）。這是**風險獎勵**的機制，比 Curse 更主動。
  - 選卡後有 `Task.Delay(3000)` 的確認動畫（`:156`），手機節奏太慢，不要抄。
  - 武器只有 4 種，升級是純數值加成（`Shooting.cs:66-82`）；沒有進化、被動欄位、reroll。
- 掉落、局外成長、耐玩度：**沒有**（沒有寶石、磁吸、寶箱、商店、角色）。
- 效能：README 疑難排解寫「預設物理 50 隻就卡、換 Jolt 到約 200」；敵人是 `AnimatableBody3D` 手動移動（`Enemy.cs:85-95`）；最近敵人查詢是全列表排序（`GameManager.cs:181-183`，反例）。傷害數字池預配 50 個 Label，每次受傷一個（`UI/DamageLabelManager.cs:6-72`）。
- 回饋：受擊粒子（`Enemy.cs:138-145`）＋傷害數字上飄淡出（`DamageLabelManager.cs:68-71`）。

## 6. 對照我們規格的缺口與建議採用前 8 項

規格已有而不用借的：進化條件（與 Roo 同）、6+6 欄位（與 Roo 同）、每格合併打擊回饋、空間格子與每格重建、寶石併大顆（四個 repo 都沒有，我們領先）。

| # | 建議 | 對應規格缺口 | 來源證據 | 難度 | 借概念或程式碼 |
|---|---|---|---|---|---|
| 1 | **寫死經驗曲線＋升級佇列**：用 Clone 的分段線性（起始 5，增量 10/13/16/20，每 10 級換段），10 分鐘局大約 20–30 級可調；一次吃多級要排隊逐一彈卡，吸塵器、寶箱、大寶石不會吞掉升級 | 規格完全沒給經驗曲線數字，也沒說多級同時升的處理 | Clone `CharacterBlueprint.cs:21-31`、`Character.cs:125-155`；Capybara 佇列 `player.gd:29-30,101-113`（概念）；Roo 線性 `ExpConfig.cs:33` | 小 | 只借概念（數字自己調，不複製） |
| 2 | **寶箱開 1／3／5 個獎勵（2/6、3/6、1/6），待進化的卡優先放入**，都沒有才補金幣；且開局送一箱、固定間隔補箱 | 規格只寫「寶箱多給一次選卡」，缺變量獎勵與進化保底 | Roo `SkillManager.cs:232-257,269-347`；Clone `Chest.cs:64-65`、`LevelManager.cs:40,89-97` | 小 | 只借概念 |
| 3 | **選卡池規則**：稀有度權重（50/25/15/9/1）、每次最多 2 張已擁有＋其餘新卡、**被動只在有相關武器時出現**、運氣決定第 4 張選項；順便把「選項不夠時補滷肉飯／零錢」保留 | 規格只寫「進化卡一定出現」，沒有一般卡的權重、已擁有／新卡比例、被動相關性、reroll 之外的「運氣」旋鈕 | Clone `Ability.cs:91-98`、`AbilityManager.cs:80-120,183-216`、`ProjectileSpeedAbilityUpgrade.cs:5-9` | 中 | 只借概念（Clone 是 MIT，但綁 Unity 反射式註冊，不適合照搬） |
| 4 | **補齊被動屬性：Amount（+投射物數）、Recovery（回血）、Luck（見 #3）、Curse（刷怪速度×、金幣與經驗×）、Duration** | 規格 8 種被動沒有 Amount、Recovery、Luck、Curse；「割草爽」的核心旋鈕之一就是 Amount，Curse 是高耐玩度的可選難度 | Roo `SkillDataSO.cs:18-34`、`StageManager.cs:108-110`、`AttributeSO.cs:12-29` | 中（Amount 要每個武器各自定義怎麼加） | 只借概念 |
| 5 | **刷怪管線**：把「每分鐘一段」改成「關鍵影格＋線性插值」避免分界跳變；用預算累加器保留小數刷怪；刷怪邊依玩家移動方向加權；包圍用「等角度圓環」、衝擊用「0.3 間距方陣團」 | 規格寫 `spawn_schedule.tres` 每分鐘一段與包圍圈，但沒有段間平滑、小數速率、位置策略 | Clone `MonsterSpawnTable.cs:12-22,64-82`、`EntityManager.cs:229-272`；Roo `StageManager.cs:99-121,136-168,198-237` | 小到中 | 只借概念 |
| 6 | **撿取手感包**：開局撒一批寶石教玩家磁吸；寶石掉落彈跳＋緩動飛向玩家；吸塵器全收＋全螢幕白閃／震波；炸彈（鞭炮）全螢幕傷害；**地圖散布可破壞道具掉落物**，鼓勵玩家繞過 1104×1584 的街區 | 規格有吸塵器但沒寫手感與開局引導；街區變大後缺少移動動機 | Clone `LevelManager.cs:38`、`Collectable.cs:80-105,134-148`、`EntityManager.cs:127-146,157-168`；Roo `DropBox.cs:22-75`、`MapManager.cs:86-105` | 小到中 | 只借概念。**不要抄 Roo 的每顆寶石每格算距離與 `FindGameObjectsWithTag`（`IDropOut.cs:31-54`、`SuckExp.cs:13`）**，我們的格子查詢更好 |
| 7 | **角色與關卡資料化**：角色＝起始武器＋HP／回復／護甲／移速／運氣＋金幣價格；關卡＝一個資源檔（時間、背景、武器池、怪物表、刷怪曲線、Boss、寶箱頻率）；金幣解鎖。這是**耐玩度最大的缺口**（目前單角色單地圖） | 規格「範圍」只有單一街區、單一角色（拳頭起始） | Clone `CharacterBlueprint.cs:9-19`、`LevelBlueprint.cs:6-26`、`CharacterCard.cs:99-105`；Roo `CharacterSelectConfigSO.cs:17`、`SaveGame.cs:43-44` | 大 | 只借概念（我們已有 `.tres` 與 AtomicFile 存檔，結構自然對得上） |
| 8 | **小 Boss 與最終 Boss**：到時間出現；Boss 用「各招分數加權」決定下一招；最終 Boss 在 10:00 出現、殺掉才算贏（取代或疊加「撐完」）。可用「臭臭胖子」做第一隻小 Boss | 規格只有精英與下班尖峰，沒有 Boss，缺少局內高潮與一局的「終點感」 | Clone `LevelManager.cs:75-87`、`BossMonster.cs:51-60` | 中 | 只借概念 |

### 值得一提但沒進前 8

- **玩家升級配敵人強化的風險獎勵**（StarterKit `GameManager.cs:131-173`）：很有 roguelike 味道，但每次升級都強迫接受敵人強化，與 VS 的爽快節奏衝突，且手機上決策負擔重。建議只做成**可選難度**（Curse 屬性或局前選「詛咒等級」）。
- **自適應難度**（Capybara `survivors_game.gd:107-206`）：用分數斜率調難度，概念可用「擊殺速率／血量比」做橡皮筋，但 repo 無授權、README 與程式矛盾、閾值寫死（7/10/14），不建議採用。
- **傷害數字開關**（Roo `SaveGame.cs:19`）：手機可選擇關閉，小工作，建議順手做。
- **reroll、banish、skip**：四個 repo 都沒有，沒有可參考的做法，需要我們自己設計（建議由局外商店提供次數，並放在 #3 的卡池規則旁邊一起設計）。

### 不要抄的反例

- Capybara：每次生成都跑物理查詢（`survivors_game.gd:131-144`）、無池化、無授權。
- Roo：磁吸每寶石自己算（`IDropOut.cs:31-54`）、最近敵人整表排序（`EnemySystem.cs:39-70`）、用 tag 全場搜尋（`SuckExp.cs:13`）。
- Clone：怪物走 `Rigidbody2D` 物理推擠（`MeleeMonster.cs:24-29`）、空間格子只給武器找目標用（所以不是大量敵人的效能範本）。
- StarterKit：全列表排序找最近敵人（`GameManager.cs:181-183`）、物理引擎撐 200 隻上限（README 疑難排解）。

## 7. 限制與說明

- 沒有實際執行任何 repo（Unity 專案無法在此環境開啟，Capybara 另附帶預先匯出的 web build 但未測）；全部依原始碼閱讀。
- Roo 的刷怪資料（`.asset`）是 YAML，我只讀了開始／結束時間、型態、速率，沒有逐一核對敵人種類。
- 沒有檢查各 repo 內美術、音效、字型的授權細節，使用素材前要另查。
- 授權欄：Capybara 沒有授權檔，不可複製程式碼；其他三個是 MIT，**程式碼可複製但需保留版權聲明**。因為語言與引擎（Unity/C#、3D C#）都不能直接用，上表一律標「只借概念」。
