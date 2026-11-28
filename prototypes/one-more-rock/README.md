# 石頭裡有什麼？ · V0.2 採石與搬運

[目前進度、下一步與驗證](PROGRESS.md)

主場景在同一張碎石平原串起採集、推車、卸貨與破石。出生後沿小徑往前約 10 公尺即可抵達可挖的山壁。地面上的原石從採掘或坍落產生。每一擊由右肩抬鎬，經過落鎬、短停與收回；命中時鎬頭卡進岩面一瞬，鏡頭跟著震一下，鎬尖立刻噴出短火花，岩面崩開時再飛出碎石與粉塵，依序播放揮鎬、撞擊、土石崩落與出礦聲，揮空時只有風切，準星脈動，手機會短震。按住連挖時等前一擊收回才揮下一擊，預設每 0.56 秒揮一次。每擊移除接觸點附近的岩材，改變岩面和碰撞；上層失去支撐時會先冒出粉塵、微微傾斜，再受重力落下碎裂。方向箭頭會隨流程指向採石場、卸貨區或破石台。碎岩先受重力掉落，走近收取時才往上浮，再落進背包或推車。回工坊踏進木屋旁卸貨料斗周圍的標線內，原石會從手邊或車斗飛入料斗，碰撞、滾動後自然堆起，並有音效及入庫數量提示，接著走進敞開的木屋門口，就會切到室內破石台。背包初始 5 顆，推車容量為 20 顆，料斗初始 30 顆。到「工坊升級」站可自行選擇破石、採掘、搬運或自動化路線。接上推車後原石會自動裝車，卸貨先清背包、再卸推車，容不下的石頭留在原容器。

| 動作 | 桌機 | 手機橫向 |
|---|---|---|
| 移動、轉向 | WASD；左鍵鎖住滑鼠後移動滑鼠，Esc 解除 | 左下拖曳移動，右側拖曳看向 |
| 跑步、跳躍 | 按住 Shift 跑步，按空白鍵跳躍 | 左下「跑步／走路」切換，右下「跳躍」 |
| 收取原石、卸貨 | 走近挖下來的普通礦塊，或踏入綠色卸貨區 | 同桌機 |
| 手動互動 | 看向近物後按 E | 準星對準近物後按右下情境鍵 |
| 採掘、推車 | 左鍵揮鎬，可按住連續敲擊。對準推車按 E 接車，準星移到空地按 E 停車 | 右下情境鍵可揮鎬、接車、停車 |
| 進屋、敲石、離台 | 走入木屋切到破石台。左鍵連點或按住掃過原石，Esc 回到門口 | 走入木屋切到破石台。連點或按住掃入原石，點「離開工作台」回到門口 |

可挖掘的岩山由 36 個岩體構成。準星變成金色圓環代表岩面在敲擊距離內。岩山保留作者製作的原始表面。採掘以鎬尖落點為中心，向四周挖出近方形、邊緣不規則的淺凹口。原岩面沿移除單元裁切，動態生成的 Voronoi 破面與碰撞一起更新。逐次改變落點高度可留下階梯狀的岩層。每個區塊仍以 6×6×6 個單元管理，已生成的切面會快取，支撐檢查從挖掉的單元往外找。鬆動預警約 0.48 秒，坍落剛體上限是手機 4 塊、桌機 8 塊。從露頭礦片採下的含礦原石需手動拾取。礦塊飛行時先保留容量，落下時才更新背包或推車計數。工作台逐顆取用倉庫原石，原石依編號與硬度使用三種輪廓，稀有結果仍在敲開後揭曉。敲擊時顯示本次品相加成和累積倍率。普通敲擊（含長按連敲）每擊 +0.05。金色時窗內的完美敲擊 +0.15，至少兩次完美再獲得 ×1.25。其餘命中有 12% 機會敲出亮面，共 +0.17。揭曉時才浮出「基價 × 倍率 = 實得」，收走時入帳實得金額。敲開後礦物留在檯面，再點一下可立即收料，持續按住會在揭曉後等 0.55 秒再收料，接著入帳並從左側補下一顆。入帳有專屬音效，錢包會滾動加總。首次發現顯示「已收錄圖鑑」和礦物縮圖，首次開石等里程碑會另跳出成就通知。首次收走一種礦物時，工坊左側的圖鑑架會增加對應的 3D 樣本和名字。看向展示架後按互動鍵可查看收錄數。圖鑑與成就目前記錄於本次遊玩。離台回到屋外，保留玩家朝向、台上原石耐久與待收礦物。V0.1 的無限原石樣品台可單獨執行。販售選擇與存檔在後續里程碑。[實作方案與驗收條件](../../docs/incremental/One-more-rock/IMPLEMENTATION.md)

