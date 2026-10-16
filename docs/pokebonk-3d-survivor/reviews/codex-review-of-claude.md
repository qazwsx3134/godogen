# Claude 文件審查工作紀錄（未完成）

狀態：這是第 2 輪審查的 checkpoint，記錄目前已核實的項目與未完成清單，不代表最終審查完成。遵照派工單，只新增本檔；沒有修改 README、live-play-notes 或其他既有文件。尚未建立 `CODEX_REVIEW_DONE`。

## 審查範圍與證據標記

審查對象：

- `/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/README.md`
- `/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/live-play-notes.md`

靜態對照來源：

- `main:行號` = `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/raw/pretty/main-B44dxb_5.js`
- `assets:行號` = `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/raw/pretty/assets-CRegv5Cl.js`
- `css:選擇器` = `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/raw/main-BVzI46Dj.css`
- 截圖只讀自 `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/`。

沒有連線網站、開 WebSocket 或將素材抽進 repo；沒有執行測試。

## 已核實的事實錯誤／需降級的陳述

| 嚴重度 | 文件陳述 | 對照結果與證據 | 建議修正方向 |
|---|---|---|---|
| 高 | README 與 live notes 都說所有 Combo 不影響數值、只跳橫幅。 | 存在 `Tempestade Divina` 特例，包含 `dragonpulse`、`twister`、`judgment`；兩件時倍率 0.85，三件時 0.6，且乘進武器傷害。`main:3601`、`main:7887-7894`、`main:7914-7921`、`main:7391-7398`。 | 改成「多數組合用提示／卡片呈現；`Tempestade Divina` 會對相關招式套用 0.85／0.6 傷害倍率」，並指出這是懲罰倍率而非純 UI 組合。 |
| 高 | README 與 live notes 說 Alpha 與 Boss 掉的球都免費。 | 預設 `alphaFree:0`；設定說明明示預設只有 Boss 球免費，Alpha 球可選擇改免費。Alpha 死亡呼叫使用 `!!he.alphaFree`；Boss 至少掉兩顆免費球。`main:3896`、`main:18121`、`main:30508`、`main:30455-30466`。 | 寫清楚：地圖球付費、Boss 掉球免費；Alpha 球預設付費，開啟設定後才免費。 |
| 高 | live notes 說 Pikachu Gigantamax +80% 傷害。 | Mega 預設 damage 加成是 0.6（+60%），攻速 +30%、尺寸 +20%、移速 +15%、數量 +1、護甲 +15%；持續 20 秒。`main:3389-3397`、`main:18112-18122`。 | 將 +80% 改為 +60%；保留其餘加成若有篇幅，並標註這是全局預設，角色外型可能另有差異。 |
| 低 | live notes 把 Boss 間隔寫成約 85 秒。 | 名義預設首隻與間隔都是 90 秒。實玩觀察可能是近似讀值，尚不能證明它是設定錯誤。`main:2994-2995`、`main:29959-29963`。 | 保留實玩讀值但標「約略觀察」；與程式預設 90 秒分開寫，說明觀察的是倒數、出場或擊殺時刻。 |
| 中 | live notes 將所有模型描述為 Draco 壓縮。 | bundle 有設定 `/draco/` decoder，並將 GLTFLoader 設為使用它；這只能證明支援 Draco，不能從 bundle 證明每個 GLB 都用了 Draco。`assets:33268-33276`。 | 降級成「載入器配置 Draco decoder；各模型是否壓縮未逐檔核實」。 |
| 中 | README 與 live notes 稱 VFX 貼圖檔名與 Kenney Particle Pack 一致，因此 Godot 可直接按 CC0 使用。 | bundle 可見執行時使用貼圖 ID（如 `star_06`、`star_04`）；檔名相似不能證明來源、版本或授權。`main:5826`、`main:6071`。 | 將 Kenney／CC0 改標「待來源與授權核實」；確認原始檔或授權紀錄前，不宜寫成可直接再用。 |
| 中 | live notes 說排行榜由伺服器驗證整局。 | bundle 顯示 client 發送 `/runs/start` 與週期性 `/runs/tick`，只能證明有提交資料，不能單靠 client bundle 證明 server 的驗證深度。`main:29699-29729`。 | 改為「客戶端提交 run 起始與 tick 資料；伺服器驗證規則與防竄改方式未由此 bundle 證實」。 |

