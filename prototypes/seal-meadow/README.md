# 蓬蓬草原 seal-meadow（原型）

懷舊 Q 版 MMORPG 風格的 2.5D 草原：3D 低多邊形地形與道具，角色和怪物是立在 3D 世界裡的 2D 插畫（沿用 skybound-blades 的 RO 式呈現與 godot-kit `sprite3d`）。玩法目前是單人練功：點地面移動、點怪追打、升級。

## 手機製作方向（2026-10-26 已確認）

以手機執行與觸控為前提，採固定方向／俯角鏡頭，跟隨角色平移；不製作旋轉鏡頭與短連招，也不安排其他鍵序／節奏連招。戰鬥以點怪追打、自動普攻與少量技能操作為規劃基線，保留換裝、寵物與成長體驗。

詳細操作、安全區、效能與驗收見 [手機製作基準](design/mobile-production-baseline.md)，原作面向與 Godot 對應見 [希望 Online 詳細研究](../../docs/research/seal-online-deep-dive-2026-10-26/README.md)。現有 2.5D 管線先用來驗證手機，不因原作是完整 3D 就直接要求重做角色。固定鏡頭、觸控、背包、村莊、任務、寵物、精煉，以及單機圖鑑與釣魚薄切片已有實作；iPhone 17 Safari 尚未實機驗收。

系統文件與工作包見[製作規劃入口](design/planning/README.md)：包含 40 系統索引與逐系統 dossier、GDD／TDD／UX／資料／QA 交付標準、Godot 架構草案、決策清單與 [M0～M6 Roadmap](production/roadmap.md)。目前先做單機內容，多人 M4 延後；M3／S19／S33／S35 規格與本機測試已記錄，真機／長時間驗收仍待完成。現況與交接見 [PROGRESS.md](PROGRESS.md)，操作回饋見 [REVIEW.md](REVIEW.md)。

> 玩家目前是 Blender 渲染的測試小人紙娃娃（身體＋頭髮＋劍三層，`resources/sheets/test_chibi_*.tres`）。怪物圖**借用 skybound-blades 的原創圖當佔位**（`assets/sprites/`、`resources/sheets/`）。本作自己的圖還沒生成：玩家是 8 方向紙娃娃（素體＋頭髮／服裝／頭飾／武器／盾分層），怪物 4 方向且一律比玩家矮，規格與 prompt 見 [design/art-prompts/](design/art-prompts/README.md)。玩家角色走 3D 建模再渲染成 sprite，完整流程見 [design/pipeline/3d-to-sprite.md](design/pipeline/3d-to-sprite.md)（渲染與打包已用測試小人跑通）。

假說：懷舊 Q 版 MMO 的「點怪練功」用固定鏡頭 2.5D（3D 地圖＋預渲染 2D 角色圖）呈現，能在手機上提供清楚的畫面與觸控手感；角色可由 3D 建模離線渲染，執行時使用 sprite。狀態：進行中，尚未完成真機驗收。

## 執行（WSL）

```bash
godot --path .                                   # 開視窗玩
env -u WAYLAND_DISPLAY xvfb-run -a godot --path . --resolution 1280x720 --script res://tools/shot.gd -- build/shots   # 截圖
```

操作：點地面移動（按住持續走）、點怪物追打；閒置時受擊會自動反擊，技能也會選擇命中的存活怪，手動移動與既有目標優先。點地上物品靠近撿起，點傳送圈或名稱前往並顯示選取外環；點小地圖或「世界地圖」查看兩區。右上可開啟寵物／背包，背包可切換「物品／精煉」；左側可開啟設定、冒險圖鑑與衣櫥，成就可解鎖外觀及裝飾光環。點村長接任務、買賣及購買釣餌，靠近草原池塘的釣點可釣魚。右下技能鈕或 Q 放範圍揮砍，蘋果鈕補血。手機觸控與滑鼠相同；鏡頭固定，不能轉；桌面另有 WASD 移動、空白鍵打最近的怪、T 切換白天／黃昏。

測試（headless）：`tests/test_m0.gd`、`test_m1.gd`、`test_m1_loot.gd`、`test_m2.gd`、`test_m3.gd`、`test_m3_hardening.gd`、`test_collection.gd`、`test_fishing.gd`、`test_wardrobe.gd`、`test_content.gd` 與 `test_review_interactions.gd`；從 repo 根目錄執行 `env XDG_DATA_HOME=/tmp/seal-tests XDG_CONFIG_HOME=/tmp/seal-tests-config TEST_TIMEOUT=120 bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow`。核心循環短測：`godot --headless --path . --fixed-fps 60 -s tests/bot_m1.gd -- clear 5`。bot 的 `sweeps` 是實際完成施放的次數，`sweep_attempts` 包含被取消的施放。本輪各項證據與待重跑項目見 [PROGRESS.md](PROGRESS.md)。

