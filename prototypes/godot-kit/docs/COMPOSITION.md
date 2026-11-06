# Godot 能力工具庫：組合與維護契約

本庫的組合單位是規則、資源、場景與製作工具。沿用 `addons/proto_kit/` 的直接呼叫，不增加另一套 runtime、全域 service locator 或通用事件格式。Composable Primitives 在此指「職責小、邊界清楚、可獨立驗證」，不是把所有遊戲物件拆成相同形狀。

```text
需求 → 搜尋能力 → 查契約與成熟度 → 遊戲端接線 → 對應層級驗證
                   │                  │
        ┌──────────┼─────────┐        │
        ↓          ↓         ↓        ↓
      規則       Resource   scene    CLI 製作工具
   回傳事件/值    調校資料   顯示/輸入   保存可編輯資產
```

## AI 最短使用路徑

在 repo 根目錄：

```sh
python3 prototypes/godot-kit/tools/capabilities.py list --query 存檔
python3 prototypes/godot-kit/tools/capabilities.py list --kind rule --json
python3 prototypes/godot-kit/tools/capabilities.py show save_slots
python3 prototypes/godot-kit/tools/capabilities.py show tool.sprite_atlas
python3 prototypes/godot-kit/tools/capabilities.py plan save_slots fixed_step
```

`list/show/plan/inventory/check` 唯讀；只有 `build` 更新生成檔。`show` 輸出參數宣告與預設值、回傳型別、訊號、原碼欄位說明、限制、範例及直接引用測試。方法完整原始碼仍是最終行為依據。`plan` 僅追靜態字串資源引用，可能含註解範例，無法證明動態載入完整；它不是選擇性安裝器。正式安裝沿用 `sync.sh <project>`，先用 `--check` 看副本差異。

- [人讀能力目錄](capabilities/REFERENCE.md)：逐項用途、情境、參數、輸出與範例。
- [JSON 契約](../catalog/capabilities.json)：同一份可機器查詢的資料；以 `id` 尋址。
- [資源與 shader uniforms](../catalog/resources.json)：scene、`.tres`、shader 路徑、hash、引用及 uniforms；特效圖像／授權沿用 `vfx/sources.json` 和 `three_sources.json`。
- [原型盤點](../catalog/inventory.json)：來源檔/API、靜態引用、副本 drift、逐位元組重複群。
- [盤點判斷](REUSE-AUDIT.md)：哪些值得抽取、哪些保留在遊戲內，以及原因。

## 四種呼叫方式

| 單位 | 輸入／輸出 | 所有權 | 適用 |
|---|---|---|---|
| 純規則 `RefCounted` | 明確值、Dictionary、專用 RNG → 值或事件資料 | 遊戲持有實例與結果 | 選卡、成長、固定步長、掉落 |
| 資源 `Resource` | Inspector／`.tres` → 設定資料 | 共享唯讀；需修改先 duplicate | 圖集、鏡頭演出、Theme |
| 元件 scene | exported 參數、方法、signal → 視覺／輸入 | scene tree 釋放；例外見各契約 | 特效、數字、方向遮罩 |
| 製作／驗證 CLI | 明確路徑與參數 → 檔案／報告／exit code | 呼叫端選輸出目錄 | atlas、子集字型、匯出、測試 |

內部 preview 與 inspector 子元件明確標為 `internal`；它們不承諾獨立呼叫介面。目錄範例是放入指定宿主的片段，含 `$Node` 或遊戲素材路徑者需先建對應 scene。原碼註解中的 `...` 為欄位說明，不是可直接執行的完整腳本。可直接執行的組合驗證見 `tests/test_capability_composition.gd`。

## 輸入輸出約定

新模組遵守下列規則；舊模組保留既有介面，不能把「未來規範」誤當成它已提供的保證。

- 時間採秒，毫秒名稱明寫 `_ms`；sprite sheet 的 tick 為 1/60 秒。`song_clock` 用聽覺歌曲時間，`time_control` 用牆上時間，`game_clock/fixed_step` 用遊戲時間。禁止混餵。
- 2D 螢幕向量為右 +X、下 +Y；3D 世界為 Godot 座標、公尺。`damage_numbers_3d.show_hit` 接世界座標，舊遊戲版本原為局部座標，遷移時必須確認。
- 查詢不改狀態；命令回傳是否接受或 Error；複雜命令明列結果鍵。不要假定所有 Dictionary 都有 `ok`：`save_slots.restore` 用 `error`，`card_draft.pick` 用 bool。
- 純規則不自動寫檔、不修改 UI 或套用傷害。金錢與背包由遊戲交易邊界提交，避免寶箱成功但發獎失敗造成兩邊不同步。
- 不共用玩法與裝飾 RNG。會存 RNG 狀態的物件須獨占該 RNG；抽卡與稀有度若共用流，保存責任由組合層一併處理。
- 每個 node 只由 auto 或 manual 其中一種方式推進。背景暫停、hit stop、離線補算各自明確歸屬。
- 新增序列化格式須有版本與遷移，JSON 整數讀回時顯式轉型。只序列化資料，不存 Node、Callable 或 Resource 實例。
- 保存場景與 StyleBox/Theme 是來源；生成器只用於製作期。`SceneBuilder.save_scene(root, ...)` 接手並 **free root**，呼叫端不得再操作它。

### 關鍵 Dictionary 契約

