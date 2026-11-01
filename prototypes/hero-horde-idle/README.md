# 全員推王（hero-horde-idle）

手機直式放置與操作推王原型：精英小隊行軍刷寶，養成後讓 100 名英雄分成近戰、遠程、輔助三團挑戰樓層王。行軍自動戰鬥，推王由玩家拖旗避招、安排站位與選擇部位集火。

目前為 master 的融合版及後續樓層／介面改善，更新至 2026-10-30。最新變更與證據見 [進度](docs/PROGRESS.md)及[全專案交接](../../Progress.md)；真人前三層體驗與手機效能仍待驗收。用語見 [CONTEXT.md](CONTEXT.md)。

```text
行軍刷寶 → 英雄／裝備／天賦養成 → 三團推王 → 解鎖下一層
    ↑                            │
    └───── 看戰報、調整隊伍 ──────┘
```

## 執行與存檔

使用 Godot 4.7、Mobile renderer。從 repo 根目錄執行：

```bash
godot --path prototypes/hero-horde-idle
godot --path prototypes/hero-horde-idle -- --save=trial
godot --editor --path prototypes/hero-horde-idle
```

預設啟動 [home.tscn](scenes/home.tscn)，專案視窗設定 430×932；主畫面邏輯尺寸 941×1672，推王邏輯尺寸 720×1280。預設存檔 `user://progress.json`；`--save=trial` 改用 `user://trial.json`。在 macOS，XDG_DATA_HOME 不會改變 user:// 路徑，試玩使用獨立檔名。

此專案以原生手機為方向，目前沒有 Web export preset。使用預設 Mobile renderer 檢查 HD-2D 外觀；Compatibility renderer 的景深與光暈呈現不同。設定可選畫質與 30／60 FPS，手機實際耗電／發熱未完成驗收。

## 六頁主畫面與操作

上方行軍戰場常駐；頭像回總覽，底部五個導覽鈕切換其他頁。