已確認為正確或大致一致：22 個任務、六種天氣、預設 90 秒 Boss 節拍、Mega 20 秒／每滿條延長 12 秒／上限 40 秒（2 倍基礎時間）。`main:4562-4713`、`main:6382-6440`、`main:2994-2995`、`main:3390-3396`。

## 覆蓋缺口盤點（尚待整理成最終審查表）

### 美術

| 嚴重度 | 缺口與來源 | 建議補入的內容 |
|---|---|---|
| 中 | 兩份文件有一般性的 toon／描邊／後製描述，但尚未記下具體 UI 視覺語言。CSS 使用 Chakra Petch 與 Silkscreen、黃／海軍藍／紅色 token、斜切按鈕、紅色偏移陰影、斜紋與網點背景。`css::root`、`css:.btn`、`css:.char-card`、`css:.card`。 | 加一句可重現的樣式摘要：字體、主要色票、切角、按鈕陰影，以及角色卡／升級卡用的網點和 3D 傾斜。 |
| 中 | 未記錄場景材質與環境實作：toon 使用三階 gradient map；畫面後製有獨立 outline pass；地面有頂點色與多尺度噪聲／陡坡混色，水面依深度混色並疊噪聲與泡沫，草片用 instance shader 擺動，天空用漸層 dome；光照、霧與陰影也有明確設定。`main:8035-8043`、`main:32153-32160`、`main:8413-8449`、`main:8452-8502`、`main:8665-8705`、`main:8801-8816`、`main:8834-8859`。 | 增加「3D 場景配方」：toon 與輪廓分開說明，再用短句記錄草地、水、天空、霧、暖色主光／環境光和陰影品質。 |
| 中 | 模型高度／相機距離設定和貼圖替換方式未記錄；通用路徑清單不足以支持移植。角色資料按模型設定 `fit.height`、`camDist`，載入器另對 `/models/swsh/tex/` 貼圖做替換。`main:16088-16124`、`assets:33268-33276`、`assets:33337-33350`。 | 增加一句說明每角色有高度與取景距離 metadata，SwSh 材質可按材質名替換貼圖；把 Draco 改成「載入器支援，逐檔壓縮狀態未核」。 |
| 低 | 文件列了 `/sprites/items/`、`/sprites/types/`、`/sprites/home/`，但還沒整理各自用在哪裡，以及圖鑑／角色卡／升級卡的表現差異。`main:3997-3999`、`css:.char-card`、`css:.card`。 | 用一行對應圖示家族用途，補充卡片使用稀有度色帶、角色色彩變數與傾斜互動。 |

### 機制

