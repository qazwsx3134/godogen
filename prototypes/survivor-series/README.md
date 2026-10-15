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
- **敵人**：抽菸者（刺青叼菸的流氓，留下煙霧）、機車（預警後衝刺）、汽車（慢、重、血厚）、臭臭胖子（臭味光環讓主角減速；被揍飛時爆屁，炸飛周圍敵人，可以連鎖）。4:00、6:00、8:00、9:00 會出現精英，打倒後掉寶箱，可以多選 1、3 或 5 次。
- **掉落**：經驗寶石（超過上限就合併成大寶石）、金幣、滷肉飯（回血）、吸塵器（吸走全場寶石）。
- **街區**：無限延伸的夜市街道，視角參考 PokéSurvivor（見 [pokesurvivor-reference.md](docs/pokesurvivor-reference.md)）：鏡頭拉遠（`zoom` 0.72），主角、敵人與道具依 y 排序前後遮擋，飛行的投射物離地 18 px、地上有影子，繞身軌道壓成橢圓。鏡頭跟著主角走，敵人從畫面外湧進來；活動範圍（`bounds`）跟著主角移動，至少比畫面大 240 px。在畫面外落後超過 2.5 秒的一般敵人會被搬到主角前進方向的畫面外。每 38～56 秒一波「下班人潮」從同一個方向湧入（精英在場時暫停，且一般生成減半）。畫面外的寶箱與精英在畫面邊緣有金色菱形。
- **街頭道具**：每個地圖區塊約八成機率放一組夜市群（一排攤位、兩排夾走道、三角錐路障）。所有道具都是路障，擋主角、敵人與飛行的投射物，敵人會沿邊緣繞過去。三角錐、花台、水果箱打得破，掉經驗、金幣，水果箱另掉滷肉飯或吸塵器；打破後路障跟著消失，整局不會再長回來。拳頭附近沒有敵人時會去打道具。
- **選卡重抽**：每局 1 次。
- **局外成長**：11 項永久強化，以及 3 個解鎖目標；存檔用 AtomicFile 寫成 JSON。

## 試玩

Godot 開啟 `prototypes/survivor-series/project.godot`，按 F5，入口是 `scenes/game.tscn`。桌面可用滑鼠拖曳，或 WASD／方向鍵。

```bash
bash prototypes/godot-kit/tools/web/build_web.sh prototypes/survivor-series
python3 -m http.server 8793 --bind 127.0.0.1 --directory prototypes/survivor-series/build/web
```

在本機開啟 `http://localhost:8793/index.html`。不要直接雙擊 `index.html`；手機遠端試玩要放在 HTTPS 網站上。Web preset 使用 Compatibility 渲染，沒有 threads 或 GDExtension。

QA 命令列參數（Godot 編輯器執行檔，或帶 `survivor_qa` feature 的匯出；加在 `--` 之後）：`--autoplay` 讓自動駕駛代玩（錄影與壓力測試用），`--duration=<秒>` 縮短一局（上限 600），`--seed=<n>` 固定刷怪亂數。QA 使用 `user://survivor_meta_qa.json`，正式進度為 `user://survivor_meta.json`。

正式 `Web` 忽略網址的 `duration`。需要短局時匯出獨立的 `Web QA` preset（`build/qa/index.html?duration=25`），完成時顯示「測試局完成」，獎勵與紀錄留在 QA 存檔。

```bash
mkdir -p prototypes/survivor-series/build/qa
godot --headless --path prototypes/survivor-series --export-release "Web QA" build/qa/index.html
python3 prototypes/godot-kit/tools/web/patch_idbfs.py prototypes/survivor-series/build/qa/index.js
```


## 可編輯場景與資料