| 頁面 | 內容 |
|---|---|
| 總覽 | 行軍狀態、小隊、隊長、羈絆與戰報 |
| 天賦 | 18 節點天賦星圖；依前置、英雄等級與樓層進度開放 |
| 背包 | 裝備／素材／遺物、資訊、分解與自動分解門檻 |
| 英雄 | 種族篩選、名冊、詳情、突破、上陣、隊長；詳情內換裝與升級 |
| 冒險 | 第 1～10 層、行軍樓層選擇、挑戰樓層王 |
| 商店 | 招募、機率與保底說明、測試商品與免費抽取 |
| `scenes/home.tscn` | 主畫面（941×1672，遊戲從這裡開始；推王是 720×1280，兩邊切換時各自設 `content_scale_size`）：`Pages` 六頁（`scenes/pages/*.tscn` 的實例）、`MarchArena`（常駐行軍戰場，站在每頁的地面線 y=470）、`Header`（總覽、金幣、招募券、設定）、`Navigation`（天賦／背包／英雄／冒險／商店）、`NavDots` 紅點、`Toast`、`Dialog`（離線戰報、招募結果、機率說明共用）、`SettingsOverlay` |
| `scenes/pages/*.tscn` | 遠征紀事的六頁（`tools/build_fusion_ui.gd` 從 `prototypes/taskbar-hero/scenes/pages` 改來）：每頁上方是共用的行軍背景 `MarchBackdrop`（`scenes/components/march_backdrop.tscn` 的實例）、羊皮紙面板 `ContentPanel`、標題與內容。總覽（`MarchStatus`、隊長、`SquadRow` 五格、`BondLabel`、`TodoList`、`CombatLog`）；天賦（`TalentScroll` 裡的 `TalentTree` 星圖，18 個 `talent_node`，`DetailFrame` 與 `LightButton`；節點位置在編輯器拖曳，連線跟著走）；背包（`FilterRow`、`ItemsGrid`、`InfoName`／`InfoText`、分解、自動分解）；英雄（預設是名冊：`AutoEquipButton` 一鍵裝備、`FormFilter`、`HeroGrid`；點英雄打開蓋在頁面上的 `HeroDetail`：`DetailPanel` 數值與技能、`ActionRow` 突破／上陣／隊長、`FactorGrid` 數值明細、`WeaponSlot`／`CharmSlot` 裝備欄位、`UpgradeWeapon` 強化、`SwapGrid` 可換的裝備）；冒險（`ChapterButton`、`StageGrid`、`MarchHereButton`、`DepartButton`）；商店（`ProductGrid`、`GiftButton`、`RatesButton`）。格子裡的卡片執行時依資料實例化 |
| `ui/sao_*.tres`、`scenes/ui_kit/*.tscn` | 刀劍神域風 UI 規範與元件庫（`docs/SAO_UI_SPEC.md`）：樣式一種角色一個檔（`tools/sao_style.gd` 產生；`tools/sao_details.gd` 加標題列／圓形導覽／稀有度色條）。HUD 元件：`sao_gauge` 斜切血條、`sao_unit_bar` 頭上血條（`march_unit.tscn` 的 `HealthBar`）、`sao_boss_bar` 樓層王血條與 `sao_timer_bar` 倒數長條（`hud.tscn` 上方）、`sao_toast` 通知、`sao_party_card` 隊伍卡；`ui_kit_gallery.tscn` 一頁看全部（`tools/build_ui_kit.gd`、`tools/build_sao_hud.gd`） |
| `scenes/components/march_backdrop.tscn` | 行軍戰場的分層背景：`Sky` 不動，`Far`、`Mid`、`Props`、`Ground` 依 metadata `parallax_depth`（0.12／0.35／0.65／1.0）跟著行軍捲動（`march_arena.gd bind_scenery`）；每層是平鋪的 TextureRect，位置與高度在編輯器拖曳，圖由 `tools/pack_backdrop.py` 從 `art_src/bg_layers/` 打包到 `assets/backdrop/`（物件依固定種子排在 `props.png` 上） |
| `scenes/components/*.tscn` | 遠征紀事的元件：頂欄、導覽、訓練列、物品卡、英雄格（`equipment_item_card`）、裝備小卡、關卡卡、商品卡；圖都是 `assets/atlas/*.tres`（參考圖 `assets/reference/*.png` 的區域），字型 `fonts/NotoSansCJKtc-*` |
| `scenes/march_arena.tscn`、`scenes/march_unit.tscn` | 行軍戰場：`Heroes` 5 格、`Enemies` 3 格、`WaveLabel`；一名戰鬥者（遠征紀事的單位：英雄用 `HeroSprite`＝`assets/heroes/heroes.png` 的格子，怪物用 `Visuals` 裡從參考圖切出的外框）。站位與數字在 `march_arena.gd`（`FRONT_X`、`SPACING`、各地區的怪物外觀 `LOOKS`） |
| `scenes/settings_panel.tscn`、`scenes/app.tscn` | 設定面板（音效、震動、畫質 `QualityChoices`、幀率 `FpsChoices`；主畫面與暫停選單共用）；App 自動載入（換畫面的淡入淡出、共用的進度） |
| `scenes/main.tscn` | `Camera`（存檔的位置、角度、`fov` 就是遊戲構圖；震動幅度）、`Stage`、Main 的四個運鏡欄位、`Boss`（`BossSprite` 大小；`PartLegs`／`PartArm`／`PartHorns` 部位位置）、`Flags`（三面旗子；旗子在 scene 裡的位置就是那團的集結位置，執行時交給模擬；`color` 是團色）、`TeleMarkers`（預警形狀的池）、`Army`（存檔裡是開戰陣形的預覽，執行時依模擬重畫）、`Bolts`、`Hud` |
| `scenes/squad_flag.tscn`、`scenes/tele_marker.tscn` | 一面旗子（`Banner` 團旗、名稱、選取時的地面橢圓；根 node 的 `banner` 換旗、`color` 是橢圓顏色）；一個預警形狀 |
| `scenes/hud.tscn` | 上方面板（王名、階段 `PhasePill`、時限 `TimerBox`、王血條、存活與輸出），提示條 `BannerStrip`（文字 `Banner`；框色與「!」方塊執行時依提示換色），部位按鈕 `Parts`（`part_button.tscn` 的實例，執行時跟著王身上的部位），下方面板（三團分頁 `SquadTabs`、士氣條與提示 `Hint`、`Actions` 全員歸位與大招），結算 `Result`；間距、字級在 scene，顏色與框在 `ui/theme.tres` |
| `scenes/stage.tscn` | `WorldEnvironment`（`materials/stage_environment.tres` 色調、光暈、霧、調色；`stage_camera_attributes.tres` 景深）、`Sun`、`Floor`（`stage_ground.tres`：競技場中心與大小、邊緣破碎程度、草地與石地色調）、`Cliffs`、`Props`（移動、縮放、`tint`、`flip`、`lean_deg`）、`BrazierLights`、`TelegraphLights`、`VolleyLight`、光點與火星粒子、`Vignette`；根 node 的匯出欄位調英雄受光強度與預警光亮度 |
| `scenes/reward_row.tscn`、`scenes/ornament_rule.tscn` | 獎勵列表的一行；對話框標題下的菱形分隔線 |
| `scenes/store.tscn` | `Store` 自動載入：測試廣告的倒數卡 `AdOverlay` |
| `ui/theme.tres` | 墨綠暖白的外觀：面板、按鈕（`PrimaryButton` 主要動作、`TabButton`、`CardButton`、`FlatButton`、`PartButton`）、`Heading` 襯線字、`Dim` 次要字、`FieldLabel` 戰場上的描邊字、`HudPanel`、`Pill`、血條／士氣條／經驗條；在編輯器改這個檔就改全部畫面 |
| `scenes/captain_plate.tscn` | 隊長名牌（`main.tscn` 的 `CaptainPlates` 池，3 個）：字型、字級、描邊、顏色在 scene；倒下時的灰在 `captain_plate.gd` |
| `scenes/skill_callout.tscn`、`scenes/name_popup.tscn` | 招牌技卡（在 `hud.tscn` 的 `SkillCallout`：頭像、招式名、英雄、效果；位置、字級、框色都在 scene）；頭上升起的名字（`main.tscn` 的 `Popups` 池） |
| `scenes/push_report.tscn`、`scenes/report_row.tscn` | 推王戰報（在 `hud.tscn` 結算面板的 `Report`）：MVP 頭像與文字、三個榜（每榜 3 個 `report_row` 實例）、診斷；字級、顏色、間距都在 scene |
| `scenes/prop.tscn` | 一個道具：換 `texture` 就換圖，大小自動跟貼圖 |
| `camera/*.tres` | 大招、打壞部位（`break.tres`）、第二階段、勝利、隊長放技能（`captain.tres`）的運鏡 |
| `scenes/main.tscn` 的 `ImpactFx`、`Sfx` | 特效池（`Chunks`、`Rings` 各環）與音效；配色在 `impact_fx.gd` 的 `PALETTES`，環的材質 `materials/fx_ring.tres`，碎塊 `materials/fx_chunk.tres` |
| `materials/*.tres` | 英雄、王、影子的外觀；`ground_mark.tres` 是預警形狀與旗子地面橢圓共用的材質（每個的顏色、填滿程度用 instance uniform） |

