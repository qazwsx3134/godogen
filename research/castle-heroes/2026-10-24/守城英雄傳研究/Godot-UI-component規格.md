# Godot UI layout 與 component 參考規格

狀態：研究／設計規格，沒有新增遊戲程式或場景。參考來源是本次 0.34.1 截圖，原作使用 Unity；下列節點與資料設計是供 Godot 4 製作時參考。

## 版面原則

保留原作的資訊分工：上方是生存狀態，中間是防線與怪潮，下方是當前模式的操作。用自己的美術重建，不把截圖裁成可操作介面。

以 1920×1080 為研究基準，實作時用 anchors、Container 與最小尺寸表達，避免逐幀改 position／size。世界與 UI 可用不同的採樣策略：世界關注像素比例；文字與按鈕保持可讀。縮小視窗時先調整資訊密度，不把所有文字無限縮小。

## 建議 scene tree

```
Game (Node)
├─ World (Node2D)
│  ├─ Backdrop
│  ├─ Castle / DeploymentSockets
│  ├─ Units / Enemies / Projectiles
│  └─ WorldEffects
├─ HUD (CanvasLayer)
│  └─ Screen (Control, full rect)
│     ├─ TopStatus (MarginContainer / HBoxContainer)
│     │  ├─ CastleHP (stat_bar.tscn)
│     │  ├─ WaveStatus
│     │  └─ CastleMP (stat_bar.tscn)
│     ├─ QuestTracker (quest_row.tscn)
│     └─ BottomDock (PanelContainer)
│        ├─ ResourceColumn
│        ├─ PreparationControls
│        └─ BattleControls
├─ ModalLayer (CanvasLayer)
│  └─ Dimmer / CenterContainer / ActivePanel
└─ TooltipLayer (CanvasLayer)
   └─ SkillTooltip / KeywordTooltip / Toast
```

CanvasLayer 可將 HUD 與其他 2D 繪製層分開排序，避免世界相機移動帶走介面。[官方文件](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html)

modal 開啟時攔截點擊穿透，關閉後把鍵盤焦點還給開啟它的按鈕；裝飾節點 mouse_filter 設為不擋操作。tooltip 的位置可按螢幕邊界調整，但主版面由 scene 本身負責。

## 可重用元件清單

| 建議 scene | 可見結構 | 資料／訊號 | 必須處理的狀態 | 參考圖 |
|---|---|---|---|---|
| stat_bar.tscn | 圖示、名稱、進度條、當前／最大值 | current、maximum；只接收資料 | 滿、低、歸零、最大值改變 | 09、25 |
| resource_amount.tscn | 貨幣圖＋數字 | currency_id、amount | 不足、K／M 縮寫、精確 tooltip | 09 |
| framed_button.tscn | Button＋自有框圖＋Label | pressed | hover、focus、disabled、pressed | 全部 |
| facility_button.tscn | 圖示、快捷鍵、通知點 | facility_id、open_requested | 鎖定／可解鎖／已開／新內容 | 09 |
| unlock_dialog.tscn | 標題、圖、成本、條件、按鈕 | requirement、cost；unlock_requested | 條件不足、錢不足、成功 | 29～33 |
| unit_card.tscn | 立繪、等級、稀有度、上陣標記 | unit_id；selected | 已選、已上陣、未取得 | 11 |
| unit_details.tscn | 展示、屬性、技能、裝備、操作 | unit_view_model；upgrade/equip 等 | 類型差異、未取得、升級不足 | 11、18 |
| stat_cell.tscn | icon、數值、說明入口 | stat_id、value、format | 百分比、小數、零值、加成明細 | 13、14 |
| skill_slot.tscn | icon、冷卻圈、MP、快捷鍵 | skill_id；cast_requested | 可用、CD、MP 不足、未解鎖 | 25 |
| skill_tooltip.tscn | 名稱、圖、CD／MP、敘述 | skill_data、resolved_values | 普攻／主動／被動／星級門檻 | 15～17 |
| equipment_slot.tscn | 類型剪影、物品、等級 | slot_type、item_id；clicked | 空、穿戴、類型不相容 | 11、22 |
| targeting_menu.tscn | 策略單選清單 | policy；policy_changed | 目前策略、不可用目標類型 | 20 |
| loadout_selector.tscn | OptionButton＋編輯入口 | preset_id；selected | 1～5 組、未儲存修改 | 24 |
| cost_row.tscn | 多貨幣圖與持有／需求 | costs[]、balances | 各項不足獨立顯示 | 02、32 |
| upgrade_row.tscn | 當前值、下一級、成本、操作 | upgrade_id；requested | 單次、批次、滿級、不足 | 18、19 |
| inventory_panel.tscn | tabs、ScrollContainer＋Grid | category、items；selected | 空、篩選、批次模式 | 12 |
| recruit_panel.tscn | 卡池進度、機率、單抽／十抽 | pool_id、count；pull_requested | 不足、動畫、結果、跳過 | 26～28 |
| probability_row.tscn | 等級、合計率、角色列表 | tier、probability、entries | 等級變動、精確單角率 | 28 |
| star_panel.tscn | 星級段、碎片條、提升預覽 | unit_id；ascend_requested | 不足、一鍵、技能解鎖 | 19 |
| quest_row.tscn | 目標、進度、獎勵、領取 | quest_id；claim_requested | 未完成、可領、已領 | 08、25 |
| contribution_row.tscn | 頭像、條、數值 | unit_id、metric、value | 無資料、單位歸因、切換指標 | 07、25 |
| tutorial_overlay.tscn | 遮罩、目標框、箭頭、文字 | step_id、target_path | 下一步、可略過、目標不可見 | 01、03 |
| production_lane.tscn | 工人／槽位、等級、產率、成本 | production_id；upgrade_requested | 未開放、工作中、滿級 | 02 |

