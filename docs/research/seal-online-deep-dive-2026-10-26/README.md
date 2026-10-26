# 希望 Online：客戶端證據、遊戲拆解與 Godot 還原方案

研究日期：2026-10-26。研究對象：`D:\games\SealOnline`，WSL 路徑 `/mnt/d/games/SealOnline`。Godot 對照版本採本專案已指定的 **4.7**；目前 `seal-meadow` 使用 Compatibility renderer。

**製作方向：以手機執行與觸控為前提，採固定方向／俯角鏡頭、點怪追打與自動普攻，保留 Q 版角色、手繪場景、換裝／寵物／交易的長期循環。鏡頭旋轉與短連招不列入製作範圍，也不製作其他鍵序或節奏連招。**

2026-10-26 使用者已確認上述手機、鏡頭與連招範圍。完整操作、效能與驗收規格見 [手機製作基準](../../../prototypes/seal-meadow/design/mobile-production-baseline.md)。本報告的原作研究保留為參考，製作建議以該基準及本段為準；未標為已確認的細節仍是提案。

## 1. 研究範圍與證據強度

| 標記 | 意義 | 本次取得方式 |
|---|---|---|
| L | 本機直接驗證 | 檔案統計、ZIP central directory、WAV 標頭、可讀 `.fx` shader、版本檔 |
| O | 官方文件 | 美版操作／生存指南、韓版遊戲介紹與系統指南；地區與年代需分開 |
| R | 現有專案 | 舊研究、`seal-meadow` README／程式／儲存截圖、kit 純邏輯模組 |
| P | 本研究提出的方案 | Godot 架構、預算、製作順序、驗收條件；不是原作內部實作的宣稱 |
| U | 尚未量測／確認 | 當前美版精確機率、連招時間窗、FOV、技能逐幀事件、伺服器協定 |

本次沒有登入或實際操作遊戲、沒有取得原作伺服器程式、沒有量測執行中封包，也沒有解密封裝。`capture/` 是空的。先前研究提及的使用者截圖本次未重新取得，因此不把它當成新畫面驗證。檔名只能證明資源被封裝，不能證明目前已啟用、實際出現次數或遊戲規則。

可重現證據見 [client-inventory.json](client-inventory.json)。執行唯讀盤點：

```bash
python3 docs/research/seal-online-deep-dive-2026-10-26/inventory_client.py \
  /mnt/d/games/SealOnline \
  --output /tmp/seal-client-inventory.json
```

本報告擴充 [先前玩法研究](../seal-online-2026-10-26.md)。先前文件中的命中公式、精煉機率、寵物經驗等主要源於社群 Wiki，**本次不將那些數字升格為現行美版規格**。

## 2. 客戶端實際告訴我們什麼

### 2.1 資源分工與規模（L）

以下 MiB 是磁碟上的封裝大小，不是解壓大小或 GPU 記憶體需求。

| 封裝 | MiB | 目錄項目 | 代表線索 | 對製作的啟示（P） |
|---|---:|---:|---|---|
| `actor/actor.SPAK` | 69.04 | 1,722 | `.an1` 1,331、`.bn1` 115、`.ms1` 148 | 角色動作與外觀資料分開管理 |
| `wear/wear.SPAK` | 403.19 | 11,578 | `.ms1` 5,517、`.tex` 3,351 | 換裝是龐大素材系統，需要共用骨架與插槽標準 |
| `monster/monster.SPAK` | 422.34 | 8,099 | `.an1` 3,465、`.ms1` 1,046、`.bn1` 956 | 怪物不只是靜態圖，需要完整動作集 |
| `map/map.SPAK` | 569.33 | 7,613 | `.map` 176、`.ms1` 3,525、`.tex` 2,054 | 分區地圖、道具、表面材質各自製作 |
| `map/minimap/minimap.SPAK` | 32.92 | 497 | `.tex` 149、`.edt` 232 | 小地圖有獨立素材／設定，不必每幀重畫整個世界 |
| `interface/interface.SPAK` | 116.65 | 1,506 | `.men` 306、`.spr` 199、`.tex` 628 | UI 是獨立而龐大的資產與版面系統 |
| `sfx/sfx.SPAK` | 163.28 | 4,013 | `.tex` 3,290、`.shader` 55 | 此封裝大量內容是視覺特效，不能把 sfx 一律解讀成音效 |
| `skill/skill.SPAK` | 66.13 | 3,988 | `.an1` 1,657、`.ms1` 1,664 | 技能包含動畫／幾何類資源線索，不能只靠粒子數量重現 |
| `etc/etc.SPAK` | 133.78 | 764 | `.edt` 514 | 遊戲資料需有結構化表格與關聯檢查 |
| `item/item.SPAK` | 19.91 | 132 | 圖示 atlas、`.ms1` 35 | 圖示檔數不是道具種類數 |
| `resource/resource.SPAK` | 12.07 | 175 | `.tex` 140 | 另有共用資源集合 |

合計 **11 個封裝、40,087 筆非目錄項目**。所有項目的 ZIP 加密旗標均開啟；本次只讀取公開的封裝目錄，不嘗試讀取受保護內容。副檔名用途是依命名推測，未驗證 `.an1/.bn1/.ms1` 的格式定義。176 個 `.map` 也不能直接等同 176 個可玩區域。