| 檔案 | 可調整內容 |
|---|---|
| `scenes/game.tscn` | 主流程、`session_duration`、金幣換算（每次揍飛、每分鐘、勝利獎勵、金幣面額）、共用服務與各畫面 |
| `scenes/street.tscn` | `Map`（`Ground` 地磚、夜市群場景與權重、每格出現機率、起點淨空半徑）、`World`（y-sort：道具、敵人、主角）、`heroes` 清單、Player 起點、四類代表性敵人、`Camera` 的 `zoom`、`Markers`（畫面外菱形的顏色、大小）；bounds 大小、敵人／特效／寶石／煙霧上限、磁吸半徑、掉落機率、落後搬移秒數 `relocate_after`、精英在場的生成倍率、`Surge` 群組（間隔、人數、橫幅文字） |
| `scenes/props/*.tscn` | 8 種地圖道具（攤位、燈籠柱含暖光暈與濕地倒影、花台、三角錐、護柱、停放機車、水果箱），腳底在原點；`Block/Footprint` 長方形就是路障（擋主角、敵人與飛行投射物）；根節點 `prop.gd` 的 `hp`（0＝打不破）、`hit_radius` 與掉落 |
| `scenes/clusters/*.tscn` | 夜市群：`market_row`、`market_double`、`roadblock`；在 `street.tscn` 的 `Map.cluster_scenes`／`cluster_weights`／`cluster_chance` 調出現率 |
| `scenes/player.tscn` | `BodyMan`／`BodyWoman` 兩套外觀（共用 `Fist`，執行時只顯示選中的一套）、HpBar；移速、拳頭距離、血量、受傷無敵時間 |
| `data/heroes/man.tres`、`woman.tres` | 主角：起手武器、血量與移速倍率、揮擊距離與回彈、選單文字 |
| `scenes/smoker.tscn`、`bike.tscn`、`car.tscn`、`fatty.tscn` | 敵人外觀、預警線、HpBar；交通工具的 `direction_textures`（5 方向圖） |
| `scenes/wave.tscn`、`slipper.tscn`、`pearl.tscn`、`firecracker.tscn`、`incense.tscn`、`lantern.tscn` | 投射物：`Visual/Art` 像素圖（`assets/pixel/fx/`，舊的向量圖形隱藏在同一個 Visual 下）、碰撞半徑 `radius`、影子 `shadow_size`、特效配色 `palette`、拖尾 `trail`（ember／spark／drip）、旋轉速度 |
| street 的 `Fx`（kit 的 `addons/proto_kit/pixel_vfx.gd`） | 方塊粒子、0.12／0.18 秒方向揮擊、碰撞後才出現的 0.09／0.14 秒星芒、0.3 秒爆竹、0.55 秒半透明臭氣。地面圈在 `ground_z_index=-1`，打擊在 z=8；字幕間隔至少 0.45 秒。Inspector 可調 5 色配色、各類上限。`stats()` 回報粒子、形狀、shader 與略過數，`snapshot().effects` 為裝飾 renderer 的實際總數。危險煙霧由自己的 scene 管理。 |
| `assets/fx/hit_flash.tres` | 敵人受擊閃白（四種敵人的 `Visual/Art` 共用；modulate 三個通道都超過 1 就變白色剪影） |
| `scenes/pickup.tscn` | 掉落物外觀 |
| `scenes/smoke.tscn` | `Footprint/DangerArea` 填色、`DangerBoundary` 圓形傷害邊界、`Cloud` 的 shader／尺寸／位置。`radius` 同步縮放顯示範圍；`lifetime` 同時決定消失與停止傷害。邊界在角色下方、低矮煙絲在腳邊上方，不佔裝飾 shader 配額。 |
| `scenes/menu.tscn` | 主角選擇（`HeroMan`／`HeroWoman`／`HeroNote`）與選單文字 |
| `scenes/hud.tscn`、`menu.tscn`、`results.tscn`、`pause.tscn`、`upgrades.tscn`、`upgrade_card.tscn`、`shop.tscn`、`shop_item.tscn` | 介面版面、文字與間距。hud：頂端經驗條 `Experience`、計時、`EliteBar`（精英在場才出現）、`Banner`（下班人潮）、底部 `Weapons`／`Passives` 格；menu／results／pause／shop 的 `Box` 是夜市雙框盒子，upgrades 的 `Glass` 是半透明面板、`Reroll` 重抽；震屏開關在 pause |
| `scenes/weapon_slot.tscn`、`passive_slot.tscn` | HUD 的武器／被動格（圖示、沒圖示時的字、等級點） |
| `data/ui_theme.tres` | 像素字（俐方體 11 號，缺字用 Noto 補）、字級 22，按鈕／主要按鈕 `PrimaryButton`／玻璃卡 `GlassCard`／盒子／進度條 `XpBar`、`EliteBar` 的 9-slice 框（`assets/ui/`） |
| `scenes/damage_number.tscn` | 傷害數字：根節點 scale 讓 1 字型像素＝1 素材像素；一般白、致命金、主角受傷紅「-N」 |
| `data/items/*.tres` | 每張卡：武器基礎值與每級成長（含 `slow`／`pull`／`blast_on_end`）、被動加成、進化條件、融合配方（`fuse_a`／`fuse_b`／`fuse_level`）、解鎖條件、卡片文字 |
| `scenes/tofu.tscn`、`ring.tscn`、`rider.tscn` | 新武器的投射物外觀與碰撞半徑；雨傘畫在 `player.tscn` 的 `Umbrella` |
| `data/progression.tres` | 經驗曲線、起始武器、欄位數、卡片清單、補給卡 |
| `data/spawn_schedule.tres` | 刷怪時間軸：每段的生成間隔、數量、敵人權重、血量倍率、同屏上限、包圍圈、精英 |
| `data/meta.tres` | 商店項目（價格、上限、加成）與解鎖目標 |
| `data/smoker.tres`、`bike.tres`、`car.tres`、`fatty.tres` | 血量、速度、重量、經驗、接觸傷害、臭味光環、爆屁 |

