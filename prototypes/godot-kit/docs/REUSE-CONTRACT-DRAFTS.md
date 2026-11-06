# 下一批能力的介面草案

以下全部是研究提出的**待實作介面**，不能 preload 或直接執行。現有可呼叫 API 仍以 [REFERENCE](capabilities/REFERENCE.md) 為準；來源與取捨見 [研究報告](REUSE-RESEARCH.md)。避免先造大框架：每次只實作一項與兩個具體 adapter 所需的欄位。

## 契約共同要求

只在資料交換／失敗邊界使用有 schema 的結果；內部小函式保留明確型別，不一律包 Dictionary。公開資料要寫出：

| 欄位 | 必須回答的問題 |
|---|---|
| inputs / outputs | 型別、必填、預設值、範圍、單位、空值含義 |
| ownership | 借用／深複製／移交；誰釋放 Node／Resource；哪些物件可修改 |
| time / space | game／real／song／UTC；seconds／ms／ticks；local／world／screen／UV |
| effects | 會不會寫檔、消耗 RNG、修改全域、發 signal、變更傳入物件 |
| lifecycle | ready 前能否呼叫、busy／cancel／reset／dispose 的意思、回呼失效處理 |
| persistence | 只有 build、完整 session 還是不可保存；schema 與 migration |
| evidence | 來源、採用者、讀取深度、驗證範圍；未知不能記成成功或零 |

錯誤碼用穩定機器識別字串，面向玩家的文案留宿主。拒絕與成功但部分交付不能都回 false。設定資料在入口驗證；無效輸入的狀態／RNG 是否保持不變須寫清楚。

## A. ValidatedSnapshotStore：有效存檔選取與提交

目前已先以 [SaveSlots 可選 validator](SAVE-SLOTS.md) 落實驗證／備份／未來版本保護；下列 codec、revision、inspect/commit 仍是未實作草案。

**用途／情境**：單人遊戲 profile／進度，主檔毀損時選有效備份，避免覆蓋較新版本。演進現有 save_slots，不新增平行存檔體系。

| 介面草案 | 輸入與輸出 |
|---|---|
| `inspect(path, schema_version, codec, validator, migrations)` | path 是單一存檔；version 為正整數；codec 負責 bytes↔envelope；validator 為純 payload 檢查；migration 逐版純轉換。回 `status, data, source, diagnostics, revision` |
| `commit(path, data, expected_revision)` | data 為經驗證的候選 snapshot；revision 由 inspect 取得，含主／備份識別。回 `ok, code, revision` |

`inspect` 不寫磁碟，data 是可獨立修改的副本；source 明確 main／backup／none。future_version 不自動降版；invalid payload 不輪替進備份。commit 成功前不對遊戲發 saved；失敗保留原有效資料，回報能否重試。revision 是本地競態偵測，**不提供跨程序鎖／跨檔交易保證**，仍限制單寫入者。

使用流程（偽碼）：

```text
r = store.inspect(profile_path, 3, json_codec, validate_profile, migrations)
if r.status == "ready":
    candidate = apply_game_command(r.data)
    result = store.commit(profile_path, candidate, r.revision)
    if result.ok: game.replace_state(candidate)
else:
    show_load_problem(r.status, r.diagnostics)
```

注意：涉及遊戲 state 與磁碟提交順序時由宿主決定耐久性需求；不能把此示例推廣成所有即時戰鬥每步都落盤。skybound tombstone、debt 多檔 import 不在這項能力內。

## B. InventoryTrial：交易預演與候選狀態

**用途／情境**：買賣、交任務、材料合成、領獎。第一階段針對 seal 的 stack／instance 語義，第二個 adapter 用 dreamling 的容量與 pending 規則確認邊界。

| 介面草案 | 輸入與輸出 |
|---|---|
| `preview(snapshot, operations, item_catalog, capacity_policy)` | snapshot 包 wallet／items 及 revision；operations 為有序 remove/add/currency 變更；回 `ok, code, candidate, changes` |
| 宿主 `commit_if_revision(candidate, expected_revision)` | 宿主持有權威狀態；僅同步且 revision 相同時替換；回 committed／conflict |

數量為正整數，金額使用遊戲定義的整數單位。definition ID 與 instance UID 分離；UID 由呼叫端先配置，preview 不生成隨機 UID。reject 不改原 snapshot，不扣錢、不消耗 RNG、不發 signal。candidate 與 changes 不借用原可變容器。

```text
trial = preview(state, [remove("bait", 1), add("fish", 1)], items, capacity)
if trial.ok and commit_if_revision(trial.candidate, state.revision):
    publish_inventory_changes(trial.changes)
```

