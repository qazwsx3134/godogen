# 行人反擊：十分鐘割草

可玩的 Godot 4.7 原型，支援手機瀏覽器直式與桌面試玩。美術方向是像素風台灣夜市（見 [art-direction.md](docs/art-direction.md)），開局二選一：男主角（厭世西裝，拳頭起手）或女主角（冷酷外套，衝擊波起手）。機制參考 Vampire Survivors：單指浮動搖桿移動，武器各自冷卻、自動攻擊；揍飛的敵人掉經驗寶石，升級時三選一，取得台灣街頭味的武器與被動。武器升滿後搭配對應被動可以進化。撐過 10 分鐘就勝利，血量歸零就倒下；每局的金幣帶回「街頭補給站」買永久強化，達成目標會解鎖新武器。

完整規格與已確認的決策見 [horde-spec.md](docs/horde-spec.md)；開發清單見 [TODO.md](TODO.md) 與 [ROADMAP.md](ROADMAP.md)。

## 內容

- **主角**：男（厭世西裝；血量 ×1.1、移速 ×0.95、拳頭起手、大幅揮擊）與女（冷酷外套；血量 ×0.9、移速 ×1.08、衝擊波起手、乾脆出掌）。選擇記在存檔；命令列 `--hero=man|woman` 可指定。
- **武器**：拳頭（男主角起始）、衝擊波（女主角起始）、回旋踢、藍白拖、珍珠奶茶、鞭炮、三炷香、天燈（解鎖）、愛的小手（解鎖）。
- **新機制武器**：臭豆腐攤（放置區域，減速）、雨傘（擋傷並彈開）、套圈圈（拉扯）、路過的機車騎士（召喚夥伴）。
- **隱藏融合**：兩把指定武器 Lv.4 時冒出「？？？」卡，選了才揭曉：雙人合擊、爆漿臭豆腐、媽媽的反手、珍珠圈、鹽水蜂炮車隊；配方見 [horde-spec.md](docs/horde-spec.md)。
- **進化**：鐵沙掌、媽媽的追蹤拖鞋、珍珠暴雨、鹽水蜂炮、媽祖遶境、平溪天燈祭、雞毛撢子。
- **被動**：沙茶醬、雞排、提神飲料、集點卡、平安符、大聲公、腳底按摩、紅包（解鎖）。武器與被動各 6 格。
- **敵人**：抽菸者（黑煙團紅眼，留下煙霧）、機車（預警後衝刺）、汽車（慢、重、血厚）、臭臭胖子（臭味光環讓主角減速；被揍飛時爆屁，炸飛周圍敵人，可以連鎖）。4:00、6:00、8:00、9:00 會出現精英，打倒後掉寶箱，可以多選 1、3 或 5 次。
- **掉落**：經驗寶石（超過上限就合併成大寶石）、金幣、滷肉飯（回血）、吸塵器（吸走全場寶石）。
- **街區**：1104×1584 的封閉街區，鏡頭跟著主角走，敵人從畫面外湧進來。
- **局外成長**：11 項永久強化，以及 3 個解鎖目標；存檔用 AtomicFile 寫成 JSON。

## 試玩

Godot 開啟 `prototypes/survivor-series/project.godot`，按 F5，入口是 `scenes/game.tscn`。桌面可用滑鼠拖曳，或 WASD／方向鍵。

```bash
bash prototypes/godot-kit/tools/web/build_web.sh prototypes/survivor-series
python3 -m http.server 8793 --bind 127.0.0.1 --directory prototypes/survivor-series/build/web
```

在本機開啟 `http://localhost:8793/index.html`。不要直接雙擊 `index.html`；手機遠端試玩要放在 HTTPS 網站上。Web preset 使用 Compatibility 渲染，沒有 threads 或 GDExtension。

命令列參數（加在 `--` 之後）：`--autoplay` 讓自動駕駛代玩（錄影與壓力測試用），`--duration=<秒>` 縮短一局（上限 600），`--seed=<n>` 固定刷怪亂數。

## 可編輯場景與資料