| 能力 | 輸入 | 輸出與失敗 |
|---|---|---|
| `card_draft` | cards: `{id, kind, weight?, max_level?, branch?, requires?}`；專用 RNG；options | `offer(n)` → ID Array，可能少於 n；`pick(id)` → bool；無效選擇不套用 |
| `rarity` | `roll_offer(ids, rng, luck)`；luck 0..1 | `[{id, tier}]`；`bonus(tier, kind, rng)` → damage/cooldown 比例、targets 整數 |
| `auto_caster` | spell: `{id, cooldown?, range?, damage?, target?, ...}`；targets: `{id,pos,hp,max_hp,tags}` | `step` → cast Array；hits 的 id 與 damage 由宿主套用；不直接改敵人 |
| `save_slots` | path、JSON 相容 data、version；migration 為版本 → Callable | save → Error；restore → `{data,source,error}`，error 為空/missing/corrupt/newer/migration |
| `upgrade_tree` | `{id,max_level,cost_base?,cost_growth?,costs?,adj?,effect?}` | buy → `{ok,reason,spent,remaining}`；preview 顯示 now/after/short_by；呼叫端更新貨幣 |
| `run_timeline` | duration 秒、events、rate、roster、elite、max_alive；專用 RNG | step → `{events,spawns}`；宿主建立實際敵人 |
| `fixed_step` | configure(seconds>0,max_steps>=1,retain/drop)；advance(delta>=0) | configure → Error；advance → int；backlog/dropped 秒數可查；非法輸入不變更狀態 |
| `damage_numbers_3d` | world_position:Vector3、amount:float、critical:bool | bool 表示是否顯示；小於門檻、非有限值、未進樹或沒有可用池回 false |

其他能力的 Dictionary 詳細欄位保留在逐項 reference 的原碼契約，避免另寫一套會漂移的平行說明。

## 組合配方

### 生存戰鬥

```text
fixed_step → run_timeline → 遊戲生怪
     └────→ auto_caster → 遊戲套用傷害 → damage_numbers_3d / VFX / 音效
card_draft → rarity ─────→ learn / rank_up
             └→ weighted_choice ← chest_shop / run_timeline / refine_ladder
```

`run_timeline` 只產生需求；怪物上限與現存數由遊戲回傳。判定是否命中、實際死亡與獎勵在遊戲層，視覺效果不反向決定傷害。暫停選卡時不 advance；`hit_stop` 若改全域 time_scale，要確認 delta 已被縮放，不能再乘一次。

### 放置成長與存檔

```text
fixed_step(retain) → simulation.step → progression.to_dict
                                          ↓
save_slots(version/migrations) → atomic_file → user://slot.json
```

保留 backlog 只適合有界補算；大量離線收益仍需遊戲專用聚合公式，不把數天時間直接跑數百萬步。存檔寫入失敗需由 UI 告知。Web 持久化需配套 IDBFS 匯出補丁；headless 讀回不等於瀏覽器重新開啟已驗證。

### 2.5D 角色製作

```text
角色圖片＋manifest → sprite_atlas → atlas.png＋sheets.json
                                      ↓
                             sprite3d_sheet Resource
                                ├→ sprite_check / inspector
                                └→ actor scene 或 MultiMesh
```

小量具互動角色使用 scene；大量群體共用 sheet 數學，不逐隻增加 Node。光照、尺寸與相機座標由遊戲統一。GPU／手機效能不能用 headless FPS 當證據。

## 演進規則

修改順序：來源與測試 → specs.json 的用途／限制／範例 → `capabilities.py build` → `check`。生成的 REFERENCE、capabilities.json、resources.json 不手改。inventory 是明確時間點的來源快照，`check` 不因別款遊戲日常更新而阻擋 kit；要更新盤點時跑 build 或 inventory。

- ID 與既有路徑不任意改名。可選參數加預設值；改座標、所有權、時鐘或 RNG 消耗次序視為相容性改動，需記遷移。
- 新需求先確認是否只是資料或 scene 調校；兩個真實使用者或使用者明確要求才增共用能力。
- 每項能力先有對應層級證據才宣稱驗收。`tests` 欄位僅是靜態引用，不是本輪通過證據。
- `internal/inspection` 不計入成熟 runtime 數量；copy、reference、測試通過、真人驗收分開記。
- 新抽取能力先在 kit 驗證；指定消費者遷移時再做 L2。不自動同步全部舊原型，不破壞其已調好的手感。

## 編輯器入口

`addons/proto_kit/damage_numbers_3d.tscn`：根節點調 pool_size、life、rise、jitter、height、顏色與 critical_scale；`Preview` 是可見 Label3D 子場景。字型、pixel_size、outline、billboard 在 `damage_number_3d.tscn` 調整。Preview 的個別 override 只影響該實例，所有池項目共用外觀請修改 number_scene。測試驗證 Inspector 字型修改進樹後保留、runtime 不回寫 scene。

## 加權核心的實際收斂

`rarity`、`chest_shop`、`run_timeline`、`refine_ladder` 已共用 `weighted_choice`。它只解決有序權重抽取；資格過濾、貨幣、保底、精煉失敗政策仍由上層擁有。`sample_index(weights, rng)` 給持有 RNG 的遊戲使用；`index_at(weights, unit_sample)` 給重播或外部亂數來源使用。兩者回傳索引或 -1。

有效有限非負分佈保留既有加總順序、一次 `randf` 與嚴格 `< 0` 邊界；sample 恰為 1 時仍回最末索引，包含尾端零權重，這是原有端點 fallback。全零、空、負值、非有限值現在明確拒絕且不抽 RNG：rarity 回 -1、寶箱失敗不扣款、生怪回空類型、精煉失敗結果退回 keep。這些是無效輸入行為變更，並非宣稱所有輸入都零行為差異。

`gacha` 使用 `randi_range`，`card_draft` 使用 `<= 0` 邊界，因此保留各自演算法。未為了共用而額外加一堆切換參數。此批重構後測試依使用者要求暫緩。