地圖目錄可見 `207_lightmap.dds`、`210_lightmap.dds`，能確認有 lightmap 命名的資產；不能推成所有場景都使用相同烘焙方式。`etc` 可見 `equipmentrefine.edt`、`gemrefine.edt`、`pet_decomposition.edt`、`guarder.edt`、`jobstat.edt`、`quest.edt`、`usaquest.edt` 等，支持系統化拆分，但未取得表內數值。

### 2.2 音訊、字型與版本（L）

- `bgm/`：67 個 MP3，共約 186.99 MiB。這是檔案量，不代表 67 個區域或 67 首互不相同的曲目。
- `sound/`：2,909 個 WAV，另有其他檔案；資料夾共約 458.87 MiB。Python 標頭解析出 1,850 個 44.1 kHz／mono／16-bit，936 個 22.05 kHz／mono／16-bit，64 個 48 kHz／stereo／24-bit；其餘格式見 JSON，27 個無法由 Python `wave` 解析，不等於檔案損壞。
- `UIfont/`：8 個 TTF，包含 Inter、Tahoma、Maplestory、思源系以外的繁中字型檔名。檔案存在不代表每一個畫面都使用它，也未確認再分發授權。
- 美版版本檔記載建置日期 `20/10/2026`；x64 版本巨集是 `1.0.35.0`，另一檔是 `0.0.160.1`。這是本機建置標記，不是伺服器更新完成與否的證明。

### 2.3 三個可讀 shader 的直接線索（L）

| 檔案 | 可直接讀出的運算 | Godot 對應（P） | 仍未知的部分 |
|---|---|---|---|
| `so3deffect.fx` | `VSScale` 將 view-space 頂點沿法線外擴；`TOutLine` 設定反向面剔除；另有選取外擴與加色 pass | 外殼式描邊、選取材質、加色 overlay | 哪些物件／狀態實際套用與參數值 |
| `TextOutlineGlow.fx` | 多方向 alpha 取樣形成描邊，鄰域加權形成 glow | Label 的字體描邊；特殊發光用隔離 viewport 或局部 shader | 實際使用的 technique 與 UI 元件 |
| `phase.fx` | noise、progress、smoothstep、邊緣增亮；同檔另有文字描邊組合 | noise 閾值消融＋邊緣色，Tween 控制進度 | 用在文字／UI／角色的哪一類情境 |

尤其 `phase.fx` 同時含文字相關參數，因此不能只因名稱就宣稱它是怪物死亡消融。Godot 重寫的是效果原理，不是直接載入 DX9 `.fx`。

## 3. 遊戲的核心吸引力