網頁匯出：`Web` 是通用 preset，`Mobile Web` 是 ETC2 手機候選。`tools/build_mobile_web.sh` 已建立 `build/mobile-web/` 和 `build/seal-meadow-mobile-web.zip` 並套 IDBFS 補丁；`build/web/` 為 2026-10-27 舊版。Chromium 已驗證載入、設定、v4／v5→v6、精煉與衣櫥，沒有瀏覽器錯誤。未上傳，iPhone 真機相容性待驗證。

分層驗證：單一規則改動執行其對應 `tests/test_*.gd`（L1）；跨系統或回修以該測試加受影響的少量回歸（L2），例如 `bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow m3 m3_hardening review_interactions`。里程碑的完整 suite（L3）在使用者手動驗收後執行；改 scene 後另做 Godot headless 匯入。

## 結構

| 位置 | 內容 |
|---|---|
| `scenes/main.tscn` | 主場景：`%Meadow`、`%Player`、`%CameraRig`（`pitch_deg`、`distance`）、`%ClickMarker`、`%HUD` |
| `scenes/meadow.tscn` | 地圖：`%Props`（樹、石、灌木、路牌，位置都可拖；`block_radius` meta >0 才擋路）、`%Monsters`（每隻怪的出生點）、`Foliage`（草與花的 MultiMesh）、`%Sun`、`%WorldEnvironment`；根節點的白天／黃昏環境與日光色 |
| `scenes/monsters/*.tscn` | 怪物數值（`max_hp`、`damage`、`move_speed`、`aggressive`、`xp_reward`…）與 `Actor` 的 `sheet`、`head_height` |
| `scenes/player.tscn` | 玩家數值（`base_hp`、`base_attack`、`attack_range`、`attack_interval`） |
| `scenes/actors/actor.tscn` | 一隻角色的外觀：sprite、影子、名牌、血條、鎖定圈（從 skybound-blades 複製，腳本換成 `scripts/actor.gd`）；`layer_sheets` 是紙娃娃的額外圖層，由下往上疊 |
| `tools/blender/`、`tools/import_sheets.gd` | 3D 模型 → 紙娃娃 sprite 的渲染、打包與匯入，見 [3d-to-sprite.md](design/pipeline/3d-to-sprite.md) |
| `ui/hud.tscn` | 狀態框、目標框、訊息欄、小地圖與按鈕；`PetButton`、`MapButton` 的 anchor／offset 可在編輯器調整 |
| `ui/refine_row.tscn` | 背包精煉頁的重複列；可調整 `Details`、名稱／材料文字和 `Action` 觸控大小 |
| `scenes/portal.tscn` | 傳送點與選取外環；`Selection` 的材質、形狀和高度可在編輯器調整 |
| `ui/world_map.tscn` | 可編輯的草原／村莊總覽；`Window`、兩區文字與 `MapClose` 的版面、字級在 scene 中調整，`world_map.gd` 只更新所在區域 |
| `ui/settings_window.tscn` | 設定視窗；`Window`、`Contents` 的版面與音效／字體／減少停頓選項可在編輯器調整 |
| `ui/collection_window.tscn`、`ui/achievement_row.tscn` | 冒險圖鑑與可重複實例化的成就列；可調整 `Scroll`、`AchievementRows` 與領取鈕版面 |
| `ui/wardrobe_window.tscn`、`scenes/player.tscn` | 可編輯衣櫥及角色裝飾光環；`Window`、選項與 `%Aura` 的版面、形狀及顏色可調整 |
| `scenes/fishing_spot.tscn`、`ui/fishing_window.tscn` | 草原釣點與釣魚視窗；釣點的 `Post`、`Marker`、`Title`，視窗的 `Contents`、`FishingAction` 可在編輯器調整 |
| `scripts/terrain_height.gd` | 地形高度函式：地形網格由它烘出，角色直接貼著它走（不用物理） |
| `tools/build_world.gd` | 產生器，只在製作時跑；已存在的檔案預設跳過，`-- --overwrite` 才重建（先看 `git diff`） |

## 發現

- 產生器要在 xvfb 下跑、不能 `--headless`：headless 的假渲染器不保留 MultiMesh 的 transform，草會全部疊在原點。
- `SurfaceTool` 的頂點色在 shader 裡是 sRGB 原值，要自己 `pow(COLOR.rgb, 2.2)`，不然地面整片偏白。
- 相容渲染器下 `fog_density = 0.004` 就濃到蓋掉顏色，目前關掉霧。
