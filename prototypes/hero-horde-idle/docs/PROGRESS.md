# 全員推王：進度與商業化缺口（2026-10-27 融合版交接）

回來時先讀這份，再看 [FUSION.md](FUSION.md)（融合的決定與系統）、[ROADMAP.md](ROADMAP.md)（里程碑）與 [../README.md](../README.md)（規格、可編輯的 scene、執行方式）。

## 現在在哪裡

v3.0 融合版（在 `fusion-idle` 開發，2026-10-27 合併進 master：`7b6964a`）。全員推王為主幹，併入遠征紀事的七頁介面與裝備撿寶、夢靈遠行的小隊編成與羈絆。

```
 已完成                                         驗證狀態（2026-10-27）
 ──────────────────────────────────────         ───────────────────────────────
 七頁主畫面＋常駐行軍戰場（遠征紀事圖稿）         截圖逐頁看過；作者沒玩過
 行軍真戰鬥（波次、行軍、退關、離線實測）         test_march；作者沒玩過
 形態（人類／怪獸／夢靈）與被動、羈絆             test_march、推王截圖
 訓練取代職業等級、上陣格 3→5、圖鑑               test_progression、test_stages
 裝備詞綴、自動分解、背包上限                     test_progression
 推王（三團、預警、部位、大招、戰報）             test_balance／report／skills／main
 存檔 v2（v1 舊檔：職業等級退款、裝備轉實例）     test_progression
```

## 第六輪回饋（2026-10-28 晚）

作者：「士氣不能用點數來算，要算攻擊頻率，被王傷害會扣；不然後期傷害提高會很快就滿。」

| 項目 | 狀態 | 檔案 |
|---|---|---|
| 士氣改成出手頻率：每名攻擊中的英雄每秒 +0.08（開場約 70 人，約 25 秒集滿），英雄被王打到 −1、被打倒再 −3；傷害多少不再影響士氣 | 完成；`test_main` 加了「被打扣士氣」「攻擊 ×20 不會集得更快」 | `domain/push_sim.gd MORALE_*` |
| 後期大招變少，機器人在第 4 層後需要的戰力變高（約 1.6～2.4 倍）；過關節奏檢查仍通過，推薦戰力重新校準：第 4 層起 ×1.6、之後每層再 ×1.03 | 完成，`test_stages` PASSED | `domain/stages.gd late_of` |

驗證：`test_skills`、`test_main`、`test_report`、`test_balance`、`test_stages`、`test_progression` PASSED（另見第五輪的 `test_home`、`test_march`、`test_recruit`）。第三～六輪於 2026-10-28 依作者指示 commit 到 master（未 push）。

## 第五輪回饋（2026-10-28 晚）

| # | 項目 | 狀態 | 檔案 |
|---|---|---|---|
| 1 | 英雄詳情：拿掉經驗條；裝備欄位移到立繪旁；點欄位開「更換裝備」視窗（目前裝備、背包候選、點一件看比較、裝備／強化武器）；「數值明細」改成按鈕開視窗；「經驗藥水」改「升級」，開升級視窗（經驗條＋三種藥水：用 1 瓶／升 1 級）；四顆動作鈕中現在值得按的加金邊（突破夠素材、升級有藥水、上陣有空位、還沒有隊長） | 完成 | `tools/build_hero_detail_v2.gd`、`scripts/pages/heroes_page.gd`、`ui/sao_attention.tres` |
| 1 | 經驗藥水分三種，給經驗不是直接升級：小 500、中 3000、大 15000（Lv10→11 要 6000）；行軍掉小（0.4%）與中（0.05%），樓層王 2 瓶中、首次通過再 1 瓶大；舊存檔的藥水轉成小藥水 | 完成，有測試 | `domain/progression.gd POTIONS` |
| 2 | 士氣：英雄打在王身上的每一點傷害（普攻、技能、招牌技）給 0.01 士氣，滿 100（＝1 萬傷害）可以放大招；大招本身不加士氣。開場約 375／秒輸出時大約 27 秒集滿 | 回答 | `domain/push_sim.gd MORALE_*` |
| 2 | 英雄只有人型：形態改種族 人類／獸人／精靈（被動與羈絆數值不變：獸人嗜血、精靈自然之癒），60 名英雄改成獸人與精靈的名字；美術生好前三族都用人類的圖。提示詞 `docs/race-art-prompts.md`（24 張，放 `art_src/races/`） | 完成；**等作者生圖** | `domain/heroes.gd`、`data/hero_names.json`、`scripts/portraits.gd`、`scripts/army.gd` |
| 3 | 道具圖示去背：從參考圖裁出 41 張（裝備、素材、遺物、天賦、商品）去背、丟掉殘留的「Lv」字樣，輸出 `assets/ui/items_clean/`，atlas 改指過去；戒指的洞也挖空 | 完成（原 atlas 備份在 `~/.claude/backups/20261028-hero-horde-atlas-before-cut/`） | `tools/cut_item_icons.py` |
| 4 | 版面：拿掉各頁標題下的說明行；名冊與背包 5→4 欄、加大間距；英雄卡 200×150（稀有度等級與「行軍中」分開）；背包卡數量移到右上；總覽拿掉重複資訊、拉開區塊與待辦間距；冒險拿掉長註解 | 完成 | `tools/ux_spacing.gd` |