| 檔案 | 可調整內容 |
|---|---|
| `scenes/game.tscn` | 主流程、`session_duration`、金幣換算（每次揍飛、每分鐘、勝利獎勵、金幣面額）、共用服務與各畫面 |
| `scenes/street.tscn` | 夜市配色與 `NightMarket`（紅白遮陽棚、燈籠）、`heroes` 清單、街區幾何、Camera 的 limit、Player 起點、四類代表性敵人；bounds、敵人／特效／寶石／煙霧上限、磁吸半徑、掉落機率 |
| `scenes/player.tscn` | `BodyMan`／`BodyWoman` 兩套外觀（共用 `Fist`，執行時只顯示選中的一套）、HpBar；移速、拳頭距離、血量、受傷無敵時間 |
| `data/heroes/man.tres`、`woman.tres` | 主角：起手武器、血量與移速倍率、揮擊距離與回彈、選單文字 |
| `scenes/smoker.tscn`、`bike.tscn`、`car.tscn`、`fatty.tscn` | 敵人外觀、預警線、HpBar；交通工具的 `direction_textures`（5 方向圖） |
| `scenes/wave.tscn`、`slipper.tscn`、`pearl.tscn`、`firecracker.tscn`、`incense.tscn`、`lantern.tscn` | 投射物外觀、碰撞半徑、旋轉速度 |
| `scenes/blast.tscn`、`impact.tscn`、`attack_flash.tscn`、`pickup.tscn`、`smoke.tscn` | 爆炸、命中、揮擊、掉落物與煙霧外觀 |
| `scenes/menu.tscn` | 主角選擇（`HeroMan`／`HeroWoman`／`HeroNote`）與選單文字 |
| `scenes/hud.tscn`、`menu.tscn`、`results.tscn`、`pause.tscn`、`upgrades.tscn`、`upgrade_card.tscn`、`shop.tscn`、`shop_item.tscn` | 介面版面、文字與間距 |
| `data/items/*.tres` | 每張卡：武器基礎值與每級成長（含 `slow`／`pull`／`blast_on_end`）、被動加成、進化條件、融合配方（`fuse_a`／`fuse_b`／`fuse_level`）、解鎖條件、卡片文字 |
| `scenes/tofu.tscn`、`ring.tscn`、`rider.tscn` | 新武器的投射物外觀與碰撞半徑；雨傘畫在 `player.tscn` 的 `Umbrella` |
| `data/progression.tres` | 經驗曲線、起始武器、欄位數、卡片清單、補給卡 |
| `data/spawn_schedule.tres` | 刷怪時間軸：每段的生成間隔、數量、敵人權重、血量倍率、同屏上限、包圍圈、精英 |
| `data/meta.tres` | 商店項目（價格、上限、加成）與解鎖目標 |
| `data/smoker.tres`、`bike.tres`、`car.tres`、`fatty.tres` | 血量、速度、重量、經驗、接觸傷害、臭味光環、爆屁 |

場景內的 PreviewEnemy 是編輯器用的代表物件；開局時會清空，再依刷怪時間軸生成。執行期的血量、位移與統計不會寫回 scene。

`tools/add_horde.gd` 已在 2026-10-07 用過一次，用來產生本版的 scene 與 Resource。之後 scene 就是可以維護的來源檔：game.tscn 有 `horde_scene_version` 標記，重跑工具會直接跳過；當次第一輪在 `migrate_street` 中斷，事後只補跑過那一個函式一次，那條補救路徑已經移除。更早的 `tools/add_progression.gd` 與 `build_playable.gd` 是前兩版的一次性工具，留著當紀錄。

## 圖片與聲音

角色、交通工具與背景目前都是幾何佔位（男女主角、煙霧怪與夜市配色已按參考圖調過色）。提示詞見 [opt-image-prompts.md](docs/opt-image-prompts.md)：第一批是男女主角、抽菸者、機車、汽車與夜市背景，第二批是交通工具的 5 方向圖、臭臭胖子、武器與掉落物。原圖放 `assets/source/`，遊戲用圖放 `assets/art/`。

