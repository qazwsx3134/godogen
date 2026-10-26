# 蓬蓬草原 seal-meadow（原型）

懷舊 Q 版 MMORPG 風格的 2.5D 草原：3D 低多邊形地形與道具，角色和怪物是立在 3D 世界裡的 2D 插畫（沿用 skybound-blades 的 RO 式呈現與 godot-kit `sprite3d`）。玩法目前是單人練功：點地面移動、點怪追打、升級。

## 手機製作方向（2026-10-26 已確認）

以手機執行與觸控為前提，採固定方向／俯角鏡頭，跟隨角色平移；不製作旋轉鏡頭與短連招，也不安排其他鍵序／節奏連招。戰鬥以點怪追打、自動普攻與少量技能操作為規劃基線，保留換裝、寵物與成長體驗。

詳細操作、安全區、效能與驗收見 [手機製作基準](design/mobile-production-baseline.md)，原作面向與 Godot 對應見 [希望 Online 詳細研究](../../docs/research/seal-online-deep-dive-2026-10-26/README.md)。現有 2.5D 管線先用來驗證手機，不因原作是完整 3D 就直接要求重做角色。下方操作列記錄目前桌面原型，手機適配與相機行為尚待實作。

系統文件與工作包見[製作規劃入口](design/planning/README.md)：包含 40 系統索引與逐系統 dossier、GDD／TDD／UX／資料／QA 交付標準、Godot 架構草案、決策清單與 [M0～M6 Roadmap](production/roadmap.md)。目前均為規劃草案，功能完成以各階段的實作與真機證據為準。

> 玩家目前是 Blender 渲染的測試小人紙娃娃（身體＋頭髮＋劍三層，`resources/sheets/test_chibi_*.tres`）。怪物圖**借用 skybound-blades 的原創圖當佔位**（`assets/sprites/`、`resources/sheets/`）。本作自己的圖還沒生成：玩家是 8 方向紙娃娃（素體＋頭髮／服裝／頭飾／武器／盾分層），怪物 4 方向且一律比玩家矮，規格與 prompt 見 [design/art-prompts/](design/art-prompts/README.md)。玩家角色走 3D 建模再渲染成 sprite，完整流程見 [design/pipeline/3d-to-sprite.md](design/pipeline/3d-to-sprite.md)（渲染與打包已用測試小人跑通）。

假說：懷舊 Q 版 MMO 的「點怪練功」用固定鏡頭 2.5D（3D 地圖＋預渲染 2D 角色圖）呈現，能在手機上提供清楚的畫面與觸控手感；角色可由 3D 建模離線渲染，執行時使用 sprite。狀態：進行中，尚未完成真機驗收。

## 執行（WSL）

```bash
godot --path .                                   # 開視窗玩
env -u WAYLAND_DISPLAY xvfb-run -a godot --path . --resolution 1280x720 --script res://tools/shot.gd -- build/shots   # 截圖
```

操作：點地面移動（按住持續走）、點怪物攻擊、點地上物品撿起、右下技能鈕或 Q 放範圍揮砍、右上「背包」看收穫並裝備／使用、走進藍色傳送圈往返蓬蓬村、點村長接任務與買賣、蘋果鈕補血（手機觸控與滑鼠相同；鏡頭固定，不能轉）、WASD 移動、空白鍵打最近的怪、T 切換白天／黃昏。

測試（headless）：`tests/test_m0.gd`、`tests/test_m1.gd`、`tests/test_m1_loot.gd`、`tests/test_m2.gd`、`tests/test_content.gd`，執行 `godot --headless --path . -s tests/<檔名>`。核心循環機器人：`godot --headless --path . --fixed-fps 60 -s tests/bot_m1.gd -- 180 7 [knob=value ...]`。

## 結構

| 位置 | 內容 |
|---|---|
| `scenes/main.tscn` | 主場景：`%Meadow`、`%Player`、`%CameraRig`（`pitch_deg`、`distance`）、`%ClickMarker`、`%HUD` |
| `scenes/meadow.tscn` | 地圖：`%Props`（樹、石、灌木、路牌，位置都可拖；`block_radius` meta >0 才擋路）、`%Monsters`（每隻怪的出生點）、`Foliage`（草與花的 MultiMesh）、`%Sun`、`%WorldEnvironment`；根節點的白天／黃昏環境與日光色 |
| `scenes/monsters/*.tscn` | 怪物數值（`max_hp`、`damage`、`move_speed`、`aggressive`、`xp_reward`…）與 `Actor` 的 `sheet`、`head_height` |
| `scenes/player.tscn` | 玩家數值（`base_hp`、`base_attack`、`attack_range`、`attack_interval`） |
| `scenes/actors/actor.tscn` | 一隻角色的外觀：sprite、影子、名牌、血條、鎖定圈（從 skybound-blades 複製，腳本換成 `scripts/actor.gd`）；`layer_sheets` 是紙娃娃的額外圖層，由下往上疊 |
| `tools/blender/`、`tools/import_sheets.gd` | 3D 模型 → 紙娃娃 sprite 的渲染、打包與匯入，見 [3d-to-sprite.md](design/pipeline/3d-to-sprite.md) |
| `ui/hud.tscn` | 狀態框、目標框、訊息欄、操作說明；配色字型在 `ui/theme.tres` |
| `scripts/terrain_height.gd` | 地形高度函式：地形網格由它烘出，角色直接貼著它走（不用物理） |
| `tools/build_world.gd` | 產生器，只在製作時跑；已存在的檔案預設跳過，`-- --overwrite` 才重建（先看 `git diff`） |

## 發現

- 產生器要在 xvfb 下跑、不能 `--headless`：headless 的假渲染器不保留 MultiMesh 的 transform，草會全部疊在原點。
- `SurfaceTool` 的頂點色在 shader 裡是 sRGB 原值，要自己 `pow(COLOR.rgb, 2.2)`，不然地面整片偏白。
- 相容渲染器下 `fog_density = 0.004` 就濃到蓋掉顏色，目前關掉霧。