場景內的 PreviewEnemy 是編輯器用的代表物件；開局時會清空，再依刷怪時間軸生成。執行期的血量、位移與統計不會寫回 scene。

`tools/add_horde.gd` 已在 2026-10-07 用過一次，用來產生本版的 scene 與 Resource。之後 scene 就是可以維護的來源檔：game.tscn 有 `horde_scene_version` 標記，重跑工具會直接跳過；當次第一輪在 `migrate_street` 中斷，事後只補跑過那一個函式一次，那條補救路徑已經移除。更早的 `tools/add_progression.gd` 與 `build_playable.gd` 是前兩版的一次性工具，留著當紀錄。`tools/add_poke_view.gd`（2026-10-13 已套用）只新增了 street 的 `Markers`、hud 的 `Banner`、upgrades 的 `Reroll` 三個節點，重跑會跳過。

## 圖片與聲音

**像素風**（[pixel-ui-plan.md](docs/pixel-ui-plan.md)）：畫面上每個素材像素都是 2 px。場景用的是 `assets/pixel/` 的縮小版，原圖留在 `assets/art/`。重做縮小版：`godot --headless --path . -s tools/build_pixel_scenes.gd -- --plan` 列出尺寸，再 `uv run --no-project --with pillow --with numpy python tools/pixelize.py`。場景已經套用過一次（`assets/pixel/.applied`），之後換圖只要覆蓋同名檔。介面框由 `tools/make_ui_frames.py` 畫，主題與 HUD 由 `tools/build_pixel_ui.gd` 一次產生（`assets/ui/.applied`），之後以 `data/ui_theme.tres` 與場景為準。

地面、地圖道具、男女主角、四種敵人、交通工具 5 方向、掉落物與每一張卡片（武器、被動、進化、融合）的圖示都已換成正式圖（`assets/art/`，清單見該資料夾 README）；拳頭、雨傘、飛行中的臭豆腐與機車騎士用 `assets/pixel/fx/` 的像素圖。幾何佔位仍留在場景裡（隱藏）。卡片圖示由 Codex 生的 3×3 圖示表切出：`uv run --no-project --with pillow --with numpy --with scipy python tools/slice_icon_sheet.py art_src/icons/sheets` 寫 `assets/pixel/icons/<id>_24.png`（同名覆蓋，不用改 `.tres`）。提示詞見 [opt-image-prompts.md](docs/opt-image-prompts.md)：第一批是男女主角、抽菸者、機車、汽車與夜市背景，第二批是交通工具的 5 方向圖、臭臭胖子、武器與掉落物。原圖放 `assets/source/`，遊戲用圖放 `assets/art/`。

- 主角：把男／女主角圖分別指給 `BodyMan`、`BodyWoman` 底下新增的 Sprite2D，再隱藏該 Body 的幾何多邊形。敵人：把 `Visual/Art.texture` 指向圖片並勾選 visible，再關掉 `Placeholder`。
- 交通工具：另外把 5 張方向圖依「南、東南、東、東北、北」的順序填進根節點的 `direction_textures`；朝西的三個方向會自動鏡像。

音效使用 kit 的 SfxBank／Synth 程序音效。把同名的 `.ogg` 放進 `assets/sfx/` 就會替換。事件名稱：`punch`、`hit`、`metal`、`launch`、`hurt`、`warning`、`start`、`finish`、`death`、`heavy`、`wave`、`kick`、`throw`、`pearl`、`pop`、`incense`、`lantern`、`swish`、`fart`、`gem`、`coin`、`heal`、`chest`、`level`、`upgrade`、`evolve`、`combo`。

