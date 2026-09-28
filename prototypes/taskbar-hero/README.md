# Taskbar Hero：遠征紀事

Godot 4.7 / GDScript / Compatibility 直式放置 RPG 原型。設計畫布 941 × 1672，等比縮放。UI 依使用者圖稿製作為可編輯 scene、node、文字與按鈕；完整 MVP 與逐像素 1:1 美術驗收尚未完成。

## 開啟與編輯

```bash
godot --editor --path prototypes/taskbar-hero
godot --path prototypes/taskbar-hero
```

匯入 `project.godot` 後開啟 `main.tscn`。進入遊戲先顯示總覽，底部六格依序為訓練、背包、怪獸、裝備、冒險、商店。左上頭像返回總覽，齒輪提供暫停／繼續與儲存。所有展開頁面共用面板範圍 y=525～1520；總覽保留較大的戰場。

| 編輯入口 | 內容 |
| --- | --- |
| `main.tscn` | 七頁實例、頂欄、提示與設定 |
| `scenes/pages/*.tscn` | 每頁原生 Control、GridContainer、ScrollContainer 與 BattleSocket |
| `scenes/components/*.tscn` | 導覽、訓練列、物品卡、裝備格等重用元件 |
| `scenes/combat/reference_arena.tscn` | 主角、四隻怪獸與三名敵人的出生位置 |
| `scenes/combat/party_unit.tscn` | 可切換角色外觀、血條與傷害文字 |
| `domain/progression_catalog.gd` | 成長、裝備與費用資料 |
| `ui/reference_theme.tres` | Noto Sans CJK TC 字型與共用樣式 |
| `assets/atlas/` | 原圖 AtlasTexture 素材區域 |

正常啟動不建立或覆寫 scene。`tools/build_reference_ui.gd` 與 `tools/build_party_scenes.gd` 是一次性作者工具，透過 Godot 打包存檔；人工調整後不要任意重跑。舊 `tools/build_scenes.gd`、`scenes/ui/` 是歷史基線。

## 玩法

- 訓練每點一次支付金幣、立即提升一級，只影響主角。
- 背包用 GridContainer 緊密排列，分類隱藏物品後自動補位。
- 四種怪獸可同時出陣；選取檢視與出陣名單分開。出陣怪獸每次擊倒敵人獲得 12 EXP，能力由自己的等級及裝備計算。
- 裝備可穿戴、卸下與付費強化；同一物品只有一名持有者，相容裝備移交時會自動清除原持有者欄位。
- 每波三名敵人，每關三波。整波清除後，隊伍快速前進 1.15 秒；近景向後移得快、遠景移得慢，接著生成下一波。第二波使用士兵外觀。
- 切頁保留同一戰場、生命、波次與行軍進度；暫停也會停止視差。主角與怪獸陣亡後復活，敵人須等下一波才出現。
- 商店與免費禮物保留本機展示提示，沒有付款／廣告 SDK 或實際發獎。

新遊戲從 500 金幣與四隻怪獸開始。`reference_preview` 僅供畫面擷取，頂欄可顯示圖稿金幣，不覆蓋玩家存檔。

## 存檔與模組

v2 保存金幣、擊倒、關卡、時間戳記，以及訓練、怪獸 EXP、出陣名單、穿戴及裝備等級。v1 讀入時保留原有金幣／擊倒／關卡，再加入成長預設值。每分鐘、應用程式背景通知、關閉與手動操作保存；訓練、穿戴、強化及出陣操作成功後立即保存。

沿用 `godot-kit/atomic_file.gd` 原子存檔與備份、`test_kit.gd` 測試輔助。不需要額外下載 Asset Library 或商店套件。主檔損壞時讀取合法備份；雙損壞或高於 v2 的版本保留原檔並停止寫入。

字型使用 [Noto Sans CJK TC](fonts/Noto-SOURCE.md)，授權在 `fonts/Noto-LICENSE`。使用者 PNG 保留原始檔，透過 AtlasTexture／Polygon2D 使用。角色及背景仍是暫用原圖素材，分層美術與動畫待補；[opt image 提示詞](../../docs/taskbar-hero-mobile-spec/art-prompts/README.md) 已提供，本輪沒有 AI 生圖。

## 驗證

目前測試入口：`test_progression_v2.gd`、`test_save_v2.gd`、`test_save_recovery.gd`、`test_ui_v2.gd`、`test_playable.gd`、`test_waves.gd`、`test_soak.gd`、`test_scene_persistence.gd`、`test_editor_contract.gd`。每支使用獨立的 XDG_DATA_HOME，例如：

```bash
XDG_DATA_HOME=/tmp/taskbar-waves godot --headless --path prototypes/taskbar-hero --script res://tests/test_waves.gd
```

`tools/capture_review.gd` 以真實滑鼠切七頁，擷取 941×1672、390×844、320×568 到 `/tmp/taskbar-v2-review/`。`tools/capture_waves.gd` 擷取戰鬥、行軍及士兵波次。擷取需顯示器或 xvfb-run。

[本輪七頁與行軍畫面對照](docs/progression-review/index.html)；[驗證結果](docs/progression-review/README.md)。舊 `docs/reference-ui/` 是前一檢查點。600 秒模擬是邏輯長跑測試，不能視為手機效能、耗電或 Android／iOS 實機驗證。離線收益、Boss、寶箱、Cube／Rune、完整章節及音訊尚未實作。