進度條可用 TextureProgressBar 的水平、垂直或環形模式。技能 CD 不必另外寫一個全屏 shader。[官方文件](https://docs.godotengine.org/en/stable/classes/class_textureprogressbar.html)

框體使用自己的 NinePatchRect 或 Theme／StyleBoxTexture；角落不拉伸，內容另外由 Container 排版。[官方文件](https://docs.godotengine.org/en/stable/classes/class_ninepatchrect.html)

## 單位管理面板的 scene 結構

```
UnitManagement (PanelContainer)
└─ MarginContainer
   └─ VBoxContainer
      ├─ Header / CloseButton
      ├─ HBoxContainer
      │  ├─ UnitDetails
      │  │  ├─ Name / Stars
      │  │  ├─ Portrait / StatGrid
      │  │  ├─ SkillRow / EquipmentRow
      │  │  └─ ActionRow
      │  └─ UnitBrowser
      │     ├─ CategoryTabs
      │     └─ ScrollContainer / GridContainer
      └─ LoadoutRow
```

重複卡片使用 PackedScene 實例化；主要版面、代表性角色與靜態文字應在編輯器未執行時可見。腳本用 scene unique name 連線訊號，避免 `_ready()` 用大量 `.new()` 重建整個畫面。這也符合 godogen 的既有場景規範。

## 資料與 UI 的邊界

建議把靜態定義、玩家狀態、戰鬥狀態分開，避免面板自己改遊戲規則。

| 類型 | 內容 |
|---|---|
| UnitDefinition Resource | ID、名稱、類型、元素、職能、基礎屬性、技能、裝備相容性、圖像引用 |
| SkillDefinition Resource | 係數、目標型態、CD、耗魔、狀態關鍵字、解鎖條件 |
| UnitProgress | 等級、星級、碎片、裝備 ID、尋敵策略 |
| Loadout | 槽位→單位 ID；不要只記陣列順序而失去位置意義 |
| EconomyState | 貨幣、材料、設施等級、招募進度、已領任務 |
| BattleState | HP／MP、波次、技能 CD、當前目標、貢獻統計 |

```
玩家按鈕 → 發出意圖 signal → 遊戲服務驗證條件
                               ↓
                         更新唯一狀態
                               ↓
                         UI 顯示最新資料
```

成本、CD、狀態疊加等公式不寫在 tooltip 文案內；同一資料來源供計算與說明使用。文字可本地化，數值格式可獨立測試。這裡提出的是自己的資料設計，不推定原作內部架構。

## 視覺 token 與資產清單

研究觀察：暗褐／黑色面板、石與金屬邊框、奶黃色主要文字、紅色主要戰鬥按鈕、藍色 MP、紅色 HP、紫色鑽石、綠色選中框。借用色彩角色分工時，請使用自己的造型與貼圖。

製作前準備：面板九宮格、按鈕 normal／hover／pressed／disabled／focus、分類 tab、貨幣 icon、屬性 icon、技能框、裝備空槽、稀有度卡框、星級、鎖定圖、快捷鍵底圖、進度條底／填充／覆蓋、提示箭頭、選中與上陣標記。文字不要烘進圖片。

字體至少支援繁中、數字與標點；統一標題／本文／說明／數值四層。母面板間距和卡片尺寸留在 scene／Theme，可在 Inspector 調整；裝飾與互動熱區分開。

## 製作驗收條件

1. 主戰場、戰前 HUD、戰中 HUD、單位管理各有可編輯 scene。
2. 改 scene 的文字／間距，執行時不被腳本覆寫；戰鬥狀態不反寫來源 scene。
3. 1920×1080、1280×720、小視窗與超寬畫面沒有主要控制被裁掉。
4. 無滑鼠 hover 也能用鍵盤開啟技能／屬性說明；焦點可見，Esc 關閉最上層。
5. 顯示成本與實際扣款一致；連點不重複扣款，資源不足不改狀態。
6. 技能 CD、MP 不足、鎖定／未取得、空倉庫都有可理解的狀態。
7. DPS 與總傷害分開，圖表能正確歸因持續傷害與召喚物。
8. 圖片與圖示使用自製／合法資產，研究截圖不作正式遊戲素材。

本輪只提供規格，以上項目尚未建立或測試。