介面字型是俐方體 11 號（Cubic 11 v1.500，<https://github.com/ACh-K/Cubic-11>，OFL 1.1，無保留字型名稱），子集 `assets/fonts/Cubic11.ttf`，完整來源 `art_src/fonts/Cubic_11.ttf`，授權 [Cubic_11-LICENSE.md](assets/fonts/Cubic_11-LICENSE.md)；字級只用 11 的倍數。俐方體沒有的字（目前只有「炷」）由 Noto Sans TC 補。Noto Sans TC 是子集，粗體 700，約 180 KB，附 [OFL 授權](assets/fonts/OFL.txt)。新增中文後要重新製作子集（完整來源可以用 `pixel-monster/assets/fonts/NotoSansTC.ttf`）：

```bash
uv run --no-project --with fonttools python prototypes/godot-kit/tools/subset_font.py --project prototypes/survivor-series --source prototypes/pixel-monster/assets/fonts/NotoSansTC.ttf --out prototypes/survivor-series/assets/fonts/NotoSansTC.ttf --weight 700 --minimal
uv run --no-project --with fonttools python prototypes/godot-kit/tools/subset_font.py --project prototypes/survivor-series --source prototypes/survivor-series/art_src/fonts/Cubic_11.ttf --out prototypes/survivor-series/assets/fonts/Cubic11.ttf --minimal
```

## 測試

```bash
bash prototypes/godot-kit/tools/run_tests.sh prototypes/survivor-series growth:600 playable:600 scaffold heroes:60 fusion:60 view:60
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
- **view（24 項）**：鏡頭距離、y 排序與圖層、投射物離地與橢圓軌道、攤位擋路、打破道具掉寶且不會長回來、拳頭打道具、落後敵人搬到前方（精英不搬）、下班人潮與橫幅、精英在場時降低生成、畫面外寶箱指示、重抽。
- **scaffold（7 項）**：最早的入口骨架。

介面截圖（不會跳視窗，在 Xvfb 虛擬螢幕跑）：`env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1280x1280x24" godot --path . --fixed-fps 60 --resolution 390x844 -s res://tools/ui_tour.gd -- --out=<資料夾>`，依序存主選單、戰鬥（精英、機車預警、畫面外寶箱）、選卡、暫停、結算、商店。`capture.sh` 在 Linux 也會自動用 Xvfb。

測試用自己的存檔路徑，跑完會刪掉。測試全部用遊戲時間推進。瀏覽器檢查：匯出 `Web QA` 後 `python3 -m http.server 8793 -d build/qa &`，再 `node tools/browser_check.mjs --playwright <playwright-core 路徑> --chromium <chrome 路徑>`（用法見檔頭）。

`addons/proto_kit/` 由 `../godot-kit/sync.sh survivor-series` 同步，不能直接改副本。本版使用的模組：FloatingStick、TimeControl、SfxBank、Synth、CameraShake、SceneBuilder、TestKit、FontCheck、AtomicFile；Music 已接入，但沒有指定音樂。

## 驗收界線

平衡與效能目前只有 headless 自動駕駛的模擬與桌面瀏覽器的冒煙測試，數字見 [horde-spec.md](docs/horde-spec.md) 的「模擬紀錄」。真機幀率、觸控手感、聲音與「夠不夠爽」仍需要真人試玩。四個參考 repo 的研究見 [reference-repos.md](docs/reference-repos.md)。

## 2026-10-15 P1／P2 與 VFX 調整

- 快速直飛／回旋投射物以整段路徑查路障，依第一次接觸排序敵人；在牆面停止或引爆。拋物、落物、軌道與伸展武器保持各自的穿越規則。
- 傷害煙霧擁有獨立材質與持續地面範圍，裝飾 shader 滿額仍可見；生命週期跟著戰鬥暫停。
- 正式／QA 匯出與存檔分開；瀏覽器預算讀真正的 PixelVfx 統計，粒子 500、形狀 80、shader 12。形狀預算保留最後 8 格給命中；危險煙霧另受 `max_hazards=10` 限制。
- VFX 以 PokéSurvivor 的短打擊、像素粒子與清楚圖層為參考，保留台灣夜市美術；見 [調整紀錄](docs/vfx-polish-2026-10-15.md)。