驗證：`test_progression`、`test_home`、`test_main`、`test_march`、`test_report`、`test_skills`、`test_recruit` PASSED；六頁、英雄詳情與三個彈出視窗重拍確認。`test_stages`、`test_balance` 沒跑（數值沒動）。

## 第四輪回饋（2026-10-28 下午）

作者給了刀劍神域遊戲內 HUD 的截圖（repo 根目錄 `docs/sao/`：隊伍血條、敵人血條、打倒通知）。

| # | 項目 | 狀態 | 檔案 |
|---|---|---|---|
| 1 | UI 規範 `docs/SAO_UI_SPEC.md`（HUD 層＝深色玻璃＋細框＋斜切血條＋菱形；選單層＝白色視窗＋金色選取；色票、線寬、字、元件、規則）與元件庫 `scenes/ui_kit/`（`sao_gauge`、`sao_unit_bar`、`sao_boss_bar`、`sao_timer_bar`、`sao_toast`、`sao_party_card`、`ui_kit_gallery`）。行軍拿掉隊長名牌，每個角色頭上換成 `sao_unit_bar` | 完成；通知條與隊伍卡做好但還沒接進遊戲 | `tools/build_ui_kit.gd`、`tools/build_sao_hud.gd`、`scripts/ui_kit/` |
| 2 | 推王英雄全變「史萊姆」：v3.0 圖集擴成 18 列，`materials/heroes.tres` 的 `frames` 還是 (9, 6)，每格塞 3 列被壓扁（HEAD 上就有）。`army.gd` 改成依 heroes.json 設定，材質值改對，`test_main` 加檢查 | 完成，截圖確認人類／野豬／魔狼／史萊姆正常 | `scripts/army.gd`、`materials/heroes.tres` |
| 3 | 經驗藥水：行軍每殺一隻 0.4%（菁英 ×3）、離線依期望值、打贏樓層王 2 瓶；英雄詳情「經驗藥水 N」一瓶升 1 級（不超過上限），沒行軍的也能用；背包素材、行軍紀錄、離線戰報、推王結算都列出；存檔欄位 `potions`；用自己的亂數流，不動既有掉落 | 完成 | `domain/progression.gd`、`scripts/pages/heroes_page.gd`、`tools/build_potion_button.gd` |
| 4 | 推王上方只剩暫停、樓層王名字＋斜切血條（右上 ×2／×1）、倒數長條（青，剩 20% 轉紅，無數字）；樓層、階段、輸出等舊標籤藏起來（程式仍更新，測試讀得到） | 完成 | `scenes/hud.tscn`、`scripts/hud.gd` |

驗證：`test_progression`（加藥水測試）、`test_home`（加藥水按鈕）、`test_main`（加材質格數檢查）、`test_march`、`test_skills`、`test_report` PASSED；推王與主畫面重拍確認。`test_stages`、`test_recruit`、`test_balance` 這輪沒跑（藥水不影響推王數值，機器人不用藥水）。

## 第三輪回饋（2026-10-28）

