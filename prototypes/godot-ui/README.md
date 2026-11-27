# godot-ui

[目前進度與驗證](PROGRESS.md)

可重複使用、不同風格的 Godot 4.7 UI 元件。原則：

1. **用 `offset_transform_*`（visual only）做動畫**：Godot 4.7 的 Control 偏移變換，不改 `position`／`scale`，Container 不會重排、也不會覆蓋動畫；visual only 時點擊範圍維持原樣，不會因縮小而變難點。
1. **Snappy**：動畫 ≤0.2 秒，任何時候都能點（動畫只改 scale／rotation／modulate，不擋輸入）。
2. **分層**：子 node 依序出場，不要全部同時動。
3. **出現、消失、數值改變都要有動畫**；誇張程度依遊戲調參數。

## 元件

| 檔案 | 用途 | 可調欄位 |
|---|---|---|
| `scenes/juicy_button.tscn`＋`scripts/juicy_button.gd` | 帶陰影的按鈕（文字或 icon）。hover：x／y 分開擠壓拉伸（0.2／0.35）＋隨機方向小旋轉（TRANS_BACK、EASE_OUT）回 0 度、播音效；離開不播。`scale_ratio = clampf(width_full_rot / size.x, 0.5, 1.0)`，越長越收斂 | `shadow_dir`（右下／左下／正下）、`shadow_offset`、`squash`、`rot_degrees`、`width_full_rot`、`hover_sound`、`pitch_jitter`（音高隨機 ±8%）；陰影是子 node `Shadow` |
| `addons/proto_kit/ui_anim/container_tween.gd` | 掛在 Container：Ready 時子 node 只設透明（**不改 visible**），依序 `SCALE`／`SLIDE_IN_LEFT`／`SLIDE_IN_RIGHT` 出場 | `trigger`（READY／VISIBILITY／MANUAL→`play()`）、`anim_type`、`duration`、`delay_between_element` |
| `addons/proto_kit/ui_anim/auto_tween.gd` | auto_tween：子 node 掛在任一既有 Control 底下，替父 node 加出場動畫；`VISIBILITY` 讓只會切 visible 的選單自動有動畫 | `trigger`、`anim_type`、`duration`、`delay` |
| `scenes/card.tscn`＋`scripts/card_hand.gd` | Slay the Spire 式手牌：每張卡包在 dummy slot（純 Control）裡，HBox 只排 slot；抽牌時 tween slot 的 `custom_minimum_size.x` 展開，打出時收到 0 再刪；扇形旋轉與弧度放在 slot 的 offset transform，卡自己的 hover 抬起疊在上面 | `slot_width`（小於卡寬即重疊）、`fan_deg`、`arc`、`duration` |
| `scenes/inventory.tscn`＋`scripts/inventory.gd`、`scenes/item_slot.tscn`＋`scripts/item_slot.gd` | 背包：`GridContainer`（6 欄×24 格，格子預先放在 scene 裡，可直接在編輯器改欄數、增減格）。打開時格子依序縮放出場；點一格選起（抬起＋變色），再點另一格放下：空格移動、同物品疊加、不同交換；`Loot` 隨機加一件，會疊到同物品，數量變動時數字會彈一下 | `Grid.columns`、`start_items`／`start_counts`、`loot_pool`；格子大小在 `item_slot.tscn` 的 `custom_minimum_size` |
| `addons/proto_kit/ui_anim/tween_once.gd` | tweenOnce：當 Control 的腳本，覆寫 `_set` 追蹤 `tracked_property`，一被寫入就彈一下；也可手動 `punch()` | `tracked_property`、`punch_scale`、`duration` |
| `scenes/fantasy_demo.tscn`＋`scenes/fantasy_theme.tres` | 奇幻花邊框風格（Kenney Fantasy UI Borders）：任務面板、背包、地點發現橫幅、主選單。樣式全在 Theme 的 type variation：`FantasyPanel`（深底花框面板）、`Button`（白底主按鈕）、`OutlineButton`（白框次按鈕）、`TextButton`（純文字選項）、`FantasySlot`（道具格，toggle＋`ButtonGroup` 單選）、Label 的 `PanelTitle`／`PanelHeader`／`BannerSmall`／`BannerBig`／`SlotCount` | 在編輯器開 `fantasy_theme.tres` 改顏色、字級、`modulate_color` 與 content margin；面板花框換款：換 `assets/kenney/fantasy/` 的貼圖後重跑 `tools/build_fantasy.gd` |
| `scenes/fantasy_button.tscn`、`scenes/fantasy_slot.tscn` | 奇幻風按鈕（沿用 `juicy_button.gd` 的擠壓、音效與陰影，無樣式覆寫，靠 `theme_type_variation` 換外觀）與道具格（icon＋`%Count`） | 按鈕的 `theme_type_variation`、`shadow_dir`；道具格的 `icon`、`Count.text`、`button_group` |