官方將 Full 3D 卡通呈現、連招、聲望、寵物與情侶列為特色。[韓版官方遊戲介紹](https://www.sealonline.co.kr/Guide)

從系統關係看，值得還原的是以下循環（P，依已知玩法整理）：

```text
出城選獵場 → 點怪追擊 → 普攻／連招 → 經驗、裝備、材料
    ↑                                      │
    │              ┌───────────────────────┘
    │              ↓
    └─ 變強 ← 換裝／技能／寵物／精煉 ← 回城整理與交易
                     │
                     └─ 外觀、稀有收藏、朋友與公會 → 長期目標
```

原作連招在此保留為研究紀錄。手機版以選目標、技能時機、走位與清楚的命中聲畫回饋提供戰鬥參與感；角色表演、成長循環及城市社交仍需分別驗收。

## 4. 視覺、場景與角色：如何做出相近效果

### 4.1 先決定完整 3D 或預渲染角色（O/R/P）

| 面向 | 完整 3D 角色 | 3D 場景＋預渲染 2D 角色 |
|---|---|---|
| 自由轉鏡頭 | 連續角度、輪廓與光照自然改變 | 4／8 方向切換，可增加方向但素材量增加 |
| 換裝 | 共用 Skeleton／Skin，換 mesh 或掛配件 | 每個裝備要覆蓋各方向、動作、幀，處理前後層 |
| 武器／身體遮擋 | 深度測試自然處理 | 單一平面深度不能表達身體內部的前後交錯 |
| 跑步／技能混合 | AnimationTree、骨架混合 | 要預先渲染或接受有限轉接 |
| 地形與投影 | 可取得實際動態影子 | 通常用腳底軟影，無法完全對應姿勢 |
| 初期成本 | 建模、綁骨、權重、動作規範 | 先做少量圖可快；大量換裝後成本未必低 |
| 本案定位 | 高相似度長期方案 | 現有 `seal-meadow` 的玩法驗證方案 |

**手機固定鏡頭方案：沿用現有 3D 場景＋預渲染 2D 角色作為首輪驗證基線。** 鏡頭固定後，完整 3D 不再是旋轉需求帶來的前提；是否改用 3D 角色，改由換裝產量、動畫維護、記憶體與手機實測決定。固定鏡頭不代表角色只有一個方向：角色仍須顯示面向與背面。顯示層可透過 `play_action`、`set_equipment`、`set_selected` 等介面抽離；這是方案建議，不表示現有程式已具備這些介面。

預渲染成本範例：8 方向 × 6 動作 × 每動作 8 幀 = 每層 384 格；每格 128×128 RGBA8 約 24 MiB 基礎像素，加完整 mipmaps 約 32 MiB，尚未計壓縮與 atlas 空隙。10 種武器各做一層就要維護 3,840 格。這是示意預算，非原作素材規格。

### 4.2 角色比例、卡通材質與描邊（P）

先以同一張原作畫面量出「角色高度／畫面高度、頭／身體、武器／身高」再建模；2.5～3 頭身只能作初稿，不能當成已測得的原作比例。美術方向是輪廓清楚、頭與手部表情可讀、武器帶性格、表面偏手繪而非寫實金屬。

Godot 起點可用低 metallic、高 roughness 的 `StandardMaterial3D`，比較 Toon／Lambert 與自訂亮暗 ramp；避免把皮膚、草地一律做成沒有明暗的 unshaded。輪廓用第二 pass 反向剔除並沿法線外擴；法線接縫需修，遠近線寬要比較。官方材質文件有 Grow＋Cull Front 的作法。[Godot 材質文件](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html)

固定世界單位的外擴會隨距離變細；要較穩定的像素線寬，可在 view／clip space 計算投影偏移，按 viewport 與深度補償。這需要在目標 renderer 實測，不能直接把原作 `GlowThickness=0.01` 搬成 Godot 的同值。

### 4.3 換裝、臉與髮型（P）

- 素體、上衣、下身、鞋、頭髮共用骨架名稱、rest pose、比例與 Skin bind 標準。變形衣服走蒙皮 mesh；劍、盾、帽飾等剛性配件可用 `BoneAttachment3D` 跟隨指定骨頭。[BoneAttachment3D](https://docs.godotengine.org/en/stable/classes/class_boneattachment3d.html)
- 長袍遮住腿部、帽子遮住頭髮時，用裝備資料的 body-region mask 隱藏被覆蓋 mesh，減少穿模。
- 戰鬥裝備數值與時裝外觀分開：`equipment_stats` 與 `appearance_override`；切外觀不觸發不相關的屬性變動。
- 眼睛／嘴可用 UV atlas 切換眨眼與表情。臉型需要時才引入 blend shape；先用少量可讀表情驗證。
- 每件裝備以標準展示 scene 檢查待機、跑步、揮砍、睡覺、正背側與各縮放距離；先驗一套完整裝備再量產。

### 4.4 動畫與角色表演（P）

動作表至少涵蓋 idle、walk/run、attack、combo steps、cast、hit、death、sleep、sit/emote；不同武器需要各自的握持與攻擊姿勢。動畫使用預備、出手、接觸、回收四階段，先保證接觸幀對齊，再增加彈性、誇張後仰與喜劇反應。

`AnimationPlayer` 保存動畫與事件軌，`AnimationTree` 負責混合／狀態切換；後者不儲存自己的動畫。[Godot 動畫樹](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html) 單機可讓動畫事件提出命中請求；多人由伺服器時間表決定結果，畫面動畫只表演。不要同時讓動畫事件與攻擊計時器各扣一次血。

### 4.5 場景與地形（L/P）

原作 lightmap 檔名提供了烘焙照明的參考。Godot 可採手繪 diffuse、頂點色、簡單太陽光、局部烘焙明暗；先把大面積地色、路徑、樹冠陰影做對，再加草與花。草原、城鎮、洞窟以區域 scene 分開，入口與出生點是編輯器中的實際節點。

地表以較平滑的色塊／貼圖過渡建立尺度感；有意義的坡度影響視線與路線，碰撞 mesh 與裝飾 mesh 分開。樹與石的輪廓應有圓潤手繪感，不能只靠隨機三角面。`seal-meadow/preview.png` 是儲存的舊預覽：其鮮綠三角地面、寫實比例劍士與簡單 HUD 仍是原型風格，不能當作已完成的希望 Online 視覺驗收。

大量草、花、重複石頭用分區 `MultiMeshInstance3D`；不要整張地圖只放一個 MultiMesh，因為其個別 instance 不會獨立做視錐剔除。[MultiMesh 限制](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) 該頁標有 4.7 更新尚未完成，實際預算以 profiler 為準。

### 4.6 鏡頭、遮擋、天空與水（O/P）

官方操作是點地移動、右鍵拖曳旋轉、滾輪縮放、中鍵朝北。[美版操作指南](https://sealonline.playrohan.com/background_new/basic_controls.html) 上述旋轉／縮放只記錄原作。手機版用 `CameraRig → Camera3D` 保存固定 yaw、pitch 與基準距離，跟隨玩家平移；不綁定右鍵、拖曳或雙指旋轉，首版也不要求手勢縮放。鏡頭俯角、距離、FOV、跟隨速度保留為編輯器 export 欄位。正交與透視可用固定地標比較後選擇；不同長寬比以構圖調整與 safe area 保持可讀，不依賴玩家轉鏡頭找路。

近牆時以鏡頭 ray／shape cast 限制距離；必要時對遮住玩家的前景道具淡化。畫面遮擋處理與伺服器視線／可達性分開。天空、遠山、距離霧負責深度；黃昏可變天空與光色但保留角色可讀性。水先用平面＋UV 捲動波紋＋岸邊透明漸層，反射等高階效果等目標平台確定後再做。

## 5. 戰鬥、玩法、成長與經濟全景

下表是面向清單及 Godot 方案；精確參數仍以目標版本實測為準。官方指南確認普攻／連招、睡覺回復、HP／AP、升級點數、掉落與任務等基本循環。[美版生存指南](https://sealonline.playrohan.com/background_new/survival_guide.html)

| 面向 | 要還原的體驗／規則 | Godot 實作方式（P） | 驗收重點 |
|---|---|---|---|
| 點地移動 | 一次點擊走向目標，繞過障礙 | Camera raycast 命中地面；NavigationRegion3D＋NavigationAgent3D＋CharacterBody3D | 不穿牆；不可達點可取消；到點不抖 |
| 點怪追打 | 鎖定後追到攻擊距離並持續攻擊 | TargetController＋Move/Chase/Attack 狀態；目標 entity id | 換目標、死亡、出區時即時清理 |
| 原作連招（研究參考） | A/S/D 序列、同按鍵、時機與收尾回饋 | 手機製作範圍不接入；戰鬥採點怪追打、自動普攻與少量技能按鈕 | 不要求連按／雙鍵／節奏輸入；手感由命中演出與技能時機驗收 |
| 命中與傷害 | miss、暴擊、防禦、屬性與職業差異 | 純資料公式與 seeded RNG；伺服器生成 CombatEvent | 同一事件僅結算一次；視覺與血量一致 |
| 技能 | 施放、AP、冷卻、距離、範圍、buff | SkillDefinition Resource＋CastCommand＋EffectResolver | 超距、施法中斷、AP 不足、死亡取消 |
| 怪物 AI | 待機、巡邏、警戒、追擊、攻擊、回家、重生 | FSM；出生點、仇恨半徑、leash、respawn 存在 scene／資料 | 無法到達時返回；不無限追殺 |
| 首領／副本 | 場地、技能循環、隊伍配合、掉落 | EncounterDefinition＋時間線＋InstanceContext | 階段可讀；重置／團滅／重連一致 |
| 職業／轉職 | 武器、技能與成長路徑 | JobDefinition、技能圖、轉職條件驗證、任務 gate | 不把所有職業做成僅倍率不同 |
| 經驗／屬性 | 升級、配點、HP/AP 與成長差異 | ProgressionCurve＋StatBlock；base/gear/buff 分層 | 升級預覽與結果一致；洗點不重複加成 |
| 裝備／背包 | 欄位、堆疊、拖拉、比較、容量 | ItemDefinition＋具唯一 ID 的 ItemInstance；ItemSlot scene | 拆堆、取消拖曳、滿包、裝備限制 |
| 掉寶／拾取 | 地上物、拾取優先權與消失時間 | LootTable＋LootDrop scene；owner/grace/expiry | 距離／權限／滿包檢查，拾取去重 |
| 精煉／製作 | 投入材料、機率、成功／失敗後果 | RefineRule、Recipe、InventoryTransaction；結果由權威端產生 | 斷線重送不重複扣料；保護道具處理正確 |
| 寵物養成 | 飢餓、餵食、經驗、進化與陪伴 | PetDefinition/PetState；時鐘驅動照護；外觀漂浮跟隨 | 區域暫停、卸裝、升階、離線規則明確 |
| 戰鬥寵物 | 與養成寵物不同的作戰單位 | 獨立 Entity＋技能／仇恨／跟隨策略 | 不把 cosmetic pet 與作戰 AI 混成同一狀態 |
| 守護者／移動外觀 | 擁有、裝備、乘坐、加成等需分清 | CollectionState、MountState 與 StatModifier 分離 | U：美版具體加成與取得規則待查 |
| 光環／時裝 | 角色身分、稀有與炫耀 | Attachment scene、外觀欄、材質與 VFX LOD | 換外觀不誤改數值；人多時效果可裁減 |
| 任務／主線 | 對話、打怪、收集、提交與世界故事 | QuestDefinition＋條件／目標狀態；Dialogue graph | 接／完成／領獎互斥且只領一次 |
| 聲望 | 與等級並行的社會／裝備門檻 | FameLedger＋rank thresholds＋需求條件 | 不拿 EXP 或貨幣欄代替；顯示下一門檻 |
| NPC 商店／銀行 | 買賣、存取、旅行前準備 | VendorCatalog、BankService、價格與容量資料 | 價格由權威端算；存取不複製物品 |
| 玩家交易／擺攤 | 玩家自己形成市場與城市活動 | Offer/Lock/Confirm/Commit；物品鎖定、原子交換 | 任一方改價撤銷雙方確認；斷線可回復 |
| 隊伍／公會／聊天 | 合作、資訊流與社交身分 | Party/Guild service＋channel chat＋member model | 權限、邀請、離線、分配與頻道隔離 |
| 情侶／表情／休息 | 共處、情感與角色生活感 | RelationshipState、雙人互動 anchors、emote scene | 同步姿勢、取消、距離、離線狀態 |
| 釣魚 | 休息時仍有收集與投入產出 | FishingState＋餌消耗＋區域掉表＋結算時鐘 | 開始後移動／背包滿／斷線的規則 |
| 決鬥／PvP | 同意挑戰、公平範圍與獎懲 | DuelSession、PvP ruleset、獨立傷害倍率 | 不誤套 PvE 死亡懲罰；退出收尾 |
| 活動／登入／商城 | 日常回訪、限時內容與付費流程 | EventSchedule、RewardClaim、Catalog＋收據驗證服務 | 時區／補領／重複領取與購買去重 |

韓版官方指南索引有職業、日常、轉職、地區、副本／raid、寵物／戰鬥寵物等分類；官方共通技能搜尋內容也列出交易、隊伍、釣魚、銀行、擺攤與決鬥。這可支撐面向盤點，但不能把韓版等級門檻直接當成美版規則。[韓版官方指南索引](https://www.sealonline.co.kr/Guide/Info?seq=20)

### 5.1 移動與戰鬥的幾個容易漏掉的細節

NavigationAgent 只算路與提供避讓功能，不會自動移動父節點；角色需在 physics tick 取下一路點後自行更新速度。到達後停止取路點以免抖動，並等待 navigation map 初始同步再發第一個查詢。[Godot 導航代理](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html)

追怪時不要每幀完整重算所有人的路徑；以目標位移或時間間隔重查，接近敵人時採攻擊半徑＋遲滯避免 Chase/Attack 來回跳。觸控優先順序明定為 UI → 可互動物／目標 → 地面。每根手指追蹤獨立 touch index，按技能時不覆寫另一根手指的移動；聊天、拖曳、關窗等操作不可穿透到地面。

`seal-meadow` 目前的 WASD 是桌面測試輸入。手機版以點地移動、點怪追打為首輪提案；虛擬搖桿待真機測試後再決定。移動指令可中斷追打，技能依可否移動施放明定中斷行為。

### 5.2 原作連招與既有模組（研究紀錄，手機版不接入）

以下僅說明原作研究與 kit 能力，不是本遊戲待辦。手機版不製作連招條、A/S/D 鍵序、雙鍵輸入、節奏時間窗或短連招教學；普通攻擊可自然輪播不同揮擊動畫，但不構成額外輸入系統。

```text
普攻累積條 → 可開始 → 讀入單鍵／雙鍵 → 驗證序列與時間窗
                                  ├─ 合法 → 下一段／收尾
                                  └─ 錯誤、過時、目標失效 → 結束
```

`combo_input.gd` 已有 gauge、候選序列、和弦窗、時序與事件；目前 0.45 秒 beat、±0.15 秒 window、0.06 秒 chord window 是模組預設，**不是量測的希望 Online 數據**。每段還要連接角色攻擊、武器軌跡、hit spark、聲音、跳字與提示條。模組在最後一步可能同時回 `step` 與 `finish`；整合時須定義收尾加成如何併入同一擊，避免照事件各扣一次血。

本遊戲連線只需驗證選取／攻擊／技能命令、射程、冷卻與攻擊間隔，不加入連招序列同步。權威結果與本地演出的延遲仍需測量。

### 5.3 寵物、精煉與經濟應一起設計

寵物餵食可回收雜物；精煉消耗寶石與貨幣；交易讓玩家用不同專長互換資源。這是經濟循環的分析（P），不是已確認的原作產銷數據。

```text
怪物／任務 → 金幣、裝備、材料 → 裝備／交易／餵寵物
                    │                    │
                    └→ 精煉／製作 ←──────┘
                           ↓
                     材料與貨幣消耗
```

所有數值用資料表，標示 `source_region/source_date/verified`；未知機率保持 unknown，原型使用的試調值另存，別讓玩家 Wiki 舊機率變成正式設計。成功率、保險、失敗退階／消失、材料扣除時機與交易鎖要一起寫成規則。估算長期成本時使用狀態轉移或 Monte Carlo，包括失敗退階；簡單 `cost / success_rate` 不足以處理精煉梯子。

韓版官方另有寵物代養系統的搜尋內容，與早期逐次餵食體驗有差異；本機也有寵物分解相關表名。這說明版本功能需要分層，而不是只拿早期寵物規則代表整個現行系統。[韓版官方寵物代養頁](https://www.sealonline.co.kr/Guide/Info?seq=596)（本次 direct open 只回導覽，具體內容由搜尋索引取得，未確認美版對應）。

## 6. 特效、UI 與音訊

### 6.1 特效配方（L/P）

| 效果 | Godot 製作配方 | 注意事項 |
|---|---|---|
| 選取圈／地面點擊標記 | 貼地薄 mesh＋透明貼圖＋旋轉／scale 動畫 | 不必依賴 Decal；處理地形坡度與 z-fighting |
| 普攻命中 | 短 flipbook 火花＋少量碎片＋同步聲音＋跳字 | 強度分普通／暴擊；避免每擊都大震屏 |
| 揮刀軌跡 | 預製弧形 mesh 或自建 ribbon 取樣武器尖端 | Compatibility 不支援內建 particle trails，需替代 |
| 魔法／範圍技 | 地面圈、升起 mesh、flipbook、粒子分層 | 對單位與地點座標分清，命中後清除 |
| 武器精煉光／光環 | 附掛 mesh＋加色材質＋少量粒子 | Emission 不等於 bloom，別靠全畫面過曝 |
| 升級 | 光柱／環形 mesh、粒子、文字與音階 | 使用獨立可重用 LevelUp scene |
| 死亡／傳送／消融 | noise threshold、邊緣增亮、Tween 進度 | 消融方向與結束端點需驗證；不假定原作 phase 用途 |
| 角色被樹擋住 | 遮擋淡化，或限定玩家的剪影 pass | 不把所有東西強制 no-depth-test |
| 頭上名字／公會／傷害 | Label3D 或世界座標投影到 CanvasLayer | 固定字級、距離裁切、螢幕邊界與重疊處理 |

內建 3D 粒子 trails 僅支援 Forward+／Mobile，原型的 Compatibility 需用預製或自建幾何。[Godot 粒子 trails](https://docs.godotengine.org/en/stable/tutorials/3d/particles/trails.html) 桌面與 Web 必須各檢查一次透明排序、材質編譯與畫面效果；不能只因 Godot editor 可看就判定 Web 完成。

### 6.2 UI：功能層與美術層都要還原（R/P）

舊研究的原作截圖記錄包含狀態欄、小地圖、快捷列、聊天、功能列與寵物欄；本次尚未量測其像素布局。應先以實際選定解析度截圖量測，再做 `CanvasLayer/HUD.tscn`。建議拆成 PlayerStatus、TargetFrame、Hotbar、ChatPanel、MiniMap、PetPanel、InventoryWindow、EquipmentWindow、SkillWindow、DialogWindow、TradeWindow 等可編輯 scene，重複欄位做 `item_slot.tscn`。

版面使用 anchors、offsets、Containers；Theme 存字型／色彩／間距，StyleBoxTexture 或 NinePatchRect 保留圖框細節。資料由 signal 更新，拖曳只發出物品操作命令。窗口需支援焦點、遮擋排序、移動／收合與輸入阻擋；底層遊戲不要在按背包按鈕時也收到移動點擊。

手機版小地圖固定北向，不綁定旋轉手勢。小地圖先採預烘焙地圖＋圖示投影：地圖 Resource 記錄世界 XZ 範圍與貼圖範圍，將座標正規化後映射；玩家朝向獨立旋轉。所有圖示與點擊目標使用相同座標轉換。另有樓層／遮罩時再增加資料，不必一開始就多開一個實時相機。

字型需檢查繁中、英文、數字與符號字形；原作字型只作辨識參考。先完成 1280×720 和一個寬螢幕解析度的布局與文字可讀性；本次不把任何未量測的 UI 色碼當成原作標準。

### 6.3 音樂、打擊聲與環境聲（L/P）

本機 MP3/WAV 數量說明其音訊內容規模；本次只解析標頭，**未試聽，不能評斷曲風、樂器、旋律與各區配曲**。實作先建立 Master → Music / SFX / UI / Ambience / Voice bus。區域 BGM 用雙播放器交叉淡入淡出，環境音與怪物／腳步使用 AudioStreamPlayer3D，按重要性限制同時發聲數；UI 用非空間聲。

武器接觸、怪物受擊、暴擊、技能施放／失敗、升級、撿物與開窗應各有語意事件。不同材質／武器可配置音色，少量音量與音高變化避免機械重複。以手機喇叭與耳機實測背景音樂是否蓋住命中、技能就緒與重要提示；玩家靜音時仍需看懂戰鬥狀態。kit 的 `music.gd`／`sfx_bank.gd` 可用作單機音訊調度起點，目標平台音高與播放模式仍要驗證。

## 7. Godot 專案與資料架構（P）

主要畫面與物件必須存成可編輯 `.tscn`，編輯器中能看到代表性角色與道具，不能空根節點執行後才用 `.new()` 建整個遊戲。

```text
Game.tscn
├─ WorldRoot
│  ├─ Zone.tscn（地形、導航、道具、入口、出生點）
│  ├─ Player.tscn
│  │  ├─ CharacterBody3D／CollisionShape3D
│  │  ├─ NavigationAgent3D
│  │  └─ Visual.tscn（Skeleton、mesh、AnimationTree、配件）
│  ├─ Monsters（重複實例）
│  └─ Drops／Effects（重複實例）
├─ CameraRig.tscn
├─ AudioRoot.tscn
└─ CanvasLayer
   └─ HUD.tscn（各窗口與 item scenes）
```

上圖是組織示意：實際 `Player.tscn` 根可直接使用 CharacterBody3D，避免多套不必要的移動根。地形、背景 UI、靜態文字、Theme／StyleBox 與間距留 scene／resource；腳本管行為與動態資料。新建大 scene 用 Godot pack/save，驗證 owner、instance 關係與重載節點數；正常啟動不得自動重建來源 scene。

靜態內容使用明確 ID 的 Resource／匯入表：Item、Skill、Job、Monster、Loot、Pet、Quest、Zone、RefineRule。執行狀態用獨立資料：CharacterState、InventoryState、QuestProgress、PetState；不直接修改共用 Definition。生成存檔／封包時只輸出允許欄位，資料版本化並提供 migration。

內容驗證工具檢查重複 ID、無效技能／怪物／圖示引用、掉表權重、裝備骨架相容性、動畫命中事件、任務不可達與缺字。這些編輯工具能減少大量內容製作後的人工排查。

## 8. 多人連線與 MMO 的必要架構（P）

原作的服務拓樸與協定未調查，以下是 Godot 新作的設計建議。

```text
Godot client
  ├─ 本地輸入／鏡頭／UI／即時演出
  └─ 移動、技能、交易等命令
                    ↓
登入與角色服務 → 地圖／副本權威伺服器 → 持久化資料庫
                    │                    ↑
                    ├─ 可見範圍 AOI       │
                    └─ 聊天／隊伍／公會／經濟服務
```

先做一個 Godot headless 權威 map server 與兩個客戶端，測移動、打怪與撿物；規模增加後再依實際需求拆服務。原生版可用 ENet；Web 可用 WebSocket 或 WebRTC 對應架構，不能在瀏覽器直接用原生 UDP。Godot 的高階 multiplayer 是同步與 RPC 工具，不會自動提供 MMO 的帳號、資料庫、分流與經濟一致性。[Godot 網路文件](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)

核心規則：

- 客戶端只請求行動；伺服器驗證位置、速度、冷卻、AP、目標、距離、掉寶、精煉與交易。
- 移動可從 server snapshot 插值開始，必要時加本地預測與校正。命令帶 session／sequence ID，過時與重送的結算不得重複生效。
- 只同步 AOI 內玩家、怪物、掉落與事件；戰鬥結果可靠傳送，頻繁位置更新選適當通道；大型清單分頁／快照。
- 稀有道具具有 instance UUID；跨角色交易與貨幣轉移在資料庫 transaction 中完成，鎖與確認都由服務端持有。
- 存檔不只依賴離線事件：關鍵交易立即 durable commit，普通狀態定期快照；斷線、重連與跨圖要能恢復。
- 同一主機可先共用登入／地圖／資料服務；這是職責邊界，不代表一開始要部署大量微服務。

暫定可用 server tick 10～20 Hz、client render 60 FPS 作測量起點，但這不是原作數據，也不是吞吐保證。可承載人數必須在指定硬體、AI／AOI／技能負載與網路條件下實測。

## 9. 效能、平台與驗收

渲染器以目標平台選：目前原型保留 Compatibility 可支援 Web；桌面高階效果可另評估 Forward+，同時維持明確降級方案。[Godot renderer 差異](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

| 成本來源 | 先量什麼 | 對策 |
|---|---|---|
| 很多換裝角色 | draw calls、skinning、動畫 CPU | 減少每套材質數；距離 LOD／動畫更新降頻；遠處省略配件 |
| 大量透明 VFX | fill rate、overdraw、排序 | 限粒子面積與同屏數；遠處換簡版；草優先 alpha scissor |
| 大地圖 | 匯入／載入時間、RAM／VRAM | 分區載入、分區 MultiMesh、遠景簡化、貼圖壓縮與 mipmaps |
| 怪物 AI／尋路 | physics frame、查路尖峰 | 分批更新、事件觸發重查、遠處休眠 |
| 聊天／名牌／跳字 | Control 數量、字型 atlas、配置次數 | 距離裁切、池化短命元件、文字增量更新 |
| 伺服器 | tick P95/P99、流量、資料庫延遲 | AOI、佇列界限、批次持久化與關鍵交易分流 |

驗收至少包含：

1. **視覺對照**：同樣解析度、鏡頭與角色佔屏比例，對照原作的正背側、白天／夜晚、城鎮／野外；以輪廓、色彩、描邊、動作接觸點評估，不先喊相似度百分比。
2. **戰鬥錄影**：固定 FPS 擷取觸控選怪、追打、自動普攻、技能、中斷追擊與切換目標；統計出手→接觸→傷害→聲音的時間差。驗證不需要連招或旋轉鏡頭也能完成戰鬥。
3. **完整循環**：接任務→出城→擊殺→撿物→升級→餵寵物→回城交易／精煉→保存→重開。
4. **編輯器驗收**：直接修改一段靜態文字與一個 Container 間距，重跑後仍保留；生命值／移動不回寫來源 scene。
5. **連線驗收**：兩客戶端、模擬延遲／掉包／斷線，測雙重拾取、交易改價、重送精煉與跨圖。
6. **壓力場景**：先用 20 玩家＋50 怪物＋重複道具作測量場景，再依需求加量；這是測試規模建議，不是已驗證效能。記錄硬體、解析度、renderer、平均與 P95 frame time。

## 10. 現有專案可用程度與缺口（R）

| 項目 | 本次查看後的狀態 | 下一步 |
|---|---|---|
| `seal-meadow/scenes/*.tscn` | 已有主場景、草原、玩家、怪物、Actor、HUD | 保留可編輯骨架，建立參考對照 scene |
| 移動／追打／升級 | 單機 Node3D 邏輯，使用自訂地形高度與簡化避障；不是完整權威多人系統 | 增加穩定導航、不可達處理與命令層 |
| 相機 | 目前程式仍有右鍵 yaw、滾輪縮放；export 預設 -42°／distance 14 | 改為固定方向／俯角與跟隨，補固定視角遮擋處理；手機不依賴旋轉／縮放手勢 |
| 角色 | Blender 渲染身體／頭髮／劍的 8 方向分層測試；README 與舊預覽時間不同 | 先以現有 2.5D 管線驗證手機；依換裝成本與記憶體實測決定長期方案 |
| `combo_input.gd` | kit 有純邏輯；`seal-meadow/scripts` 未見接入 | 作共用模組與研究參考保留，本手機遊戲不接入 |
| `pet_care.gd` | kit 有純邏輯，尚未證明目標遊戲已整合 | 設定版本規則、UI、外觀與存檔 |
| `refine_ladder.gd` | kit 有純邏輯，含試調值 | 先完成物品 instance／背包，再接交易結算 |
| `talent_tiers.gd` | 三系 tier 型技能點模組 | 可借配點基礎；不等同原作職業技能樹 |
| `loot_ledger.gd` | 收藏／解鎖型掉落工具 | 不等同 MMO 地上物、拾取優先權與交易背包 |
| `music/sfx_bank/atomic_file/scene_loader` | kit 已有共用能力 | 新功能實作時先評估，僅同步指定專案 |
| MMO／任務／背包／社交 | 本次查看的原型尚無完整系統證據 | 需另外設計與實作，不能以模組存在宣稱完成 |

本次只作研究與唯讀程式檢視，**沒有執行既有 Godot 測試、重新產生 scene、改動遊戲、匯出或部署**。舊研究提及的 47 項檢查不是本次新跑的證據。

## 11. 建議製作順序與交付範圍（P）

```text
手機構圖／觸控與原作美術參考量測
           ↓
固定鏡頭＋觸控＋一套角色＋一塊草原＋一隻怪
           ↓
點怪追打／自動普攻＋少量技能＋完整聲畫回饋
           ↓
一個城鎮＋任務＋背包＋掉落＋換裝
           ↓
寵物餵食／一次進化＋精煉＋存讀檔
           ↓
雙客戶端權威伺服器＋交易／重連驗證
           ↓
職業、更多地區、副本、公會、活動與持續營運
```

第一個可驗收切片建議限制：1 職業、1 套素體、2 把武器、1 套換裝、3 種怪、1 草原、1 小城鎮、3 個任務、1 寵物成長分支、1 套精煉規則。這些數量是用來驗證管線的提案，不是使用者已批准的開發任務。

先在手機固定視角驗證角色比例、材質、可讀性、輸入與持續執行的效能：若小場景已出現模糊、誤觸或熱降頻，先處理再量產地圖、裝備與職業。尚未有團隊人數、素材來源與營運規模，故不提供不可靠的工期／預算總額。

## 12. 還需要的原作量測

| 待量項 | 建議採樣 | 影響 |
|---|---|---|
| 相機／比例 | 固定視角、角色各移動方向、不同手機長寬比 | 頭身比例、視野、安全區與遮擋；不需要旋轉鏡頭量測 |
| 普攻／技能 | 出手、命中、冷卻、移動中斷與切換目標 | 觸控回饋、攻擊節奏與動畫同步；不量測連招時間窗 |
| 換裝 | 一把劍／一件衣／一頂帽逐件換 | 骨架分件、遮擋、材質與發光規則 |
| 寵物 | 飢餓一段時間、餵不同物品、進城／卸裝 | 時鐘、經驗、暫停與離線規則 |
| 精煉 | 介面文字、材料、保護道具說明、版本來源 | 不足以從少量結果估真實機率；需官方機率表 |
| UI | 固定解析度全畫面與各窗口 | 色彩、框線、字級、拖拉、焦點與縮放 |
| 音訊 | 授權／可用條件下試聽區域與事件 | 曲風、循環、空間感、打擊層次 |
| 網路 | 經授權的雙客戶端延遲／重連觀察 | 僅能觀察行為，不能直接得知伺服器內部拓樸 |

本機資料足以拆解製作面向與部分渲染原理；要主張逐幀、逐數值一致，必須補這些量測。製作自有版本時用原創或已授權素材；本報告的封裝清單是研究證據，不是素材移植／解密成果。

## 13. 主要來源與檢視檔案

公開來源皆於 2026-10-26 查核；官方 guide 可能保留舊資料，索引／搜尋內容與當前伺服器規則應分開。

- [韓版官方介紹](https://www.sealonline.co.kr/Guide)：Full 3D 卡通、連招、寵物、聲望、情侶與故事。
- [美版官方操作](https://sealonline.playrohan.com/background_new/basic_controls.html)：點擊、轉鏡頭、縮放與快捷操作。
- [美版官方生存指南](https://sealonline.playrohan.com/background_new/survival_guide.html)：睡覺、HP/AP、普攻／連招、掉落、升級與任務。
- [韓版指南索引／共通技能](https://www.sealonline.co.kr/Guide/Info?seq=20)：功能範圍；部分本文僅在搜尋索引返回。
- [韓版寵物代養](https://www.sealonline.co.kr/Guide/Info?seq=596)：版本差異參考；direct open 未回正文。
- [官方早期情侶與公會更新](https://www.sealonline.co.kr/Board/View/update/2640)：雙人休息與社交功能的歷史證據，不能當當前完整規則。
- [Godot 材質](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html)、[動畫樹](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)、[骨骼附掛](https://docs.godotengine.org/en/stable/classes/class_boneattachment3d.html)。
- [Godot 導航](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html)、[粒子 trails](https://docs.godotengine.org/en/stable/tutorials/3d/particles/trails.html)、[MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)。
- [Godot renderer](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)、[multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)。Godot stable 是會移動的文件連結，本專案版本仍以 4.7 為準。
- 本機：`SealOnline` 的 SPAK 目錄、三個 `.fx`、WAV 標頭、版本檔；詳 [JSON](client-inventory.json) 與 [盤點腳本](inventory_client.py)。
- 專案：`prototypes/seal-meadow/README.md`、`project.godot`、`preview.png`、`scripts/{player,monster,main,camera_rig,actor,hud}.gd`；`prototypes/godot-kit/README.md`、`addons/proto_kit/combo_input.gd`、`tests/test_mmo_modules.gd`。