英雄共 100 名：人類 40、獸人 30、精靈 30；職業決定推王分團，種族被動同時作用於行軍與推王。行軍小隊從 3 格成長至 5 格，種族羈絆依行軍小隊計算。具體數值以 [heroes.gd](domain/heroes.gd)、[talents.gd](domain/talents.gd)、[progression.gd](domain/progression.gd) 為準。

推王時拖曳英雄群或軍旗移動該團，也可點選一團後點空地移動。點王的部位或部位按鈕讓遠程團集火；下方提供全員歸位、士氣與大招。走動中的英雄停止出手；坦補距離、避開預警與拆除部位都會影響結果。樓層王有兩條血，第一條耗盡後進入第二階段；樓層資料見 [stages.gd](domain/stages.gd)。
美術：Codex 生的原圖在 `art_src/`（派工單、回報、候選圖；Godot 不匯入）。選哪張寫在 `art_src/selected.json`，`uv run --with pillow --with numpy tools/pack_stage_art.py` 把選定的圖縮到統一像素密度、減色、做硬邊透明，地面貼圖做成無縫，輸出到 `assets/stage/`；英雄（`selected.json` 的 `heroes` 是人類、`races` 是獸人與精靈，原圖在 `art_src/races/`；缺的動作用站姿代替）打包成 `assets/heroes/heroes.png`＋`heroes.json`（人類第 0～5 列、獸人 6～11、精靈 12～17；只重做這一步：`... pack_stage_art.py heroes portraits`）；團旗（`flags`，兩格共用裁切、旗桿底部放在格子正中）打包成 `assets/flags/<團>.png`；養成畫面用的站姿大圖（每個種族×職業一張，160 px 高）與頭像裁切框打包成 `assets/heroes/portraits/`（只重做這一步：`... pack_stage_art.py portraits`）；招牌技圖示、職業小旗與英雄頁背景（`selected.json` 的 `ui`，Codex 生的原圖在 `art_src/ui_icons/`；小旗是洋紅底，打包時去背）打包成 `assets/ui/`（`... pack_stage_art.py ui`），還沒有圖時遊戲用職業頭像代替。武器與飾品圖示（`assets/ui/items/` 的 `w_*`、`c_*`）暫時是從 round3 道具設計稿裁下來的（`python3 tools/crop_item_icons.py`：從裁切框邊緣洪水填色去掉面板底色，縮進 96 px）；遺物、素材、招募券（`r_*`、`m_*`）、nav bar 圖示（`assets/ui/nav/`）與招募頁背景（`assets/ui/bg/recruit.png`）是 Codex 生的（`art_src/ui_icons2/`，洋紅底去背），由 `pack_stage_art.py ui` 打包。同一種族同一職業的英雄共用同一張圖。字型：內文 Noto Sans TC，名字與數字用 Noto Serif TC Bold（[notofonts/noto-cjk](https://github.com/notofonts/noto-cjk) 的 SubsetOTF/TC，SIL OFL 1.1，見 `ui/fonts/OFL.txt`），兩者都只保留同一組 6281 個字；新增文字前先確認字型裡有這些字（例如日文的「・」沒有，改用「‧」）。換圖：改 `selected.json` 的路徑再跑一次。git 只收 `art_src/` 的派工單、回報、腳本、`selected.json` 與選定的圖（`art_src/.gitignore` 擋掉其他 png、`inputs/`、`DONE`），新選的圖要用 `git add -f` 加進去。

## 行軍與離線結算

行軍按固定 tick 戰鬥，清完一段後繼續前進；打輸退一層並恢復。擊殺發金幣、小隊經驗及機率掉落，強敵使用三倍獎勵。

離線開頭最多五分鐘模擬戰鬥、升級、退關及恢復，再以更新後隊伍的加權速率估算剩餘時間。保存格式為 v2，保留 v1 遷移；離線上限受天賦影響。長時間及不同種子的估算仍有差距，尚未宣稱與在線完全等價。

算法、48 組對照、退關修正及未驗項目集中在[前三層與離線收益驗收](docs/FIRST-THREE-FLOORS-ACCEPTANCE.md)。主畫面與推王共用 App 的進度；商店目前是測試介面，來源見 [store.gd](scripts/store.gd)。

## 可編輯場景與資料責任

scene 是可維護來源；在編輯器調整後，正常啟動與測試不會重新產生版面。

| 場景／資源 | 可調整的內容 |
|---|---|
| [home.tscn](scenes/home.tscn) | Pages、MarchArena、Header、Navigation、SettingsOverlay |
| [overview.tscn](scenes/pages/overview.tscn) | 總覽面板、小隊與紀錄配置 |
| [train.tscn](scenes/pages/train.tscn) | TalentScroll／TalentTree 節點位置與連線配置 |
| [backpack.tscn](scenes/pages/backpack.tscn) | 篩選、ItemsGridScroll／ItemsGrid 與資訊區 |
| [heroes.tscn](scenes/pages/heroes.tscn) | HeroGrid、HeroDetail 與裝備操作區 |
| [adventure.tscn](scenes/pages/adventure.tscn) | StageGrid 與挑戰操作區 |
| [store.tscn](scenes/pages/store.tscn) | 招募與商品版面 |
| [main.tscn](scenes/main.tscn) | 推王 Camera、Stage、Flags、Army 與 Hud |
| [march_arena.tscn](scenes/march_arena.tscn)、[march_unit.tscn](scenes/march_unit.tscn) | 行軍隊伍站位與戰鬥者呈現 |
| [stage.tscn](scenes/stage.tscn) | 光照、道具、地面、WorldEnvironment |
| [settings_panel.tscn](scenes/settings_panel.tscn) | 共用設定面板 |

介面規格及元件入口見 [SAO_UI_SPEC.md](docs/SAO_UI_SPEC.md)。主畫面樣式集中於 `ui/sao_*.tres`，推王 Theme 在 [theme.tres](ui/theme.tres)，元件在 `scenes/ui_kit/`。原創種族與背景素材仍有待作者選擇的批次，見[種族素材規格](docs/race-art-prompts.md)與[背景圖層規格](docs/bg-layer-prompts.md)。

規則分工：`domain/march_sim.gd` 負責行軍戰鬥，`domain/push_sim.gd` 負責推王，`domain/progression.gd` 負責養成、收益與保存；`scripts/home.gd` 和各頁腳本協調畫面。`addons/proto_kit/` 是同步副本，維護規則見[kit 版本與同步](../godot-kit/docs/VERSION-SYNC.md)。

`tools/` 的 scene 產生器只供製作使用；重跑前檢查 diff 與覆寫行為，保留人工編輯。既有製作流程、素材打包命令與版本經驗保存在[歷史快照](docs/history/README-2026-10-30.md)。

## 分層驗證

從 repo 根目錄使用會檢查腳本錯誤的 runner：

```bash
env XDG_DATA_HOME=/tmp/hero-tests XDG_CONFIG_HOME=/tmp/hero-tests-config TEST_TIMEOUT=120 \
  bash prototypes/godot-kit/tools/run_tests.sh prototypes/hero-horde-idle march progression home main
```

| 改動範圍 | 對應測試 |
|---|---|
| 行軍／收益 | march |
| 養成／保存 | progression |
| 推王戰鬥／技能 | balance、skills |
| 戰報 | report |
| 招募／測試商店 | recruit |
| 跨養成、行軍、推王互動 | 對應測試加 home、main |
| 完整樓層曲線 | stages；完整 suite 等作者手動驗收後執行 |

改 scene／resource 另做 headless 匯入。機器人結果用於規則及曲線驗證，不能替代真人「看懂敗因、想再次挑戰」的證據。本輪收益修正的 L2 四組通過紀錄在 `/tmp/godot-tests.GbS3oh`，其他較早結果依 [PROGRESS.md](docs/PROGRESS.md) 的日期查核。

截圖命令從遊戲根目錄執行：

```bash
godot --path . --resolution 470x836 --script res://tools/capture_home.gd -- /tmp/hero-home-shots
godot --path . --resolution 390x844 --script res://tools/capture_shots.gd -- /tmp/hero-push-shots
```

## 決策與歷史

[FUSION.md](docs/FUSION.md) 保存 2026-10-27 的融合決定；當時七頁、形態用語與介面描述屬歷史基線。現在的頁面／種族／收益行為以本 README 及來源碼為準。早期 bot 勝率、配色、無存檔原型與完整版本沿革見[歷史快照](docs/history/README-2026-10-30.md)，不作為目前版本的驗收結果。

2026-10-30 存檔保護：較新／不支援版本、破損 JSON 與空檔會保留原檔並停止寫入，主畫面會提示目前遊玩不保存。保存前也重新檢查目標版本。L2 四組 PASS，詳見[規則與限制](docs/SAVE-PROTECTION.md)；已加入英雄陣列、物品／詞綴、UID 與舊格式相容驗證。本輪沒有改 schema、未產生手機安裝包、未 commit／push。