| 嚴重度 | 缺口與來源 | 建議補入的內容 |
|---|---|---|
| 中 | 沒寫地圖球成本公式。基礎式是 `round((12 × 1.32^opened + 4 × opened) × rarityMultiplier)`，再與持有金額比例最低價比較；稀有度倍率為 1／1.6／2.5／4／6.5。`main:3875-3896`、`main:27080-27085`。 | 增加公式及一句「高稀有度另受目前金額比例最低價約束」，避免只說球會愈來愈貴。 |
| 中 | Bonk 只列出神殿、商人、微波爐名稱，缺少互動與價格。商人 3 格、稀有度基價 25/40/70/120/200，會依時間與關卡加價；微波爐成本 `45 × 1.7^使用次數 × (1 + 時間/900)`，複製持有物品；充能神殿讓玩家留在圈內 4 秒後給三選一永久本局增益。`main:3079-3080`、`main:28808-28825`、`main:28842-28895`、`main:28700-28715`。 | 加一段 Bonk 設施的效果與遞增費用；標明神殿增益只持續本局。 |
| 中 | 任務總數正確，但兩份文件沒有任務條件與獎勵摘要。`main:4562-4713`。 | 加任務分類與幾個代表例：單局擊殺／進化／Boss／模式條件及累積 run／擊殺／勝場解鎖。 |
| 中 | 未記錄結算評級公式。勝利為 S，Boss 獎牌平均值達 0.85 才升 S+；失敗依時間門檻 450/270/120 秒給 A/B/C，其餘 D。`main:22582-22587`。 | 用一句列明勝利與失敗兩套條件，避免只說「結算有評級」。 |
| 中 | 未區分本作屬性規則與寶可夢標準屬性相剋。傷害路徑確定套用同屬性 STAB 與天氣增減益；敵人天氣親和度影響速度／傷害／受到傷害，沒有證據顯示一般攻擊套用完整攻防屬性表。`main:30364-30366`、`main:6559-6574`。 | 寫清楚「可見的是 STAB 與天氣親和加成；不要直接假設有完整 Pokémon type chart」。 |
| 中 | 沒有狀態效果表：目前看到 burn／地面燃燒區、slow、stun 及 Boss 部分免疫條件。`main:8933-9017`、`main:9073-9101`、`main:7944-7947`。 | 增加狀態名、持續時間／觸發方式、對 Boss 是否有效的簡表。 |
| 中 | berry／magnet 只散見實玩紀錄，缺機率與效果：berry 基礎擊殺率從 0.6% 線性降至 0.08%（600 秒），至少間隔 12 秒，基本回復 25% HP；未掉 berry 時另有 0.25% 磁鐵機率。Boss 固定掉磁鐵。`main:3810-3811`、`main:30534-30535`、`main:30461-30466`。 | 補掉落率與晚期下降規則，說明 Normal 磁鐵吸 XP／錢，Hard 額外可吸部分 berry。 |
| 中 | README 建議先跳過 8 人連線，卻未留合作／Duel 的現有數值基線。合作每多一人：敵 HP +60%、Boss HP +85%、生怪率 +30%、敵傷害 +7%，活敵上限 +8% 並封頂 1.5 倍；Duel 以擊殺數累積派 Alpha。`main:3602-3614`、`main:7147-7155`、`main:17844-17855`、`main:3046`、`main:29311-29329`。 | 加一段移植時可沿用的多人調整基線，並說明 Duel 每 30 次擊殺首發、往後門檻漸增，Alpha 數量逐次增至上限 4。 |

### 特效實作