`ui_anim/` 放在 godot-kit（`godot-kit/addons/proto_kit/ui_anim/`），本專案的是 `sync.sh godot-ui` 的副本，**改 kit 不改副本**。

`JuicyButton` 按下會縮到 88%，放開後彈回。要調整縮小幅度，選按鈕節點，在 Inspector 修改 **Press Scale**。

## 展示專案

用 Godot 編輯器開 `prototypes/godot-ui/project.godot`，按 F5 跑 `scenes/demo.tscn`：標題欄 ContainerTween（SCALE），Menu 按鈕切換的設定面板（VISIBILITY＋SLIDE_IN_LEFT，標題用 AutoTween），`+1` 讓計數器 TweenOnce 彈跳；`Draw Card` 抽牌，點卡打出；`Bag` 打開背包。

## 素材

- `assets/kenney/button_frame.png`：Kenney UI Pack – Pixel Adventure 2.0 `Tiles/Large tiles/Thick outline/tile_0000.png`，CC0
- `assets/items/*.png`：MorbidEmber Pixel RPG Starter Pack v1.1，MIT（授權檔在同目錄）
- `assets/kenney/mouse_left.png`：Kenney Input Prompts 1.5A，CC0
- `assets/kenney/fantasy/*.png`：Kenney Fantasy UI Borders 1.0（`PNG/Default` 的 panel-000／002／009、panel-border-000／009、panel-transparent-center-002／009、divider-fade-003），CC0。`panel-dark-000.png` 與 `divider-fade-003-flip.png` 由 `tools/build_fantasy.gd` 合成：前者是 panel-000 填深色後疊上 panel-border-000
- `assets/kenney/gradient-radial.png`：Kenney Development Essentials 1.1，CC0，奇幻示範的背景光暈
- `assets/sfx/*.ogg`：選低頻、不尖銳的（頻譜重心約 200～800Hz）。Kenney UI Audio `rollover6`→hover；Impact Sounds `impactSoft_medium_000`→unhover；Interface Sounds 1.0 `bong_001`→press、`drop_002`→appear、`maximize_008`／`minimize_008`→overlay 開關、`drop_004`／`confirmation_001`→抽牌／出牌。皆 CC0，來源 `D:\repo\game-sound`

背包道具格使用 Kenney UI Audio 的 `assets/sfx/rollover2.ogg`。要換音效，先把音檔放進專案的 `assets/sfx/`，再開啟 `scenes/item_slot.tscn`。選根節點 `ItemSlot`，把音檔拖到 Inspector 的 **Hover Sound**，存檔即可更新使用該場景的道具格。程式預設值在 `scripts/item_slot.gd` 的 `hover_sound`。

音效一律走 `UiAnim.play_sfx()`：音高隨機 ±8%，Container 出場時每個元素一聲、音高逐步升高（`pitch_step`）。

## 指令

```bash
godot --headless --path . -s tools/build_scenes.gd   # 製作工具：只在要重建時跑，會覆蓋 scenes/
timeout 60 godot --headless --path . -s tests/test_ui.gd </dev/null   # 單元測試，印 ALL PASS
godot --headless --path . -s tools/build_fantasy.gd   # 製作工具：重建 fantasy_* scene 與 Theme（新貼圖要先 --import 再跑一次）
timeout 60 godot --headless --path . -s tests/test_fantasy.gd </dev/null   # 奇幻 UI 測試，印 ALL PASS
godot --path . res://scenes/fantasy_demo.tscn   # 開奇幻 UI 示範
```
