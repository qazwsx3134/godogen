# 浮空劍域 Skybound Blades（開發中）

單機 AI 隊伍的爬塔放置 RPG；角色永久死亡，保留帳號傳承。目標是 Web 桌機與手機橫向，戰鬥呈現是 RO 式 HD 2.5D：3D 地圖＋godot-kit sprite3d 的 HD billboard 角色，點敵人追打、自動狩獵與兩名 AI 隊友。

目前交付：[RO 戰鬥切片](design/ro-slice.md)＋[M1 單層閉環](design/m1-loop.md)：風庭遺跡的狩獵區、營地（補給、倉庫、委託、換裝）、撤退、守層者「守門者」、本機存檔與世代交替，可在桌機與手機橫向的網頁版遊玩。角色與怪物是本作原創的 HD 插畫（`art_src/chars/`），場景是低多邊形 3D。

## 原型假說

RO 式 HD 2.5D 的自動追打，加上兩名真正參與戰鬥的 AI 隊友，能讓「農怪升級」在 Web 桌機與手機橫向上都好看、好懂、有手感；之後再接上遠征、任務、物品與永久死亡傳承的長期循環。

## 執行

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import                     # 第一次或新增素材後
$GODOT --path .                                          # 開視窗玩
# 測試（依序跑；嚴格檢查 log）
GODOT_BIN=$GODOT ../godot-kit/tools/run_tests.sh . battle run save camp field:60 text sprites
# 網頁版：build/web/，從 localhost 開
GODOT_BIN=$GODOT ../godot-kit/tools/web/build_web.sh .
```

檢查角色圖集：`$GODOT --path . res://addons/proto_kit/sprite_inspector.tscn`（方向、速度、逐幀、格線與自動檢查，見 godot-kit README）。

操作：點地面移動（按住拖曳持續移動）、點怪物鎖定追打、WASD／方向鍵、空白鍵自動狩獵、Q 裂空斬、E 藥水、R 急救包、T 撤退、B 背包（換裝）、C 營地（在營地內）、Esc 暫停、滾輪縮放。

## 程式結構

| 位置 | 內容 |
|---|---|
| `domain/` | 純模擬（不碰節點）：`battle.gd` 固定 50 ms 步進的戰鬥、AI、營地、撤退、守層者；`run.gd` 一代的成長、背包、裝備實例、委託與 kill receipt；`profile.gd` 跨代的倉庫與紀念碑；`save_service.gd` 存檔／備份／tombstone；`tuning.gd` 讀 `design/tuning-draft.json`；`stepper.gd` 把畫面 delta 換成步數 |
| `game/` | 呈現：`field.gd` 讀場景配置、存讀檔、轉輸入為指令、轉事件為特效／音效／HUD；`camp_menu.gd` 營地視窗的內容與動作；`actor_view.gd` 角色外觀、插值與程序化動作；`boss_view.gd` 守門者（低多邊形石像，HD 美術待補）；`fx.gd`、`prop.gd`、`camp.gd`、`sfx.gd` |
| `ui/` | `hud.tscn`＋`hud.gd`（只用 signal 與 `refresh()` 對外）、`camp_panel.tscn`、`item_row.tscn`、`party_row.tscn`、`theme.tres` |
| `tools/` | `build_slice.gd`（scene 產生器，只在製作時跑）、`pack_sprites.py`（原畫 → 圖集）、`shot.gd`（截圖）、`pacing_calc.py`（節奏試算） |

## 主要 scene 與可調欄位

| Scene | 在編輯器可直接調整 |
|---|---|
| `scenes/field.tscn` | `%Camp` 的位置與 `radius`（安全區）；`%Party` 三人與 `%Monsters` 每隻怪（含守門者）的位置（開局即依此出生）、怪物節點的 `kind_id`；`%Props` 道具的位置／旋轉／縮放與 `block_radius`（>0 才擋路）；根節點的 `bounds`、`battle_seed`、`camera_distance`、`pick_radius_px`；`Sun`、`WorldEnvironment`、`Ground` 材質參數 |
| `scenes/actors/actor.tscn` | `head_height`（名牌與血條高度）、`show_nameplate`、`dissolve_on_down`、`nameplate_color`、`sheet`（`resources/sheets/*.tres`：動畫格與每格停留時間） |
| `ui/hud.tscn` | 所有面板的錨點與位置、按鈕大小、文字；配色與字級在 `ui/theme.tres` |
| `scenes/props/*.tscn` | 低多邊形道具的組成與 `block_radius` |
| `scenes/fx/*.tscn` | 特效長度 `duration`、`rise` 與 shader 參數 |

戰鬥數值一律在 `design/tuning-draft.json`，不在 scene。產生器只在製作時執行：已存在的 scene 預設跳過，`-- --force <名稱>` 才會重建（先看 `git diff`）。

## 狀態與發現

M0 RO 戰鬥切片：可玩，驗收狀態見 [ro-slice.md](design/ro-slice.md) 的「驗收結果」。

- 網頁包 3.8 MB（字型 1.5、圖集 2.0）；角色圖集用有損 WebP＋mipmap，不轉 VRAM 壓縮。
- kit 的角色 shader 是像素用的 nearest 取樣；HD 插畫改用產生器從 kit 衍生的 `shaders/sprite3d_hd.gdshader`（只換成 linear＋mipmap）。
- 手機實機 FPS 尚未量測（headless 軟體繪圖的數字不代表實機）。

## 文件

- [最新：MMORPG 機制研究](../../docs/research/echoes-of-aincrad-mmorpg-systems-2026-10-24.md)
- [目前交付：RO 戰鬥切片](design/ro-slice.md)
- [切片之後：機制開發順序](design/mechanism-plan.md)
- [一頁企劃](design/game-brief.md)
- [玩法與實作規格](design/implementation-plan.md)
- [原作六項機制補充研究](../../docs/research/snored-art-online-mechanisms-2026-10-24.md)
- [前一輪登入實測](../../docs/research/snored-art-online-gameplay-items-modes-2026-10-23.md)
- [接續工作狀態](production/session-state/active.md)
- [Review 紀錄](production/reviews/)

選定方向：單機、隊長＋2 AI、永久死亡與傳承、Web 桌機＋手機橫向、RO 式 HD 2.5D。暫名與所有調校數字可在原型驗證後調整；已確認的方向不再重複詢問。