電鑽用按住操作，鑽頭旋轉、接觸岩面時每約 0.21 秒切一次。右鍵或手機「礦震」對準岩面後可發動一次大範圍採掘，十字鎬先蓄力，電鑽短暫過載，冷卻 8 秒。

普通揮鎬與電鑽每次成功採掘掉 1 顆原石，礦震掉 2 顆。出礦天賦可額外增加 1 或 2 顆，岩層坍落時同時碎裂的岩塊共用短間隔，每批最多掉 2 顆。挖口也會剪掉受擊區域內懸空的原始外皮，裁切後的極薄殘片會從畫面和原始岩壁碰撞一起移除。

連續開挖後，凹口內有機會露出金黃色方解石或紫色水晶。可從原開挖位置看到的內岩面才會出現礦片。初次從第 3 擊起檢查，以後間隔 8 次成功開挖。直接對準礦片敲 2 下就能採下，鋼鎬和礦震可一擊採下。每次敲中礦片會疊播鎬頭撞擊與水晶聲，敲鬆時有火花，敲下後晶簇以可拾取剛體掉落。拾取時保留原本的晶簇外觀和礦種，送到工坊可用對應等級的槌子加工。撞擊、水晶與崩落聲每次播放都有小幅隨機音高。

## 執行與匯出

以下從本目錄執行。Web 預設使用單執行緒的 Compatibility 模板；匯出需要本機安裝與 Godot 版本相符的 Web release 模板。

```sh
godot --headless --editor --import
godot --path .
# 單獨試玩 V0.1 無限樣品台
godot --path . res://scenes/workbench.tscn
mkdir -p build/web
touch build/.gdignore
godot --headless --export-release Web build/web/index.html
python3 -m http.server 8937 --bind 127.0.0.1 --directory build/web
```

桌機瀏覽器開啟 http://localhost:8937 。Android 實機可用 USB 執行 `adb reverse tcp:8937 tcp:8937` 後開啟相同網址；iOS 可從 HTTPS 靜態主機載入整個 build/web 目錄。

## 編輯入口

