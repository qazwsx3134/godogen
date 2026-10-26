# 夢靈遠行 · Dreamling Trails

2026-10-27：第一個可玩版本，於本段落暫停開發。Godot **4.7.stable.official.5b4e0cb0f**、GDScript、Compatibility。一般單一視窗；桌面置頂、透明與特殊焦點處理延期。

接手 Agent 先讀 [Progress.md](../../Progress.md)：已完成、未完成、驗證證據、限制及續作順序集中記錄於該檔；每次 commit 或出門／下班／暫停前更新。

驗證目標：小隊自動冒險時，換人、培養、換裝與羈絆是否帶來可辨識的變化。這是小內容可玩切片，尚未完成研究規劃中的全部系統。

```text
自動戰鬥 → 金幣／EXP／裝備 → 培養／編隊／換裝
    ↑                              │
    └──────── 換關／挑戰首領 ───────┘
```

## 開啟與遊玩

在 repo 根目錄執行：

```bash
godot --path prototypes/dreamling-idle
godot --editor --path prototypes/dreamling-idle
```

開場苔角與燼尾自動作戰。覺得吃力時，在「夢靈」撤下燼尾並讓露露上陣，可得到治療與森靈生命羈絆。「培養」消耗金幣升級；「裝備」選擇持有者後穿戴；「天賦」購買「勇氣」後可開第三格「結伴」。戰敗會自動恢復並退回已通關地圖刷取資源。編隊、裝備及天賦調整於下一波套用。

已有本機 Web 匯出：`build/web/index.html`。透過 HTTP 開啟，不能直接雙擊 HTML：

```bash
python3 -m http.server 8797 --bind 127.0.0.1 --directory prototypes/dreamling-idle/build/web
```

開啟 <http://127.0.0.1:8797/>。瀏覽器資料與原生版存檔分開；同來源的 IndexedDB 保存網頁進度。測試網址 `?qa=1` 使用獨立、每次重設的 QA 檔，`?qa=1&resume=1` 讀取 QA 檔。平常遊玩不要加 QA 參數。

重建 Web（須已安裝相同版本匯出範本）：

```bash
bash prototypes/godot-kit/tools/web/build_web.sh prototypes/dreamling-idle --zip-name dreamling-trails-playable
```

輸出 `build/dreamling-trails-playable.zip`；build 為忽略的可重建產物，不進版控。

## 本版完成

- 6 種夢靈、3 種起始持有、其餘達到關卡條件後以金幣招募；2～3 格編隊。
- 6 個關卡、每關 3 波、兩場首領；自動前進／重刷、首通獎勵、團滅恢復。
- 固定 tick 水平移動、選敵、攻擊、護甲、有效治療與單次治療反應；森靈與獸靈羈絆。
- EXP、等級與付費培養；武器／防具、穿脫、鎖定、出售；36 格背包、64 格待領，兩者皆滿後暫停新增裝備。
- 6 項永久天賦、圖鑑、戰報、暫停與聲音切換（預設靜音）。
- 原子存檔、有效舊檔備份、壞檔回退與較新版本保護；每 20 秒、手動及正常退出存檔。

關閉後沒有收益。重新開啟從目前關卡第一波開始，不恢復戰鬥中 HP。報表的戰鬥貢獻為本次遊玩統計。尚未製作重複個體、進化、工坊、離線模型、完整詞綴與大量內容；六種角色暫時共用三套動作圖。未進行真人樂趣驗收、8 小時 soak、跨 OS 原生匯出或正式發行驗收。

## 編輯場景與數值

主要 scene 是可維護來源，正常開啟／匯入／測試不會重新生成。

| 路徑 | 可調整內容 |
|---|---|
| [主畫面](scenes/main.tscn) | `OuterMargin`、`BodyRows` 間距、HeaderTitle 靜態文字、頁籤與戰鬥區比例 |
| [戰鬥帶](scenes/world/battle_lane.tscn) | 背景層、裁切範圍、代表性 actor 的位置 |
| [角色](scenes/world/unit_actor.tscn) | Body 大小、名字與 Health 血條；根節點 visual_scale、friendly、display_name |
| [管理面板](scenes/panels/) | 六個頁面的 Container、文字與捲動區 |
| [重複卡片](scenes/items/) | 夢靈／裝備／地圖／天賦卡版面 |
| [Theme](scenes/theme.tres) | 字型、StyleBox、配色、字級 |
| [資料表](data/catalog.json) | 角色、關卡、裝備、天賦、容量與成長數值 |

`domain/game_model.gd` 是唯一模擬權威；`simulation_driver.gd` 每 0.05 秒推進一次，超額時間保留待處理。顯示與管理指令不自行計算掉落或攻擊。actor 移動及飄字只修改視覺節點位置。`save_repository.gd` 驗證及正規化 JSON 整數，避免首通資料於重開後失配。

共用 kit 以 `sync.sh dreamling-idle` 同步；使用 AutoCaster、UpgradeTree、AtomicFile、SceneBuilder、TestKit、SfxBank。副本不直接修改。`tools/build_scenes.gd` 是一次性製作工具，預設跳過現有 scene；重新產生前必須檢查差異、保留人工編輯。場景建立使用 Godot pack/save，檢查 owner、節點數與子 scene 參照。

## 驗證與證據

```bash
godot --headless --path prototypes/dreamling-idle --script res://tests/test_domain.gd
godot --headless --path prototypes/dreamling-idle --script res://tests/test_ui.gd -- --qa
godot --headless --path prototypes/dreamling-idle --script res://tests/test_font.gd
bash prototypes/godot-kit/sync.sh --check dreamling-idle
```

原生測試建議設定獨立 `XDG_DATA_HOME`，避免與平常遊玩資料混用。

本輪結果：domain 67 項、UI／編輯器契約 32 項、中文字型與 kit 同步檢查通過。domain 包含 600 秒模擬及 15／30／60／120 FPS 一致性、容量、反應、交易與存檔回歸；這不是實際裝置長時間效能驗證。UI 以真實 node 滑鼠事件驗證，另保存修改後的 scene，確認靜態文字與間距不會被 `_ready` 蓋掉。

[瀏覽器測試結果](evidence/web/report.json)記錄真正 canvas 滑鼠操作、編隊、培養、頁籤、IndexedDB 重開、1280×900／960×675 版面；[總覽截圖](evidence/overview.png)、[網頁截圖](evidence/web/restored.png)、各測試 log 在 [evidence](evidence/)。瀏覽器測試工具為 [browser_check.mjs](tools/browser_check.mjs)，需傳入本機 Playwright 套件與 Chromium 路徑。

下一段先由作者實玩確認養成節奏與畫面方向，再調整前 15 分鐘平衡、戰鬥辨識及專屬美術；保留進化／工坊／離線為後續工作。原始研究與完整 roadmap 見 [研究包](../../docs/research/idle-game/README.md)。素材來源見 [assets/README.md](assets/README.md)。
