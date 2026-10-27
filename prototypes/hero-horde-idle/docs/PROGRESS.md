# 全員推王：進度與商業化缺口（2026-10-27 融合版交接）

回來時先讀這份，再看 [FUSION.md](FUSION.md)（融合的決定與系統）、[ROADMAP.md](ROADMAP.md)（里程碑）與 [../README.md](../README.md)（規格、可編輯的 scene、執行方式）。

## 現在在哪裡

v3.0 融合版（分支 `fusion-idle`，從 `hero-horde-squads` 開出；worktree 在 `~/repo/godot/godogen-fusion`）。全員推王為主幹，併入遠征紀事的七頁介面與裝備撿寶、夢靈遠行的小隊編成與羈絆。

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

## 等作者決定的事

1. **試玩手感**：前 15 分鐘的節奏（新玩家先打 1-1 拿約 2.3 萬金，第一個訓練 3000 金）、行軍戰場的可讀性、七頁的資訊量。
2. **怪獸與夢靈的正式美術**：現在是 Skybound 三套怪物動作圖換色（怪獸＝野豬／魔狼，夢靈＝史萊姆），立繪也是同一批圖。要列生圖清單給作者選（直接生或給 opt image 提示詞）。
3. **英雄外觀與人類職業圖**：推王裡的人類仍是 6 種職業身體換色；紙娃娃模組（ROADMAP M2）還沒做。
4. **價格與數字**：商店價格、招募機率、保底、金幣經濟（已放大 10 倍）都是暫定。
5. **合併方式**：`fusion-idle` 要不要合回 `hero-horde-squads` 或 master，由作者決定。

## 回來時要先處理

- **作者的存檔已轉成 v2**：2026-10-27 試跑時遊戲讀到 `~/Library/Application Support/Godot/app_userdata/hero-horde-idle/progress.json`（macOS 的 user:// 不看 `XDG_DATA_HOME`），把 v1 存檔轉成 v2 並補了 8 小時離線收益。原始 v1 沒有備份（atomic_file 不留 .bak；APFS 本機快照只有系統更新快照，Time Machine 若有備份可能還在）；轉換後的快照在 `~/.claude/backups/20261027-hero-horde-idle-progress-v2-migrated.json`。舊分支 `hero-horde-squads` 的遊戲讀不懂 v2，會當成新玩家並覆蓋它，不要在舊分支用同一個存檔玩。試玩請用 `-- --save=<名稱>`。
- **工作區未提交**：融合版的修改都還沒 commit（作者沒有授權 commit）。
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
