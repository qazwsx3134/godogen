# 像素水族箱進度


## 2026-11-23｜master｜分類提交

- feat(pixel-aquarium): add aquarium prototype
- 本次整理未重跑遊戲測試；既有驗證與待辦以 README、先前進度及測試檔為準。未 push。
- 下一步：依原專案進度進行人工驗收與後續工作。

## 2026-11-22｜master｜木紋、葉飾與緊湊 HUD

- 背包及手札採可九切縮放的像素木紋框與四角葉飾，道具格沿用木框紋理。選中道具用琥珀底及亮邊。主列 60 → 48、背包按鈕高 72 → 58、道具格 70×66 → 58×52，縮放與布置按鈕也縮小。沿用既有水族箱場景。
- 木紋圖樣由 `tools/draw_notebook_frames.py` 繪製，來源圖在 `assets/notebook/`，透過 `care_notebook.tres` 與可編輯場景套用。
- L2 通過 headless 匯入、`check_care.gd`、`check_touch.gd`，並以 Xvfb 驗證 390×844 的觸控和實際渲染。[背包](docs/care-wood-inventory.png) · [布置](docs/care-wood-placement.png) 手機真機待測。基準 `f2f7c056`，本地未提交。

## 2026-11-22｜master｜養魚手帳介面元件

- 採 B 的奶油底、暖棕框和琥珀操作狀態，套用主缸 HUD、背包格子、操作選單、魚卡、育種手札及彈窗。版面採現有右下角背包與觸控方式，魚缸場景、模型、光線和取景維持 2.5D。
- 可編輯主題為 `assets/care_notebook.tres`。匯入與 L2 `check_care.gd`、`check_touch.gd` 均通過。Xvfb 390×844 通過背包、賣出、擺放與旋轉驗證。[背包](docs/care-notebook-inventory.png) · [布置](docs/care-notebook-placement.png)
- 基準 `f2f7c056`，本地變更未提交。手機真機驗收待做。

## 2026-11-22｜master｜放置育種與手機操作

- 同種成魚在缸內準備 60 秒後可自動配對。有空位時產一顆卵，親魚休息 180 秒，卵再過 90 秒孵化。依事件時間結算離線配對與孵化，出生成就和獎勵只寫入一次。回缸紀錄提供產卵、孵化與成年，孵化前隱藏子代品系。現在採同種育種，玩家間魚隻交易延後。
- 右下背包預設收合，打開可點魚卵、飼料、裝飾使用或賣出。布置由點選位置、旋轉 30°、確認或取消組成。放大後可單指拖曳，窄直式視窗也可左右拖曳。主畫面採圖示入口和短暫回饋。存檔更新至 v4，可讀 v1 至 v3。
- [A．深青魚缸、B．養魚手帳、C．水玻璃側欄](design/ui-concepts/README.md) 三張直式 ImageGen 概念圖供視覺選型。可玩版目前為精簡深色介面。[背包](docs/care-touch-inventory.png) · [旋轉與確認](docs/care-touch-placement.png)
- L2 在隔離副本通過 `godot --headless --editor --import`，以及 `godot --headless --fixed-fps 60 --script res://tools/check_{care,preview,cardinal,touch}.gd` 四支腳本。Xvfb 圖形模式另驗證 390×844 觸控事件及 844×390 展示缸點魚。已驗證離線產卵／孵化、重開防重複、v1 至 v3 遷移、庫存售出、裝飾旋轉與鏡頭拖曳。手機真機和第一胎的節奏待實玩。
- 主要入口為 `scenes/care.tscn`、`scripts/care_state.gd`、`scripts/care.gd` 與 `scripts/aquarium.gd`。[規格更新至 v0.6](design/SPEC.md)。基準 `f2f7c056`，本地原型與文件未提交。

## 2026-11-21｜master｜紅蓮燈養成

- 孵出第一胎子代後解鎖每顆 18 金的紅蓮燈卵。買卵入庫，放入孵化盤 90 秒後孵化。幼魚滿四分鐘且吃過兩餐後成年，可命名、餵食、收起、送養和配對。
- 三尾以上在缸內會沿同一條路線巡游，保留各自的節奏與間距，進食時可離隊。鬥魚與紅蓮燈分開配對；紅蓮燈親魚及子代接上回缸紀錄、圖鑑、家系和下一胎。
- 存檔版本升到 v3，保留 v1／v2 鬥魚、名字、親緣、金流、飼料與布置。L2 在乾淨副本通過 headless 匯入及 `check_care.gd`、`check_preview.gd`、`check_cardinal.gd`。Xvfb 720p 和 4:3 均通過解鎖、購買、孵化、群游、實際吃餌、配對和重開。[群游](docs/care-cardinal-school.png) · [紅蓮燈家系](docs/care-cardinal-lineage.png)
- 主要檔案為 `scripts/care_state.gd`、`scripts/care.gd`、`scripts/fish.gd`、`scripts/breeding_journal.gd` 與 `scenes/breeding_journal.tscn`。紅蓮燈沿用 `scenes/cardinal.tscn`。七彩神仙與オイカワ可在展示缸觀察。基準 `f2f7c056`，本地變更未提交。