作者的 7 點寫在 `../REVIEW.md`。先做與風格無關的四點，再依作者對三個問題的回答做風格、樓層與背景提示詞。作者說先不要 commit；Track A 的差異另存 `~/.claude/backups/20261028-hero-horde-trackA.patch`。

| # | 項目 | 狀態 | 檔案 |
|---|---|---|---|
| 4 | hover 時看不見：背包物品卡 `inventory_card` 的 `InspectButton` hover／按下樣式是不透明藍色塊，整格蓋住 → 改成半透明＋金框；另外 75 顆深色字按鈕 hover 時字變白 → 補上 hover／按下／focus 字色 | 完成；用滑鼠移動＋點擊的探測腳本截圖確認 | `scenes/components/inventory_card.tscn`、`scenes/**/*.tscn` |
| 6 | 頂欄拿掉頭像、等級、經驗條，左邊換成「總覽」大按鈕（設定鈕旁的總覽移過去） | 完成 | `scenes/components/header.tscn`、`scripts/home.gd` |
| 5 | 拿掉「裝備」分頁（導覽 6→5 顆、`equipment.tscn`／`equipment_page.gd` 刪除）；英雄頁預設是名冊，標題列有「一鍵裝備」；點英雄打開蓋在頁面上的 `HeroDetail`（不蓋導覽列）：卡片、突破／上陣／隊長、數值明細（`progression.gd stat_factors`，各乘數相乘＝攻擊／生命，有測試）、裝備欄位（該職業共用的武器＋強化、專屬飾品；點欄位後下方列出背包裡能換的，點了就裝上）；待辦的「換裝備／強化武庫」改跳英雄頁 | 完成 | `tools/build_hero_detail.gd`、`tools/build_nav5.gd`、`scenes/pages/heroes.tscn`、`scripts/pages/heroes_page.gd` |
| 3 | 天賦 9→18 節點，星圖可上下捲動；新節點：學識（行軍經驗）、尋寶（掉寶）、鍛造（武器效果）、共鳴（飾品效果）、領袖（隊長加成）、劍聖／不屈（第二條攻擊／生命 ×1.04）、迅捷（冷卻）、長征（離線 +2 小時）。新節點除了前置節點，還要「打倒第 N 關的關卡王」與「英雄最高等級」（例：學識要 1-1、Lv10；劍聖要 2-1、Lv25）；詳情列出還缺什麼 | 完成；舊 9 個節點的條件不變，存檔自動補長 | `domain/talents.gd`、`tools/build_talent_tree.gd`、`scenes/pages/train.tscn`、`scripts/ui_art.gd` |
| 1 7 | 作者選「刀劍神域平面白」：白色不透明視窗（陰影）＋淺灰標題列與刻線、區塊用上方細線分隔、白底卡片＋左側稀有度色條、白鈕＋金色主要鈕、深色條上的圓形導覽（深藍圓盤＋細環，所在頁變金環）、行軍戰場左上的斜切 HP 條名牌（綠／黃／紅）；推王的 `ui/theme.tres` 同一套色、王血條改斜切兩條。參考圖在 `docs/ui-reference/`（不進 git）；作者給的 SAO-UI repo 只借配色與尺寸，不用其字型、圖示與圖檔（無授權或仿原作） | 完成，等作者看 | `tools/sao_style.gd`、`tools/sao_details.gd`、`tools/build_leader_plate.gd`、`tools/theme_taskbar.gd`、`ui/sao_*.tres`、`scenes/leader_plate.tscn` |
| 7 | 「層 跟 boss」：關卡改成第1～10層、每層一隻有名字的樓層王（`stages.gd BOSSES`），兩條血＝推王原本的第二階段（50% 狂暴換招），戰鬥模擬沒改；全部「關卡王」改「樓層王」，CONTEXT 用語同步 | 完成 | `domain/stages.gd`、`scripts/hud.gd`、`scripts/pages/adventure_page.gd`、`CONTEXT.md` |
| 2 | 背景分層：作者選給 opt image 提示詞 → `docs/bg-layer-prompts.md`（天空、遠山、中景、去背物件、地面；放 `art_src/bg_layers/`） | **等作者生圖**，到了再接 | `docs/bg-layer-prompts.md` |