| 嚴重度 | 缺口與來源 | 建議補入的內容 |
|---|---|---|
| 中 | 文件記了通用粒子池／Boss 階段，仍缺招式特效到幾何／粒子／命中的對照。雷擊以 beam 段連鎖；火焰是高穿透長存 projectile 加 muzzle flash；水炮進化版是雙 beam 與沿線煙；Twister 以移動物件帶旋轉 `twirl` 貼圖；Judgment 先落地 telegraph 再發 22m 光柱；Surf 是向外擴大的 ring。`main:13312-13370`、`main:13371-13505`、`main:13506-13577`、`main:13780-13879`、`main:13880-13957`、`main:14256-14332`、`main:15477-15494`。 | 增加一張「招式—視覺實作」代表表，避免只列貼圖名稱；至少涵蓋連鎖閃電、火、水、旋風、光柱／波圈。 |
| 中 | Boss 預告只描述成「地面危險區」，未寫出 mesh 與時序。圓形 strike 是地面 decal；衝撞是約 30m 長、0.9 秒的半透明平面；砸地危險半徑 7.5m、延遲 1.15 秒。`main:6171-6198`、`main:26395-26400`、`main:26700-26754`。 | 補各預告形狀、寬長／半徑、顏色與預告秒數，再列命中後柱體、粒子、震屏。 |
| 中 | 命中／死亡／升級進化／Mega 視覺只零散描述，缺事件序列與參數。進化會 hit-stop 0.5 秒、FOV kick 10、flash、擴張 decal／柱體；Mega 是 0.7 秒 hit-stop、FOV 14、60 粒子、五色 rings、40m 柱與半徑 14 impact。Boss 死亡有 poof、60 粒子 burst、柱體、impact、0.4 秒 hit-stop。`main:31148-31175`、`main:30761-30814`、`main:30455-30461`、`main:30338-30355`。 | 把每個事件寫成短序列（預告 → 命中回饋 → 結束）並列出關鍵時間與尺寸；一般升級卡是 UI 暫停覆層，選牌另有 burst／ring／flash。`main:31030-31038`、`main:31117-31148`。 |
| 中 | 天氣文件已提粒子參數，但未寫出自訂 point shader、相機周圍循環粒子框與 shader shape 的方法；另有 fog/tint 漸變。`main:6382-6440`、`main:6460-6670`。 | 補一句實作方式：相機座標為中心包覆粒子、shader 隨時間更新位置；雨／風用線形 alpha，其餘用圓形點，切換時同步漸變霧與畫面 tint。 |
| 中 | 已描述 XP／coin 外觀，但沒有完整寫出 pickup 動畫：拋物線彈跳、停下後旋轉浮動、進入拾取範圍後加速吸附；球體與天空光柱會浮動／閃爍。`main:26963-27150`。 | 增加上述動畫與磁鐵吸附規則；說明其為遊戲邏輯更新，不只是 sprite 特效。 |
| 低 | 相機與 hit-stop 只有總結，缺玩家受傷、連殺、Mega／進化的強度差異。`main:30338-30355`、`main:30513-30520`、`main:30761-30775`、`main:31148-31155`。 | 以事件列出 micro-stop／hit-stop、shake、FOV kick、flash 的時長／幅度，保留設定滑桿可覆寫的說明。 |

## Godot 移植建議：暫記風險

| 嚴重度 | 現有建議 | 審查註記／修正方向 |
|---|---|---|
| 中 | 「GPUParticles3D 會改動全域亂數，因此平衡基準要在加粒子後再拍。」 | bundle 本身不能證明 Godot 的 RNG 行為；這句目前無來源且不宜當成專案教訓。改為以注入／固定的遊戲 RNG 做 A/B 對照，或先在目標 Godot 版本文件／小型驗證中證實再保留。 |
| 中 | 主角 outline 用 `no_depth_test` 的 `next_pass` 永遠蓋在最上層。 | 技術上能達成「Always see my Pokémon」，但會穿透所有深度遮擋物；文件需註明這是刻意的可見性設計。若只要穿透草和特效，改採遮擋層／深度規則，避免穿牆顯示。 |
| 中 | hit-stop 可用全域 `Engine.time_scale`。 | 單人原型可行，但會一起改變其他使用 scaled delta 的節點／Timer；連線模式尤其會造成模擬時間與網路 tick 不一致。優先建遊戲層時鐘或短暫凍結 world processing，UI 與網路處理維持獨立。 |
| 低 | 以 MultiMesh 批次大量一般敵人。 | 方向合理；最終文件需補清楚 MultiMesh 只負責 draw batching，不取代敵人的 CPU 狀態、碰撞、空間查詢與可編輯來源場景，且符合 repo 的 scene/node 規範。 |

## 尚未完成的審查工作

- 將上列工作紀錄整理成最終審查報告，逐項加上 `高／中／低`，控制重複並確保美術、機制、特效三類都完整。
- 收尾確認 README 的音效「確定沒有」說法及 live notes 的網路／音效推論；靜態 client 與單次網路記錄不足以證明伺服器端或所有執行時行為。
- 最終檢查引用行號、證據標記、絕對路徑與 diff，確認只有本 review 檔新增後，才依派工單建立 3 行摘要的 `CODEX_REVIEW_DONE`。