| 場景 | 在編輯器能調什麼 |
|---|---|
| scenes/quarry.tscn、scenes/quarry_landscape.tscn | WorkshopEntry 進屋範圍、WorkshopExit 出屋落點、WorkshopInterior 照明和木牆、山體與 PolyforkProps 場景模型 |
| scenes/player.tscn | Eyes 的高度與視野、Pickaxe 十字鎬和握把手套、ElbowAnchor 前臂起點、PackSocket 落點，以及走跑速度和跳躍 |
| player.gd `swing_pickaxe`／`kick` | 抬鎬、揮擊、卡鎬、收回的秒數、揮鎬弧寬與鏡頭震幅；連挖間隔是 quarry.gd 的 `mine_interval` |
| scenes/quarry.tscn 的 MiningChips、MiningDust | 命中石屑與粉塵的數量、速度、大小與顏色 |
| scenes/specimen_shelf.tscn | 圖鑑櫃、四個樣本位置、文字與收錄計數 |
| scenes/cart.tscn、scenes/unload_zone.tscn、scenes/upgrade_station.tscn | Ore Barrow、木箱鐵件與卸貨標記、升級砧台與牌匾 |
| scenes/stock_pile.tscn、scenes/pile_rock.tscn | 料斗壁、近層剛體、MultiMesh 中層、遠層石堆與剛體預算 |
| scenes/excavated_ore.tscn、scenes/falling_rock.tscn | 物理碎岩的重力和碰撞，坍落預警與剛體上限在 excavation.gd |
| tools/bake_voronoi.py、voronoi_cells.gd | 編輯期切出岩體的共用 Voronoi 單元。確定種子後只需重新烘焙一次 |
| scenes/workbench.tscn | Camera、raw_shells 和 raw_hulls 原石外形與碰撞、Daylight 天空資源、Hammer/StrikeFace 的實際槌面、ImpactEmitters 石屑、ProductTray 收料盤落點、StoneEntry 補料起點、Finds 和 IconViewport 的模型、HUD/Estimate 和右上通知、CashSound 入帳音效 |
| scenes/stone.tscn | Shell 的外形，HitShape 的凸包，Crack1–3 的裂紋路徑；工作台引用這個子場景 |
| workbench.gd | 命中、品相倍率、收料與入帳流程。常數 PERFECT_FROM／PERFECT_TO（完美時窗）、STEADY_BONUS、PERFECT_BONUS、LUCKY_BONUS、FLAWLESS_BONUS；Inspector 可調 min_hit_interval 和 rubble_glow_chance |
| scenes/workbench.tscn 的 TimingRing | 時機光環的粗細與大小（縮到 scale 1 時應貼合石頭外緣） |

場景已用 Godot Kit 的 scene_builder 製作並經 pack/reload 核對節點與子場景引用；合成的敲擊和揭露音效已烘入場景。進入破石台時切到固定相機。中文字型取自同庫 pixel-aquarium 的 Noto Sans TC，授權隨附於 assets/OFL.txt。

地上碎岩、拾取飛行、推車載貨與料斗都共用暖灰褐色的原石外觀。近層碰撞使用同一個預烘凸包，中層繼續用 MultiMesh。紫水晶在破石台揭露、圖鑑通知縮圖和圖鑑櫃都使用同一個三柱晶簇。模型可在相關場景的 MeshInstance3D 調整比例與位置。 [模型來源及修改](assets/minerals/ATTRIBUTION.md)

礦工木屋、礦井井架、礦燈與貨箱是採石場場景的 GLB 實例，手推車外觀也由 GLB 提供。推車的礦石和拾取落點仍由遊戲的裝載量驅動。 [採石場素材來源](assets/polyfork/ATTRIBUTION.md)

## 音效配方

目前音效在 `assets/sfx`。揮鎬保留風切聲，普通岩壁用 `mine_hit.wav`，碎裂與坍落分別用 `stone_crash.wav` 的短版和完整版。電鑽持續播放 `drill_whizz.wav` 的循環剪輯，走跑時依地面移動距離播放 `foley_footstep_gravel_2.wav`。工作台槌擊用 `axe_hit.mp3` 的短剪輯，手動收料觸發 `coins_gather_small.wav`。直接敲擊露出的方解石或紫水晶時，疊播 `impactMining_001.ogg` 和 `crystal_hit.wav` 的剪輯，普通岩壁和工坊各用自己的音色。