- 主角：把男／女主角圖分別指給 `BodyMan`、`BodyWoman` 底下新增的 Sprite2D，再隱藏該 Body 的幾何多邊形。敵人：把 `Visual/Art.texture` 指向圖片並勾選 visible，再關掉 `Placeholder`。
- 交通工具：另外把 5 張方向圖依「南、東南、東、東北、北」的順序填進根節點的 `direction_textures`；朝西的三個方向會自動鏡像。

音效使用 kit 的 SfxBank／Synth 程序音效。把同名的 `.ogg` 放進 `assets/sfx/` 就會替換。事件名稱：`punch`、`hit`、`metal`、`launch`、`hurt`、`warning`、`start`、`finish`、`death`、`heavy`、`wave`、`kick`、`throw`、`pearl`、`pop`、`incense`、`lantern`、`swish`、`fart`、`gem`、`coin`、`heal`、`chest`、`level`、`upgrade`、`evolve`、`combo`。

Noto Sans TC 是 433 字的子集，粗體 700，約 160 KB，附 [OFL 授權](assets/fonts/OFL.txt)。新增中文後要重新製作子集（完整來源可以用 `pixel-monster/assets/fonts/NotoSansTC.ttf`）：

```bash
python3 prototypes/godot-kit/tools/subset_font.py --project prototypes/survivor-series --source prototypes/pixel-monster/assets/fonts/NotoSansTC.ttf --out prototypes/survivor-series/assets/fonts/NotoSansTC.ttf --weight 700 --minimal
```

## 測試

```bash
bash prototypes/godot-kit/tools/run_tests.sh prototypes/survivor-series growth:600 playable:600 scaffold heroes:60 fusion:60
bash prototypes/godot-kit/sync.sh --check survivor-series
```

- **fusion**：配方門檻、融合換掉兩個零件並空出一格、零件不再重複出現、未發現的融合顯示「？？？」、發現記進存檔、合擊波四面八方、雨傘擋傷與無敵、圈圈拉扯減速、機車與臭豆腐生成。
- **heroes**：選單預設男主角；選女主角後按鈕與說明更新、起手武器與顯示的身體對得上、女主角較快較脆、成長後倍率仍保留、揮拳會回到原位、選擇存檔後重讀仍在。
- **growth（132 項）**：
  - 經驗溢出與多級排隊、第一次升級只出新武器、解鎖限制、6+6 欄位上限、進化條件與保留原欄位、全滿後的補給卡
  - 商店加成、選卡凍結、過期卡片事件、寶箱 1／3／5
  - 判定先後：倒下 > 時間到 > 待選升級
  - 復活、金幣入帳、成就只解鎖一次、存檔來回讀寫、壞檔回到預設值、商店畫面
- **playable（199 項）**：
  - 移動中出拳、揍飛掉寶石、磁吸、寶石合併
  - 汽車重量、機車預警與衝刺、交通工具 8 方向與人物翻面
  - 煙霧與煙霧上限、胖子減速、爆屁排隊連鎖
  - 空間格子對照暴力掃描、15 種武器／進化都會開火並造成傷害、三炷香數量、投射物重複命中間隔
  - 刷怪時間軸（包圍圈、精英、上限、生成在畫面外）
  - 暫停與失焦、自動駕駛短局走到結算、重試
  - 靜態文字保留、原始 scene 不被改動、字型與畫面主題、震屏開關
- **scaffold（7 項）**：最早的入口骨架。

測試用自己的存檔路徑，跑完會刪掉。測試全部用遊戲時間推進。`tools/browser_check.mjs` 還是 90 秒版的瀏覽器檢查，**已過期**，待改寫（TODO T-005）。

`addons/proto_kit/` 由 `../godot-kit/sync.sh survivor-series` 同步，不能直接改副本。本版使用的模組：FloatingStick、TimeControl、SfxBank、Synth、CameraShake、SceneBuilder、TestKit、FontCheck、AtomicFile；Music 已接入，但沒有指定音樂。

## 驗收界線

平衡與效能目前只有 headless 自動駕駛的模擬與桌面瀏覽器的冒煙測試，數字見 [horde-spec.md](docs/horde-spec.md) 的「模擬紀錄」。真機幀率、觸控手感、聲音與「夠不夠爽」仍需要真人試玩。四個參考 repo 的研究見 [reference-repos.md](docs/reference-repos.md)。
