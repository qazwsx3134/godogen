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

英雄共 100 名：人類 40、獸人 30、精靈 30；職業決定推王分團，種族被動同時作用於行軍與推王。行軍小隊從 3 格成長至 5 格，種族羈絆依行軍小隊計算。具體數值以 [heroes.gd](domain/heroes.gd)、[talents.gd](domain/talents.gd)、[progression.gd](domain/progression.gd) 為準。

推王時拖曳英雄群或軍旗移動該團，也可點選一團後點空地移動。點王的部位或部位按鈕讓遠程團集火；下方提供全員歸位、士氣與大招。走動中的英雄停止出手；坦補距離、避開預警與拆除部位都會影響結果。樓層王有兩條血，第一條耗盡後進入第二階段；樓層資料見 [stages.gd](domain/stages.gd)。

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
