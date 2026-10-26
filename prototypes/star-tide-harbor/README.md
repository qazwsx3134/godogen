# 星潮小港 · Star Tide Harbor

以《獵戶座之藍》的橫向海灣、悠閒釣魚與居民生活為研究起點，製作的**原創 Godot 可玩小品原型**。本作沒有使用原遊戲角色、場景、音樂、台詞或擷取素材作為遊戲資產。原型使用自己編寫的 SVG 像素風資產、水面 shader 與合成音樂。

## 開始試玩

Windows：雙擊 [開始遊戲.cmd](開始遊戲.cmd)。會使用這台電腦現有的 Godot 4.7；也可用環境變數 `GODOT_BIN` 指定引擎。

用 Godot 4.7 開啟 [project.godot](project.godot)，按 F6／F5 也能執行。這份交付是可執行的 Godot 專案，**沒有另外打包成免引擎的 Windows exe**。

| 操作 | 功能 |
|---|---|
| A／D、左右方向鍵 | 沿碼頭散步，攝影機橫向跟隨 |
| 點擊場景 | 走向點擊位置；點米菈會走近交談 |
| 空白鍵／釣魚按鈕 | 進入固定竿位，點選水域決定拋點與方向 |
| 按住左鍵／空白鍵 | 收線，水下移動魚餌誘魚；中魚後拉近魚並增加張力 |
| 按住右鍵 | 放線，延長魚餌路徑；中魚後卸力 |
| 角力提示出現時連點左鍵／空白鍵 | 放開再按計次；成功可拉近魚 |
| Tab／輔助按鈕 | 輔助示範完整釣魚流程；再按停止輔助 |
| E | 靠近米菈時交談 |
| B／魚類圖鑑 | 查看已發現魚種，分解重複魚 |
| Esc | 關閉圖鑑或對話；釣魚時返回小港，S 也可返回 |
| 小船佈置 | 以 2 份素材點亮船上的暖燈 |
| H／船艙佈置 | 開啟船艙，選四種免費家具樣品並點空格放置 |
| 佈置工具列 | 移動、收回；放置前 R 翻轉，右鍵取消預覽，Esc 完成 |

推薦先釣一尾魚，走到右側米菈身邊送禮，取得素材後點亮小船。再向更右側的霧光蘆葦灣散步，尋找另外兩種魚。

## 已實作

- 2400px 橫向場景、天空／遠島／中景林帶／主體／近景草五層景深感、環狀行星、水面波紋、倒影、植被風動與螢火光點。
- 選點拋竿、水下收放線誘魚、魚群靠近咬鉤、張力管理、偶發連點角力、斷線／脫鉤與捕獲結果。
- 輔助操作示範，可自動完成完整循環；這不代表原作放置規則。
- 六種魚、兩個位置魚池、永久發現紀錄與目前持有數量。
- 分解重複魚，保留每種第一尾，換得星砂與素材。
- 一位原創居民米菈、首次交談、一次送禮、簡單關係對話。
- 四種船艙家具，預覽、格位放置、移動、翻轉、收回與版面保存；保留 2 素材的船外暖燈升級。
- 一個小目標、原子寫入的本機存檔。
- 合成環境旋律與釣魚提示音。

這是約數分鐘能看懂的垂直切片。船艙目前為獨立佈置畫面，尚無艙內角色走動、牆面裝飾、多格家具與撤銷功能；也未做航海、季節、角色自訂、完整戀愛事件或商店升級。送禮上限是**這份原型存檔一次**，目前沒有日夜換日系統。輔助釣魚只在程式執行時運作，沒有離線補算。

## 可編輯場景

| Scene | 可調整內容 |
|---|---|
| [harbor.tscn](scenes/harbor.tscn) | 215 個節點（含子場景），主場景、人物位置、背景、HUD、對話、圖鑑與燈光 |
| [depth_layers.tscn](scenes/depth_layers.tscn) | 中景／前景原點與位移倍率，6 節點 |
| [cabin.tscn](scenes/cabin.tscn) | 船艙背景、工具列、格線與預覽，41 節點 |
| [furniture.tscn](scenes/furniture.tscn) | 可重複使用的家具與燈光罩，3 節點 |
| [fishing.tscn](scenes/fishing.tscn) | 28 個節點，水下場景、魚群、餌、魚線、張力與角力 HUD；根節點可調收放速度、吸引範圍、斷線寬限與連點次數 |
| [player.tscn](scenes/player.tscn) | 主角 Body 圖片與腳底錨點 |
| [mira.tscn](scenes/mira.tscn) | 居民 Body 圖片與腳底錨點 |
| [fish_card.tscn](scenes/fish_card.tscn) | 可重複使用的魚類圖鑑卡片 |
| [harbor_theme.tres](assets/harbor_theme.tres) | 共用字型、字級、Panel、Button 與進度條樣式 |

主要 UI 在 `HUD/Screen`。靜態文字、位置、尺寸與色彩均保留在 scene／Theme；腳本只更新遊戲狀態、移動、特效與動態資料。可直接改 `%Title` 的標題文字；測試已確認 `_ready()` 不會覆蓋它。

`tools/build_scenes.gd` 是已套用的製作工具，正常執行不會呼叫它；再執行時會跳過既有場景。`tools/add_fireflies.gd` 是一次性場景遷移，已有 Fireflies 時跳過。重新產生素材前請先檢查 diff，保留人工修改。

`tools/build_fishing.gd` 與 `tools/retire_tracking_meter.gd` 是已套用的釣魚場景遷移，會跳過已完成的部分。`tools/upgrade_fishing.py` 只記錄本次一次性原始碼遷移，不要重新執行。

`tools/build_depth_cabin.gd` 是已套用的景深及船艙製作工具；新增資產要先匯入，再執行製作工具。既有場景不重建。`bind_cabin_textures.gd` 只補上首次匯入前缺少的圖像參照。

## 驗證

已執行 Godot 4.7 headless 匯入、核心邏輯測試與實際 OpenGL 畫面擷取。詳見 [smoke-results.json](evidence/smoke-results.json)。通過項目：選點→拋竿→水下誘魚→咬鉤→張力與角力→捕獲、收放線長度、被動等待不自動咬鉤、過緊斷線與鬆線脫鉤、圖鑑、分解保留、送禮上限、小船佈置、攝影機邊界、遠岸魚群及場景不被執行狀態覆寫。通過邏輯測試尚不能證明與原作手感相同。

```text
godot --headless --path . --editor --import
godot --headless --path . --script res://tools/smoke_test.gd -- --smoke-test
godot --path . --script res://tools/capture.gd -- --smoke-test
```

`--smoke-test` 不載入或修改正常玩家存檔。正常存檔位於 Godot 的 `user://harbor-v1.json`。進度在捕獲、分解、交談、送禮與佈置時儲存。

## 來源

- [原作研究與驗證](研究與驗證.md)：官方資訊、實機觀察與尚未驗證項目。
- [釣魚體驗分析](釣魚體驗分析.md)：Sol 撰寫，含使用者補充、Luna 實機證據與新版操作對照。
- [景深、美術與佈置](景深美術與佈置.md)：距離層、風格分析、可操作的船艙佈置與限制。
- [素材與授權](素材來源.md)。
- [海灣預覽](evidence/prototype-harbor.png)、[釣魚預覽](evidence/prototype-fishing.png)、[圖鑑預覽](evidence/prototype-journal.png)。