驗證（2026-10-28）：Track A 後 `test_home`、`test_progression`、`test_stages` PASSED；風格與樓層改完後 `test_progression`、`test_home`、`test_main`（改了三處 1-1→第1層的字串）、`test_march`、`test_report`、`test_skills` PASSED；`--import` 無錯；`capture_home.gd`（六頁＋英雄詳情）與 `capture_shots.gd`（推王）重拍逐張看過。`test_stages` 在樓層改名前跑過（之後只改標籤字串）；`test_recruit`、`test_balance` 這輪沒跑。依 L3，作者手動驗收後再跑完整測試。

注意：
- 機器人平衡（`test_stages`）的一鍵養成碰不到新節點（它們要英雄等級，機器人不行軍），所以關卡曲線沒變；真人點了新節點會比曲線強，打得比推薦戰力輕鬆。
- 名冊與天賦星圖在 ScrollContainer 裡、格子是按鈕：桌面滾輪可捲，手機上拖曳捲動還沒實機確認。
- 作者的 Godot 編輯器開著這個專案：`header.tscn`、`navigation.tscn`、`home.tscn`、`heroes.tscn`、`train.tscn` 與多個元件 scene 被工具改過，回來先在編輯器重新載入，不要存舊版。
- 新工具 `build_hero_detail.gd`、`build_nav5.gd`、`build_talent_tree.gd` 都已套用，重跑會跳過。

## 第二輪回饋（2026-10-27 下午，已併入 `21604e3`）

作者說「畫面太小看不清楚」「挑戰王的 UI 風格要對齊放置畫面」「訓練換成點亮天賦」「要能幫所有英雄裝備、要有一鍵裝備」「總覽放在設定鈕左邊」。

| 項目 | 狀態 | 檔案 |
|---|---|---|
| 天賦星圖：9 個節點（劍術、拾光、耐力／速度、結伴、休息／遠程、近戰、輔助專精），連線依 `need` 自動畫，點節點看詳情、按「點亮」 | 完成 | `domain/talents.gd`、`scenes/components/talent_node.tscn`、`scripts/talent_links.gd`、`scripts/pages/train_page.gd` |
| 團專精：每級該團攻擊與生命 ×1.02，最多 10 級，起價 10 萬、每級 ×1.7（第一版 ×1.05 讓第三地區戰力爆衝，`test_stages` 不過，已調弱） | 完成，`test_stages` 通過 | `domain/talents.gd`、`progression.gd base_power` |
| 裝備頁：飾品持有者 ◀ ▶ 切換全部 100 名（行軍中在前）、「一鍵裝備」；英雄頁「裝備」鈕跳到該英雄 | 完成 | `scripts/pages/equipment_page.gd`、`heroes_page.gd`、`home.gd` |
| 頂欄：金幣／招募券框左移，設定鈕左邊「總覽」鈕（頭像仍可回總覽） | 完成 | `scenes/components/header.tscn` |
| 字級：七頁與元件的小字 ×1.3（≤24）／×1.15（≤32），單行字超出顯示「…」；頁面預設字 30；總覽待辦最多 3 列 | 完成，需作者確認夠不夠大 | `tools/build_fusion_ui_v2.gd` |
| 細長螢幕：頁面與導覽列貼底，上方補天空色 `SkyFill`；預覽視窗 430×932 | 完成，還沒重拍截圖 | `scripts/home.gd _fit`、`project.godot` |
| 推王風格：`ui/theme.tres` 改紙色面板、藍色一般鈕、金色主要鈕、Noto Sans CJK、紅血條／金士氣；HUD、結算、戰報、設定的淺色字改墨色（提示條與王血條數字保留白字） | 完成，截圖看過 | `tools/theme_taskbar.gd`（可重跑）、`scenes/hud.tscn` 等 |
| 刪除 `art_src` 95 個殘留 `.import` | 完成 | — |

已知限制：主畫面仍照螢幕寬度縮放（941 寬的版面），細長手機多出來的高度只拿來放天空，字的實際大小靠字級放大；若作者還覺得小，下一步是減少每列格數或重排版面。原本 `training_row.tscn` 已不用，留在 components 沒刪。

## 等作者決定的事