## 2026-11-21｜master｜育種手札

- 主缸入口新增圖鑑、家系與「下一胎」。家系標記玩家的首胎和第一尾月影，以兩張親魚卡連到子代。可從魚卡直達，或由家系定位缸內個體，送養後保留紀錄。
- 「下一胎」優先列出可立即配對的成魚組合，再按月影機率排序。顯示四種結果、冷卻／滿缸限制及穩定月影家系進度。選組合後會進入現有配對確認。
- L2 在乾淨副本執行 `godot --headless --editor --import`、`godot --headless --fixed-fps 60 --script res://tools/check_care.gd`、`godot --headless --fixed-fps 60 --script res://tools/check_preview.gd`。驗證第一胎、回缸、定位、冷卻、配對確認與已送養家系。以 Xvfb 在 1280×720 與 1024×768 確認家系、100% 配對及穩定月影家系標記。真人首胎試玩仍待驗收。
- 主要檔案為 `scenes/breeding_journal.tscn`、`scripts/breeding_journal.gd`、`scripts/care.gd`。基準 `f2f7c056`，本地原型與進度未提交。

## 2026-11-21｜master｜統一商店、自由布置與游姿

- 右下角道具欄統一顯示商店買的魚卵、兩種飼料與裝飾。薄片飼料下沉慢，沉底顆粒較快落到底，每包五次投餌，落水才扣一次。
- 裝飾用滑鼠預覽缸底位置，Q／E 旋轉，左鍵放置，右鍵或 Esc 取消。已擺放的道具可移動或收回。舊版存檔的固定位置轉成相應缸底座標，缸燈成為可旋轉的實體道具。
- 直游有推水與滑行節奏，尾鰭延遲跟上彎身。迴轉有角加速度、側傾及收尾，飼料依原先啄食規則判定。
- L2 通過 `godot --headless --fixed-fps 60 --script res://tools/check_care.gd` 與 `godot --headless --fixed-fps 60 --script res://tools/check_preview.gd`。驗證商品入庫、投餌扣量、旋轉與取消、重開保存、舊檔遷移、游姿與餵魚回歸。圖形模式另於 1280×720、1024×768 驗證商店及擺放。[自由布置](docs/care-placement.png)
- 主要檔案為 `scenes/care.tscn`、`scripts/care.gd`、`scripts/care_state.gd`、`scripts/fish.gd` 與 `shaders/swim_bend.gdshaderinc`。基準 `f2f7c056`，原型與進度未提交。

## 2026-11-21｜master｜道具欄、飢餓提示與進食動作

- 畫面底部中央增加道具欄。商店魚卵依品系堆疊，放入孵化盤後才開始 90 秒倒數。購買時占用一格，重開保留庫存。親魚產的卵直接孵化。道具店購買的水草、沉木、缸燈也從道具欄擺放、移動與收回。
- 缸中有食慾的魚上方顯示飼料圖示。鬥魚會轉向追餌、靠近減速張開下顎、接觸後合嘴和吞嚥。吃飽時圖示消失，食慾恢復後重現。
- L2 檢查 `godot --headless --fixed-fps 60 --script res://tools/check_care.gd` 及 `godot --headless --script res://tools/check_preview.gd` 通過。以 Xvfb 在 1280×720、1024×768 實際渲染養成流程，驗證卵過 90 秒仍在庫存、重開後開始孵化、道具擺放與收回、飢餓圖示及下顎動畫。畫面見 [道具欄與飢餓提示](docs/care-inventory.png) 和 [啄食](docs/care-bite.png)。混音試聽待玩測。
- 主要檔案為 `scenes/care.tscn`、`scenes/betta.tscn`、`scenes/item_slot.tscn`、`scenes/hunger_icon.tscn`、`scripts/care.gd` 與 `scripts/care_state.gd`。基準 `f2f7c056`，變更未提交。

## 2026-11-21｜master｜養成首版

