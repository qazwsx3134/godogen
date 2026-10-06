# 行人反擊：90 秒打擊測試場

可玩的 Godot 4.7 原型，支援手機瀏覽器直式與桌面試玩。單指浮動搖桿移動、靠近敵人自動揮拳；普通命中擊退，致命命中誇張揍飛。玩家不死；揍飛取得經驗，升級三選一解鎖衝擊波、回旋踢或橫掃拳。90 秒後統計揍飛、受擊、連殺、等級與本局成長，可直接重試。

三類敵人：抽菸者留下只造成傷害的煙霧、機車先顯示路線再直線衝刺、汽車慢速追近且難推動。打擊包含程序音效、閃光、形變、速度線、震屏與節流的 hit stop。HUD 可關閉震屏；暫停及失焦會停止戰鬥，需按繼續才恢復。

## 本輪新增

開發清單與里程碑見 [TODO.md](TODO.md) 與 [ROADMAP.md](ROADMAP.md)。

十張升級卡：衝擊波、回旋踢、橫掃拳、拳力加重、快拳連打、長臂反擊、強力擊退、蓄力重拳、巨浪衝擊、旋風踢擊。第一輪固定三種攻擊模式，後續抽取合法選項；招式強化有前置與層數上限。選卡時暫停倒數與敵人，選完重新拖曳即可移動。

增加走路起伏、出拳朝向、攻擊弧線與圓環、重拳音效、連續揍飛、敵群重量分離；機車預警與衝刺維持固定路線。

## 試玩

Windows Godot 開啟 `D:\repo\godot\godogen\prototypes\survivor-series\project.godot`，按 F5。入口是 `scenes/game.tscn`。桌面可用滑鼠拖曳，或 WASD／方向鍵。

Web 版建置後放在 `build/web/`，上傳用壓縮包為 `build/survivor-series-web.zip`。不要直接雙擊 `index.html`；本機透過 HTTP localhost，手機遠端試玩則放在 HTTPS 網站。這次未發布到外部平台。

```bash
bash prototypes/godot-kit/tools/web/build_web.sh prototypes/survivor-series
python3 -m http.server 8793 --bind 127.0.0.1 --directory prototypes/survivor-series/build/web
```

在本機開啟 `http://localhost:8793/index.html`。Windows 編輯器的 Web 匯出範本需安裝在 Windows 自己的 Godot 資料目錄；WSL 的範本不會自動共用。Web preset 使用 Compatibility、無 threads／GDExtension。

## 可編輯場景

| Scene | 可調整內容 |
|---|---|
| `scenes/game.tscn` | 主流程、session_duration、共用服務與各畫面 instance |
| `scenes/menu.tscn` | Title、Instructions、Start、Column 的間距 |
| `scenes/street.tscn` | 街區幾何、Camera、Player 起點、三類代表性敵人；bounds、刷怪與演出數量上限 |
| `scenes/player.tscn` | Motion、Visual、Placeholder、Art、Shadow、Fist；移速、攻擊範圍、傷害與間隔 |
| `scenes/smoker.tscn`、`bike.tscn`、`car.tscn` | 敵人外觀、WarningLane／WarningLine、HpBar、definition 資源 |
| `scenes/smoke.tscn` | 煙霧形狀、危險區、radius 與 lifetime |
| `scenes/impact.tscn` | 命中星芒、速度線、Caption 與 lifetime |
| `scenes/joystick.tscn` | 觸控區 anchor／offset、Base／Knob 外觀、radius／dead_zone |
| `scenes/hud.tscn` | SafeTop 邊距、計時條、受擊與揍飛統計、Pause、ShakeToggle |
| `scenes/results.tscn`、`pause.tscn` | 結算與暫停畫面、按鈕、文字與間距 |
| `scenes/upgrades.tscn`、`upgrade_card.tscn` | 升級面板與卡片 item，代表性卡片在編輯器可見；Column／Options 間距、標題與說明文字樣式 |
| `scenes/wave.tscn`、`attack_flash.tscn` | 衝擊波、拳擊弧線與回旋踢圓環；速度、半徑、壽命與線條 |
| `data/progression.tres` | 起始升級 EXP、每級增加值、第一輪選項與升級清單 |
| `data/upgrades/*.tres` | 每張卡的 ID、標題、描述、前置、上限、顏色與效果數值 |
| `data/ui_theme.tres` | 共用字型、字體大小、按鈕樣式與顏色 |
| `data/smoker.tres`、`bike.tres`、`car.tres` | 血量、速度、碰撞半徑、擊退重量、經驗獎勵、煙霧間隔或衝刺時序 |

場景內的三個 PreviewEnemy 是編輯器代表物件；開始一局時清空並依場景資源刷怪。改 Player 起點或靜態文字再執行會保留；執行期血量、位移與統計不回存 scene。