0. **第三輪的驗收**：平面白整套（六頁、英雄詳情、推王）、樓層與樓層王、天賦 18 節點的門檻（「等級」目前＝英雄最高等級）。背景圖層等作者用 `docs/bg-layer-prompts.md` 生好。
1. **試玩手感**：前 15 分鐘的節奏（新玩家先打 1-1 拿約 2.3 萬金，第一個天賦 3000 金）、行軍戰場的可讀性、六頁的資訊量。
2. **怪獸與夢靈的正式美術**：現在是 Skybound 三套怪物動作圖換色（怪獸＝野豬／魔狼，夢靈＝史萊姆），立繪也是同一批圖。要列生圖清單給作者選（直接生或給 opt image 提示詞）。
3. **英雄外觀與人類職業圖**：推王裡的人類仍是 6 種職業身體換色；紙娃娃模組（ROADMAP M2）還沒做。
4. **價格與數字**：商店價格、招募機率、保底、金幣經濟（已放大 10 倍）都是暫定。
5. **合併方式**：`fusion-idle` 要不要合回 `hero-horde-squads` 或 master，由作者決定。

## 回來時要先處理

- **作者的存檔已轉成 v2**：2026-10-27 試跑時遊戲讀到 `~/Library/Application Support/Godot/app_userdata/hero-horde-idle/progress.json`（macOS 的 user:// 不看 `XDG_DATA_HOME`），把 v1 存檔轉成 v2 並補了 8 小時離線收益。原始 v1 沒有備份（atomic_file 不留 .bak；APFS 本機快照只有系統更新快照，Time Machine 若有備份可能還在）；轉換後的快照在 `~/.claude/backups/20261027-hero-horde-idle-progress-v2-migrated.json`。舊分支 `hero-horde-squads` 的遊戲讀不懂 v2，會當成新玩家並覆蓋它，不要在舊分支用同一個存檔玩。試玩請用 `-- --save=<名稱>`。
- **合併時沒帶進來的 master 修改**：master 上 `1b119d0`（推王戰報）、`0a65639` 是建在舊的六區架構上，合併採用融合版；其中兩個點子融合版沒有：推王的固定步進 `advance()`（每幀最多 0.25 秒，切背景回來不快轉）與戰報的「救回的血量」統計。要的話再移植。
- **Git LFS 警告**：合併時 git-lfs 提示 84 個 `art_src` 檔「應該是指標卻不是」（分支直接存成一般檔案，master 的 LFS 規則要求指標），沒有轉換。
- **兩款原型保留不動**：`prototypes/taskbar-hero`、`prototypes/dreamling-idle`（在 master）當參考；這裡的頁面、元件、atlas、字型是從 taskbar-hero 複製來的。
- 其他原型的 `addons/proto_kit/` 副本和 kit 不一致，只對這款跑 `sync.sh`。
- **字型**：主畫面用完整的 Noto Sans CJK TC（`fonts/`，兩個約 33 MB），推王的子集字型（`ui/fonts/`）缺「珂菇隼鷲」，已在匯入設定加上 Noto Sans CJK 當 fallback。上架前要切子集（godot-kit `subset_font.py`）縮包體。
- **離線收益**：開啟時、App 從背景回來、打完推王回首頁都會結算離開的時間；不到 10 分鐘只寫進戰鬥紀錄，超過才彈離線戰報。

## 要成為商業級遊戲還缺什麼

依「上架前一定要有」排在前面。

### A. 上架前一定要有