要製作其他變體，可從 Bfxr 各分頁的預設開始。下表的長度是遊戲內的試聽目標。 [Bfxr](https://www.bfxr.net/) · [材質與旋律範例](https://github.com/increpare/bfxr2/blob/master/examples/SoundCabinet/README.md) · [碎裂範例](https://github.com/increpare/bfxr2/blob/master/examples/Exotic/README.md#fractr)

| 遊戲事件 | 起始預設與調法 | 建議匯出 |
|---|---|---|
| 十字鎬命中 | **Clonkr → Ceramic Crack**。Size 稍大，Strike Hardness 稍高，Hollowness 壓低，Damping 拉高、Duration 拉短。保留開頭清楚的「喀」，讓尾巴約 0.15–0.25 秒收乾淨。 | `mine_hit.wav` |
| 原石收入背包 | **Clonkr → Wood Knock**。Size 略小，Strike Hardness 降一點，縮短 Duration，取輕短的「嗒」，約 0.1–0.2 秒。 | `ore_pickup.wav` |
| 岩層坍落 | **Fractr → Stone Collapse**。先取低沉的主落地聲，再把碎塊連續落地的尾段收短到約 0.8–1.3 秒。 | `rock_collapse.wav` |
| 金幣入帳 | **Bfxr → Pickup/Coin**。用 Sine 或 Triangle，Attack Time 接近零，Decay Time 縮短，Frequency Slide 略往右。試聽目標是約 0.12–0.25 秒的短促上揚音。 | `cash_in.wav` |

選中音效後按空白鍵試聽，`Ctrl+E` 匯出 WAV，`Ctrl+S` 留一份 `.bfxr` 方便再調。把 WAV 放在專案素材目錄後，在 Godot Inspector 設到對應播放器的 Stream。F1 的 **Sound Test** 可試聽命中、碎裂、水晶、槌擊、腳步、拾取、卸貨與入帳，再用 **Audio** 比較音量。坍落音量和距離由採石場的 `CollapseSound` 調整。 [Bfxr 快捷鍵](https://www.bfxr.net/) · [採石場音效節點](scenes/quarry.tscn) · [工作台音效節點](scenes/workbench.tscn)

## 工坊天賦樹

看向「工坊升級」站按 E，手機使用右下情境鍵。左側切換八條路線，右側顯示該路線的天賦樹。先選天賦節點查看花費、前置條件和效果，再按下方按鈕解鎖或換裝。節點之間的連線對應前置條件，加高車斗需要先解鎖加大背包，料斗可獨立解鎖。

| 路線 | 選項 |
|---|---|
| 破石工具 | 初始槌處理硬度 1。鍛鋼槌解鎖硬度 2，鑽尖槌解鎖硬度 3。三階原石耐久分別為 5、7、9。修面與精修工具同時增加起始品相及每擊加成。 |
| 採掘工具 | 鋼製十字鎬每擊挖得更深。電鑽適合按住近距離持續鑽掘，可在工坊免費切換兩種工具。 |
| 搬運 | 背包 5 → 10、料斗 30 → 60。加高車斗可把推車從 20 顆增至 30 顆。 |
| 出礦 | 沿紋劈鑿與整面剝採讓每次成功採掘依序多出 1、2 顆原石。 |
| 拾取 | 普通原石的自動拾取半徑由 2.1 擴至 3 公尺，快速入袋縮短入袋和裝車時間。 |
| 體能 | 輕步靴提高跑速，彈簧靴讓玩家跳得更高。 |
| 自動化 | 固定式破石機以壓頭壓碎料槽裡的原石。拾運機器人（55 幣）會撿地上已落穩的普通原石送進料斗。接著可買自動破石機（50 幣），鍛鋼與鑽尖升級（80、125 幣）依序提高到硬度 2 和 3。拾運與破石可各自暫停接單。 |

破石台會從料斗取出第一顆目前槌子能加工的原石，較硬的原石留在料斗。全都超出目前槌子強度時，提示需升級的硬度。已知含方解石的原石需要鍛鋼槌，已知含紫水晶的原石需要鑽尖槌。

Kenney Adventure 介面的路線與節點位置在 [workshop_menu.tscn](scenes/workshop_menu.tscn)，共用節點樣式在 [workshop_upgrade_row.tscn](scenes/workshop_upgrade_row.tscn)。價格、效果和前置條件在 [workshop_upgrades.gd](workshop_upgrades.gd)。本原型的升級與金幣存在本次遊玩。

## 開發面板

從 Godot 編輯器執行採石場時按 F1。面板暫停遊戲，調整後按 F1、Esc 或「關閉」回到原本的控制模式。晃動與粉塵可單獨開關或調整，便於比較不同的揮鎬設定。

- **Terrain** 調連挖間隔、揮鎬四段時序、弧寬、可達距離、鎬等級、剛體預算、粒子與手震。
- **Hero、Camera、Rewards** 調走跑跳、視野、瞄準靈敏度、收取和卸貨範圍、工作台連敲間隔，也可以加測試金幣。
- **Stress Tests、Debug View** 在玩家前方生成 30 或 100 顆原石，並檢查地上原石數、正在坍落的岩塊、繪製呼叫和活躍剛體。
- **Audio、Sound Test** 即時調主音量和各動作音量，試聽採掘、拾取、卸貨和入帳。

採石場的接線集中在 [quarry_dev_panel.gd](quarry_dev_panel.gd)。目前 Web 匯出預設排除了開發面板。專用開發匯出可另外複製一個預設，移除這兩個排除項目，設定 `developer` 並以 debug 匯出。共用介面見 [Godot Dev Panel](../godot-dev-panel/README.md)。

## 驗證

- 露頭礦片 L2 用 `godot --headless --script tests/mineral_loop.gd` 驗證挖口露出、準星瞄準、專屬命中聲、採收與加工。
- 開發面板與揮鎬 L2：`godot --headless --script tests/dev_tools_and_mining.gd`。驗證 F1 暫停與恢復、展開與套用欄位、揮擊途中轉離岩壁、從空中轉進岩壁，以及命中畫格的鎬尖座標。
- V0.2 L2：`godot --headless --script tests/quarry_loop.gd`。驗證第一人稱走跑跳、左鍵揮鎬、實體碎岩拾取、回程指引、圖鑑架、拾取先浮後落、稀有石手動拾取、雙指歸屬、失焦取消、接車、到點自動卸貨與音效、滿倉剩量、開石、離台、升級、清空演出和 300 顆的三層表現。自動化驗證滿倉、在途保留位、稀有石手動拾取、分級加工與入帳。
- 岩體 L2：`godot --headless --script tests/excavation_loop.gd`。確認凹洞改變實際射線命中深度，以及底層失去支撐時上方岩塊成為剛體、落地後碎裂。
- 破石台 L2：`godot --headless --script tests/bench_loop.gd`。檢查槌面命中、石屑、敲擊不透露金額、普通加分、亮面與完美無瑕、按一下才移礦補料、單次入帳、金幣滾動與首次收錄通知。
- 場景修改後：`godot --headless --editor --import`。可修改 HUD/Place 的靜態字串，按 F5 應顯示新字串；停止後執行時開石數不寫回場景。
- V0.2 手機試玩：用背包與推車各運 20 顆，比較往返、第一次轉向找不到工坊的位置、採掘誤觸與卸貨回饋。V0.1 另記自願開石數和看不清的提示，待實機試玩。

目前 V0.2 的料斗容量為 30–60 顆。測試用 300 顆驗證 60 個手機剛體上限、64 個中層實例與剩餘量的遠層代理；桌機上限暫用 200。後續 M4 會把這套表現接上自動化吞吐與車、斗等處理單位。

採石場場景的 MiningSparks、MiningChips、MiningDust 可調火花、碎石及粉塵。MineSound、RockBreakSound、MineralImpactSound、CrystalOreSound、CollapseSound 可調各種撞擊與崩落音，F1 的 Sound Test 可試聽採掘與水晶音效。

採石場天空使用 Kenney Skyboxes 日景的 2048×1024 WebP。來源約 21 KB，Godot 有損匯入後打包約 23 KB。[Kenney CC0 授權](assets/sky/LICENSE.txt)

工坊天賦樹使用 [Kenney UI Pack – Adventure 1.0](https://kenney.nl/assets/ui-pack-adventure)，升級站砧台來自 Kenney Survival Kit。兩組 CC0 授權隨素材保存。

工具回歸使用 `godot --headless --script tests/mining_tools_loop.gd` 驗證蓄力、冷卻、電鑽長按及鬆開。局部碎裂在開發機 headless 抽樣的切削 CPU 時間，56 次普通揮鎬 p95 為 8.34 ms，49 次礦震 p95 為 20.03 ms。這組量測只涵蓋切削處理。