`tools/build_playable.gd` 已於 2026-10-07 使用，保存的 scene 是維護來源。它驗 owner、pack 前後節點數與子場景引用，既有檔案一律跳過；正常開啟、匯入、執行與測試不呼叫產生器。第二輪的 `tools/add_progression.gd` 是已套用的一次性擴充工具，版本標記存在時直接跳過，重跑驗證保留 35 個 scene／resource 的雜湊。最初的 `main.tscn`／`arena.tscn` 與 scaffold 測試保留為入口骨架參考，F5 使用新的 game scene。

## 圖片替換與聲音

第一批 [opt image 提示詞](docs/opt-image-prompts.md)由使用者自行生成，現有角色與背景都是幾何佔位，沒有調用 AI 圖片生成。將原圖放在 `assets/source/` 保留；遊戲用圖放在 `assets/art/`。

在對應角色 scene 將 `Motion/Visual/Art.texture`（主角）或 `Visual/Art.texture`（敵人） 指向遊戲用圖，調整 Sprite2D 的位置／比例並勾選 visible，再將 同一 Visual 下的 `Placeholder.visible` 關閉；腳底或車輪對準 scene 原點，Shadow 留在地面。碰撞與血量無須因換圖修改。街區貼圖使用 `Street/Block/BackgroundArt`；啟用後可關閉 Block 下的幾何地面與周邊裝飾。

本批是單張靜態姿勢，揮拳先以短距離 visual 位移、拳頭與命中特效呈現；不同方向與逐格動畫另行補圖。

音效使用 kit 的 SfxBank／Synth。將 `punch.ogg`、`hit.ogg`、`metal.ogg`、`launch.ogg`、`hurt.ogg`、`warning.ogg`、`start.ogg` 、`heavy.ogg`、`wave.ogg`、`kick.ogg`、`level.ogg`、`upgrade.ogg`、`combo.ogg` 或 `finish.ogg` 放進 `assets/sfx/` 並匯入，可替換對應音效，不改腳本。Web preset 維持全部資源匯出，確保依事件名尋找的聲音會打包。未提供背景音樂；Music 服務已留在場景。

Noto Sans TC 字型從 sugarcane-tanks 的完整來源製作子集，約 110 KB；保留 [OFL 授權](assets/fonts/OFL.txt)。本版使用程序音效與幾何外觀，沒有搬入原作美術或音樂。字型子集是最小字元集合；新增中文後需用 kit 的 subset_font.py 重新製作，並跑字型檢查。

## 測試與重用

```bash
bash prototypes/godot-kit/tools/run_tests.sh prototypes/survivor-series growth:600 playable:600 scaffold
bash prototypes/godot-kit/sync.sh --check survivor-series
```

109 項 growth 檢查包含經驗溢出、合法選項、前置與上限、觸控卡片 signal、選擇凍結、衝擊波穿透只命中一次、回旋踢、前方橫掃、過期選卡事件、結算優先與成長重置。47 項 playable 檢查包括攻擊與移動、致命判定、重量、預警鎖定、煙霧、受擊節流、90 秒流程、暫停與失焦、重試、靜態編輯保留與實際畫面字型；原 scaffold 另有 7 項檢查。快速測試以手動固定步長推進遊戲時間，最後讓原生音訊執行緒收尾。

`tools/browser_check.mjs` 用 Playwright／Chromium 驗證手機真觸控事件、音訊手勢解鎖、升級三選一與真觸控選卡、衝擊波、完整 90 秒成長、物件上限、結算、重試及桌面載入。傳入本機 Playwright 套件與 Chromium 路徑即可重跑，報告與截圖預設寫到 `/tmp/survivor-browser`：

```bash
node prototypes/survivor-series/tools/browser_check.mjs --playwright /path/to/playwright-core --chromium /path/to/chrome --out prototypes/survivor-series/build/qa
```

`addons/proto_kit/` 由 `../godot-kit/sync.sh survivor-series` 同步；修改來源後再同步，不能直接改副本。本版實際使用 FloatingStick、TimeControl、SfxBank、Synth、CameraShake、SceneBuilder、TestKit、FontCheck，Music 已接入但沒有指定音樂。其餘模組保留可用副本，未聲稱已接入。sugarcane-tanks 的房間與甘蔗主流程未複製，細節見 [重用盤點](docs/reuse-audit.md)。

## 設計與驗收界線

四輪訪談與整體實作同意記在 [design-interview.md](docs/design-interview.md)，詞彙記在 [CONTEXT.md](CONTEXT.md)，完整規格見 [first-playable-spec.md](docs/first-playable-spec.md)。本輪升級與攻擊變化見 [progression-spec.md](docs/progression-spec.md)。Boss、局外成長、存檔與正式死亡規則屬於後續版本。

目前的瀏覽器驗證使用模擬手機與軟體 WebGL；真機幀率、瀏海／安全區、喇叭聽感與「夠不夠爽」仍需真人試玩。沒有用自動測試宣稱已完成手感驗收。