| 項目 | 現況 | 要做的 |
|---|---|---|
| 手機實機 | 從沒匯出過 Android／iOS，沒有 `export_presets.cfg` | 匯出、量發熱後的持續 fps、冷啟動時間、記憶體；決定畫質預設（ROADMAP M5） |
| 金流與廣告 | 測試商店（`godot-kit store_front.gd`，畫面已經只透過它） | 選 Godot 4.7 能用的 IAP 與廣告外掛，覆寫 `_charge`／`_restore_ids`／`_play_ad`／`is_test`；消耗型商品的收據驗證（最好有伺服器）；iOS 的 ATT 與廣告同意（GDPR／CMP） |
| 存檔 | 只存在本機（`user://progress.json`，`SAVE_VERSION` 1，新欄位用預設值讀） | 雲端存檔或帳號綁定（換手機、付費玩家必要）；正式的存檔版本遷移；防竄改（至少檢查值的範圍） |
| 每個地區自己的王與舞台 | 3 個地區都是同一隻巨魔換色、同一個舞台換色調 | 每個地區一隻關卡王（4 格姿勢＋3 種預警攻擊）與一套舞台美術（ROADMAP M6） |
| 英雄外觀 | 100 名英雄是 6 種職業身體換色 | 做紙娃娃模組（godot-kit 新增 `paperdoll`，還沒開始；48 px 格，髮型／服裝／武器部件；ROADMAP M2）；部位被打壞的專屬圖 |
| 音效與音樂 | 全部是程式合成的佔位音，沒有背景音樂 | 正式音效（放同名 `.ogg` 到 `assets/sfx/` 就會換掉）、各畫面的背景音樂（godot-kit `music.gd`） |
| 法務與商店頁 | 只有遊戲內的機率說明 | 隱私權政策、分級問卷、商店截圖與宣傳影片、抽卡機率公開（遊戲內已有機率說明頁；台灣、韓國有法規，日本有業界自律規範，上架前確認各地最新要求） |
| 在地化 | 只有繁體中文，字串寫在程式與 scene 裡 | 抽出字串（`tr()`＋翻譯表），英文、日文；字型子集要含各語言（godot-kit `subset_font.py`） |

### B. 留住玩家（上架後很快就需要）

- **沒有每日循環**：沒有每日任務、簽到、成就、週期活動。現在每天回來的理由只有離線收益和每天一次看廣告免費單抽。
- **內容量**：只有 10 關。打完之後沒有重複可玩的內容（無盡塔、每日王、活動王）。
- **新手引導**：只有第一場的一則操作提示；養成、招募、道具沒有引導。
- **養成**：訓練取代了職業等級（作者的存檔顯示沒發現職業等級這層），等作者試玩確認看不看得懂。
- **抽卡演出**：結果直接列出來，沒有開卡動畫。
- **SSR 技能特寫**：招牌技只有招牌技卡與頭上名字，沒有短運鏡特寫（ROADMAP M3）。
- **平衡**：曲線是機器人量的；真人只有作者玩過開頭幾關（1-1 打不過才有 v2.5 的前四關打折）。

### C. 營運與工程

- **數據**：沒有遙測、當機回報、遠端設定。上架後調數值、看留存都需要。
- **效能**：桌面上沒問題，手機沒量過。推王畫面離開時有一筆粒子 shader 洩漏警告（`ParticlesShaderRD never freed`，v2.5 之前就有，不影響遊玩）。
- **介面細節**：主畫面用遠征紀事參考圖切出的 atlas（941×1672 原尺寸，nearest），在非整數倍的手機上像素寬度會不一；推王結算面板的圖示還是 hero-horde 舊的設計稿裁圖；`main.tscn` 在編輯器裡的預覽還是舊的稀有度描邊色。
- **無障礙**：預警已有斜紋（色弱分得出），還沒有字級選項。

## 怎麼接著做

```bash
GB=/Applications/Godot.app/Contents/MacOS/Godot
cd prototypes/hero-horde-idle
$GB --path . -- --save=trial                    # 試玩（不碰正式存檔）
for t in march progression home recruit report skills main balance stages; do   # 完整測試（依序，不要同時跑）
  timeout 900 $GB --headless --path . --script res://tests/test_$t.gd 2>&1 | grep -E 'PASSED|FAILED|SCRIPT ERROR'
done
$GB --path . --resolution 470x836 --script res://tools/capture_home.gd -- <輸出資料夾>   # 主畫面七頁截圖
$GB --path . --resolution 390x844 --script res://tools/capture_shots.gd -- <輸出資料夾>  # 推王截圖
```

- 分層驗收：改單一系統跑該系統的測試；動到行軍、養成、推王之間的交互，加跑 `test_home` 與 `test_main`；完整測試等作者手動驗收後再跑（`test_stages` 約 80 秒）。
- scene 以存檔為準：`tools/build_fusion_ui.gd` 已套用，頁面掛上腳本後重跑會跳過；要重做某頁，先看 diff 再刪檔重跑。
- 生圖一律先列出批次內容給作者選。