overflow 的 pending／salvaged 是上層領獎 adapter 的 outcome，不是預設「盡量塞入」。精煉 random roll 和 receipt 提交需要宿主共同處理；不把純 trial 偽裝為跨當機 exactly-once。

## C. TouchVector：指標所有權＋可編輯搖桿

**用途／情境**：luffy／madara 浮動觸控，固定式 scene 用於 seichi 類巡覽。

- 設定：`mode=fixed|floating`、`radius_px > 0`、`deadzone ∈ [0,1)`、`enabled`。畫面位置／尺寸仍保存在 scene，而非每幀重寫。
- 輸入：單一 pointer ID、經 GUI adapter 轉成控制項 local pixels 的位置；raw OS 事件不進數學核心。
- 輸出：`changed(Vector2)`，x 右／y 下、長度 0..1；`released(reason)`，reason 至少 released／cancelled／disabled／focus_lost。
- owner：核心只借用指標值，不持有 player；scene 控制 Base／Knob。失焦、停用或隱藏釋放 pointer 並輸出零。
- GUI 遮罩與 raw input 必須經同一 enable gate；release 可重複呼叫，不得留下按住狀態。

```text
stick.changed → game.move_axis = Vector2(v.x, -v.y)  # 前進為正的遊戲
modal.opened  → stick.set_enabled(false)
modal.closed  → stick.set_enabled(true)             # 不恢復舊按住狀態
```

fixed／floating 共用向量運算，不要求共用同一套事件處理腳本。

## D. GlowBatch3D：每幀光效批次 scene

**用途／情境**：luffy／madara 大量 dot／ring／spark／puff；這是 immediate batch，不是長生命特效池。

- 資源：保存 scene 包 MultiMesh、quad、shader include、blend material；容量正整數、blend 為場景 preset；每個 scene instance 的可變渲染資源隔離。
- 建議入口：`submit(world_position, size_m, color, shape, progress=0) -> bool`。position 有限；size 正值；shape 固定枚舉；progress 0..1。scene 在邊界做 `to_local`，避免宿主假設根節點無 transform。
- `commit_frame()`：同一 owner 每幀末呼叫一次，更新 visible_count，清本幀隊列；`clear()` 立即清可見內容。
- overflow：drop-new 回 false，另暴露 submitted／drawn／dropped。不要無聲自動擴容，也不把 draw count 當 FPS 提升證據。

```text
for confirmed_hit in hits:
    glow.submit(confirmed_hit.world_position, 0.8, warm, RING, 0.2)
glow.commit_frame()
```

hit 列表由遊戲確認；光效不算傷害。持續效果應由外部 simulation 每幀提交，與 VFX finished/recycle 契約分開。

## E. StoryGraphChecks：編譯期圖結構與診斷

**用途／情境**：debt 的 DM／Parley 兩個來源先轉同一 IR，再檢查 dangling edge／不可達節點，交給遊戲 schema 檢查 opcode。先留 debt 內部，滿足第二款遊戲需求後才提升 kit。

- `check(entry_id, nodes, edges) -> diagnostics[]`，nodes 保有 source location；edges 由格式／opcode adapter 提供，不猜 Dictionary 欄位。
- diagnostic：`code, severity, source_path, line, node_id, message`；排序穩定；不改圖，不寫暫存檔、不載入遊戲場景。
- 結構 fingerprint 的欄位由 opcode schema 定義。文字 typo 可不改存檔版本，但選項 ID、跳轉與步驟位置要納入。

```text
parsed = format_adapter.parse(text, source_path)
issues = graph_checks.check(parsed.entry, parsed.nodes, parsed.edges)
issues += game_command_schema.validate(parsed.nodes, asset_catalog)
if no_errors(issues): write_compiled_story(parsed)
```

compile 與寫 pack registry 是不同操作；後者若部分失敗須回報已寫的檔案，不假稱整個 build 沒發生。

## 組合配方比新框架更有價值

```text
確認命中事件
  ├─ 數字 scene：world position／damage
  ├─ 光效 batch：world position／preset
  ├─ SfxBank：event ID（真實時間節流）
  ├─ Haptics：tier（unsupported 可忽略）
  └─ 鏡頭 owner：新增 shake sample

輸出全部屬展示；沒有任一展示回呼再次扣血或發獎勵。
```

下一批實作完成時，才把對應草案轉為 catalog 的正式參數、結果與可執行範例；不要把本頁未實作名稱登記成可用能力。
