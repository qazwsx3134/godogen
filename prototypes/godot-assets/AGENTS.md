# 共用 UI 素材使用指南

先讀目標遊戲的 README 和現有 Theme。套用素材時，以該遊戲的介面風格與操作規格為準。這裡提供共用來源，請把用到的檔案及其授權複製到目標遊戲，例如 `res://assets/ui/kenney/`。在專案的素材署名或 README 註明來源和版本。保留本庫的上游檔案，專案需要調色或裁切時在遊戲自己的副本處理。

## 框、按鈕與道具格

- 用 Kenney Pixel Adventure 的 [Preview.png](kenney/ui-pack-pixel-adventure/Preview.png) 選粗框或細框、木色或藍灰色。同一組 HUD 選同一套線寬。暖色方框可從 `Tiles/Large tiles/Thick outline/tile_0000.png` 的 32×32 單張 PNG 開始。
- 可伸縮的面板和道具格用 `StyleBoxTexture`，設定 `Texture Margins` 以保留邊框與角落。上面那張方框可從四邊各 6 px 起測，再在編輯器拉寬和拉高確認角落、邊框及內容間距。把樣式放入 `Theme` 的 `PanelContainer/panel` 或 `Button` 對應狀態；靜態框可用 `NinePatchRect`。用 `CanvasItem.texture_filter = TEXTURE_FILTER_NEAREST` 保持像素邊界。
- `normal` 決定基礎框，`hover` 負責游標回饋，`pressed` 或選取樣式負責持續高亮。鮮明的選取框需在觸控放開後仍跟著當前選取格。鍵盤焦點使用獨立的 `focus` 樣式。道具內容用 `Button.icon` 或格內的 `TextureRect`，數量用獨立 Label。
- 使用圖集時先讀同尺寸資料夾的 `Tilesheet.txt`。例如 Large tiles 的原始 `tilemap.png` 是 32×32 格、格間隔 1 px，`AtlasTexture.region` 要算進間隔。逐張選用時直接拿 `Tiles/` 內的獨立圖。

## 道具與操作提示

- Pixel RPG Starter Pack 的 `tiles/` 已切成 64×64。背包用 `backpack_LVL_01.png`，書本可用 `book_01.png`。維持圖示比例，用現有格子的大小和文字樣式擺放。框和按鈕樣式沿用目標專案的 Theme。
- Kenney Input Prompts 依裝置和尺寸分目錄。手機點按可用 `Touch/Default/touch_tap.png`，滑鼠可用 `Keyboard & Mouse/Default/mouse_left.png`，Xbox A 用 `Xbox Series/Default/xbox_button_a.png`。先看包內 `Overview.html` 或各裝置的 Preview 再挑圖。
- 有改鍵的遊戲從 `InputMap.action_get_events()` 或既有輸入管理器取得實際綁定。依最近使用的裝置切換提示，優先沿用專案既有的裝置判定。未知手把用 Generic 圖示，找不到鍵盤圖示時顯示實際按鍵名稱。觸控動作顯示對應手勢或操作按鈕。

## 交付驗證

用目標遊戲的 Godot 編輯器確認素材可從 `res://` 載入，存成可調整的 scene 或 Theme 資源。測試目標手機／桌面比例下的面板拉伸、圖示可讀性、按鈕高亮、焦點，以及與實際綁定對應的提示。匯入檢查可用 `godot --headless --path <遊戲目錄> --editor --import`。