- 養成缸成為預設入口。完成幼魚命名、買卵、可見的落餌與啄食、幼魚成熟、親魚配對、遺傳預覽、胎次、家系、圖鑑成就、擴缸及裝飾。12 尾同缸的外觀展示可從原場景開啟。
- 進食、產卵、離線孵化與養成獎勵接上版本化自動存檔。重新進場的回缸紀錄可以定位個體。裝飾使用左、中、右固定位置，玩家間交易維持延期。
- 接上原創合成雙層主曲、水聲與事件音效。四組音量獨立保存。真機耳機、喇叭的十分鐘聽感與第一胎後的玩家試玩仍待驗收。
- L1／L2 使用 `godot --headless --editor --import`、`godot --headless --fixed-fps 60 --script res://tools/check_care.gd`、`godot --headless --script res://tools/check_preview.gd`。養成檢查以可控時間驗證投餌、孵化、成年、第一胎、回缸無重複獎勵、擴缸及音量存檔。實際渲染 1280×720 與 1024×768 跑過養成流程，使用 Mesa llvmpipe 與 Dummy 音訊。手動驗收後再跑完整回歸。
- 主要檔案為 `scenes/care.tscn`、`scripts/care.gd`、`scripts/care_state.gd` 與 `scripts/tank_audio.gd`。實作基準 `f2f7c056`，養成專案和根目錄入口未提交。

## 2026-11-21｜master｜淡水魚外觀擴充

- 依なちゃっと水族館的淡水魚參考新增 8 尾魚。三尾紅蓮燈沿一條路線群游，三尾七彩神仙以藍、紅、綠松石配色區分，雌雄オイカワ各一尾。保留四尾鬥魚，主缸共有 12 尾。
- 三種新增魚使用獨立的可編輯 3D 幾何與像素 Shader。共用游動、點魚、收起與放回行為。新增展示目前是預覽內容，養成、繁殖和出售仍按後續里程碑接入。
- L2 通過。 `godot --headless --editor --import` 完成匯入，`godot --headless --script res://tools/check_preview.gd` 通過名稱、配色、群游位置、深度點選、縮放和新舊魚收放。Xvfb / GL Compatibility 在 1280×720、1920×1080、1024×768 通過相同冒煙流程。畫面見 [12 尾同缸](docs/freshwater-tank.png) 和 [新魚點選](docs/freshwater-fish.png)。Windows 硬體效能待試玩。
- 新場景為 `scenes/cardinal.tscn`、`scenes/discus.tscn` 和 `scenes/pale_chub.tscn`。作者工具和參考授權見 [README](README.md)。基準 `f2f7c056`，專案仍未提交。下一階段接魚卵、孵化、餵食、成熟與本機存檔。

## 2026-11-21｜master｜滿版主缸與點魚操作

- 改成滿版透視水族箱，加入有深度的前景水草、石頭、沉木與底砂。四尾鬥魚沿 X、Y、Z 移動，近處個體自然放大。魚名、狀態與操作從點魚面板顯示。
- 滾輪或左下按鈕縮放 82%–200%，點數字重設。射線選擇重疊魚最前的一尾。收起與放回已可操作，狀態保留於當前執行。繁殖與出售等待各自的系統。
- L2 通過。`godot --headless --editor --import` 無匯入錯誤；`godot --headless --script res://tools/check_preview.gd` 通過。Xvfb 實際渲染 1280×720、1920×1080、1024×768，皆通過滿版、魚的深度、滾輪／重設、重疊點選、收起與放回檢查。畫面見 [滿版魚缸](docs/fullscreen-tank.png) 和 [點魚選單](docs/fish-selection.png)；Windows 桌面端待玩家試玩。
- 主要入口為 `scenes/aquarium.tscn`、`scenes/tank.tscn`、`scenes/betta.tscn`，編輯位置與指令見 [README](README.md)。下一階段接 M1 魚卵、投餌、成年與本機存檔。新專案與根目錄入口仍未提交。

## 2026-11-21｜master｜M0 外觀原型

- 完成四種鬥魚同缸、3D 魚身與尾鰭、像素鱗片、月牙遮罩與視角反光。魚可游動、轉身、展鰭，提供分區對照、自由游動與暫停。
- 主缸、魚與介面為可編輯的儲存場景。模型暫用 Godot 原生 Mesh 資源與幾何源檔，GLB 製作流程待後續資產工作。
- L1 驗證通過。`godot --headless --editor --import` 成功；`godot --headless --script res://tools/check_preview.gd` 通過四表型、預覽控制及卡片間距檢查。三個場景在儲存與重載後節點數分別為 20、256、282。
- 以 Xvfb / GL Compatibility 在 1280×720 與 1920×1080 執行同一冒煙檢查，兩者通過。檢視側身及轉身畫格，720p 錄影為 312 幀、24 FPS、13 秒。畫面見 [M0 預覽](docs/m0-preview.png)。測試使用 Mesa llvmpipe，實際硬體效能與玩家辨識試玩仍待驗收。
- 下一步是 M1。先接個體與魚卵資料、孵化盤、投餌／成熟與本機存檔。繁殖、擴缸、裝飾購入及離線結算依里程碑實作，玩家交易排在單機養成之後。
- 工作區狀態為新專案與根目錄入口未提交。實作基準 `f2f7c056`。重要檔案見 [README](README.md)、[首版規格](design/SPEC.md) 與 [執行方案](design/IMPLEMENTATION.md)。
