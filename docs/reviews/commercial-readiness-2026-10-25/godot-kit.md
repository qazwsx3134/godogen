# godot-kit 評論

## 判斷

**值得繼續維護，但應把它定位成「可靠的小工具箱」，不要在尚無實際採用案例時變成通用遊戲框架。** 對玩家的價值，是存檔不失去、操作一致、畫面穩定；玩家不會因為用了很多模組就認為遊戲更好。

本輪讀取 README、同步腳本、測試 runner、atomic_file、time_control、新增三個規則模組及 UI Theme 管線；跑 `genre_modules` 和 `proto_kit`。沒有逐個 shader 做 GPU profiler。

## 優點

| 優點 | 實際價值 | 應保留的設計 |
|---|---|---|
| 多數是小型 preload 模組，規則可不碰 scene tree | 遊戲能獨立演進、測試容易 | 不把跨遊戲進度放進全域 autoload |
| AtomicFile 提供暫存、回讀與 rename | 比直接覆寫主檔可靠 | 儲存機制與各遊戲 schema 分開 |
| SceneBuilder 驗證 owner、pack 後節點數與相依 scene | 編輯器內容可成為真正來源檔 | 一次性產生器，預設跳過現有檔案 |
| sprite3d／MultiMesh 支援大量角色 | 全員推王能把百人做成可負擔的呈現 | 模擬與 sprite 外觀獨立 |
| 有嚴格檢查 SCRIPT ERROR 的 runner | 防止 Godot exit 0 掩蓋腳本失敗 | 保留 stdout/stderr 證據，而非只看退出碼 |
| 三個 UI Theme 已共用 `.tres` | 在編輯器修改可影響多個版型 | root theme 引用外部資源，不回到每 scene 一份 |

## 程式與工程改善

### K-01／P1：import 失敗仍能顯示 PASS【重現確認】

位置：`prototypes/godot-kit/tools/run_tests.sh:21`（import）及 `:40` 起（判定 suite）。

import 指令沒有 timeout，也沒有檢查 exit code／import log；後續 suite 成功會把整體結果蓋過。用測試替身令 editor import 返回 17，而 suite 印 PASSED、返回 0，runner 仍回 `PASS genre_modules` 和 exit 0。這是 runner 的控制流程重現，不是在宣稱目前各遊戲 import 都壞了。

**改善**：import 和 suite 都成為獨立 gate；import 加 timeout、驗 exit、掃錯誤，失敗時保留 log 並停止後續驗收。完成標準：同一替身得到非零退出碼，正常 import/suite 仍可通過。

### K-02／P2：意外 engine ERROR 被通過訊息遮住【重現確認】

位置：`tools/run_tests.sh:40`；`addons/proto_kit/sprite_inspector.gd:167`；`tests/test_proto_kit.gd:1156`。

本輪 `proto_kit` 最後出現 `Index p_idx = 0 is out of bounds (items.size() = 0)`，來源是空 ItemList 的 select，仍印 `PROTO KIT TESTS PASSED`。同份測試也包含故意製造的壞資源、錯 owner 等負例，因此不能粗暴把所有 `ERROR:` 當失敗。

**改善**：先修空清單選取；讓負例按案例登記預期錯誤及數量，runner 對未預期的 engine ERROR 失敗。不要用「exit 0 就沒問題」或全域忽略 ERROR 來處理。

### K-03／P2：同步模型與模組成熟度沒有明確版本契約【程式確認】

位置：`sync.sh:36` 起；README 的收錄標準與「尚未採用」模組列。

`rsync --delete` 會整包替換副本。README 說至少兩個原型實用才收錄，但 card_draft／upgrade_tree／run_goals／UI 目前均尚未採用，另外多項僅有一個採用者。這不使模組無效，卻讓「已穩定」與「可試用」混在一起。

本輪逐檔比較：三款已存在的副本與 kit 同路徑檔案沒有內容差異；缺少的新檔案分別為 debt 44、skybound 16、hero 21（不計 `.uid`、`.import`）。**這是採用範圍差異，不是證明有人私改副本。** 不應為了通過全目錄 diff 就強迫全部遊戲帶進用不到的 UI。

**改善**：新增 stable／experimental 狀態、模組版本與依賴清單；同步前輸出變更計畫，允許按模組同步相依集合；把使用端本地定制放在 `addons/proto_kit/` 之外。完成標準：能說出某原型採用哪些版本，以及更新將影響哪些場景與測試。

### K-04／P2：atomic 寫入不等於整個存檔交易可靠【程式確認，未做斷電注入】

位置：`atomic_file.gd:63`。

不允許直接覆寫的平台會先把主檔改名 `.old` 再搬 `.tmp`。兩個 rename 中間中斷，可能暫時只有 `.old`／`.tmp`，不是主路徑永遠存在；多個檔案（死亡墓碑＋Profile）也不會自動變成同一筆交易。debt loader 已嘗試 `.bak.old/.old/.tmp`；skybound loader 僅試主檔與 `.bak`。

**改善**：文件精確界定「單檔提交」與「恢復候選」；提供故障注入 seam，覆蓋各 rename 失敗點、目錄不可寫、備份失敗。跨檔交易仍由遊戲 SaveService 管，避免 kit 知道遊戲的死亡規則。

### K-05／P2：新規則模組需要資料驗證及版本化【程式確認】

位置：`card_draft.gd:17`、`upgrade_tree.gd:_init`、`run_goals.gd:_init/from_dict`。

目前預設呼叫端給有效內容；重複 id 會覆蓋，未知 requires／互鎖前置條件可造成永不出牌，錯型別與非有限權重也沒有統一診斷。這是投入內容製作後的風險，不是聲稱目前合法測試資料失敗。

**改善**：加離線內容 validator，檢查唯一 id、引用、範圍、有限數值、可達性；存檔附 schema／內容版本並回報無法遷移的原因。把錯誤放在作者建置時看見，避免玩家才遇到空選單。保留呼叫端注入 RNG；說明 `from_dict` 會改寫 RNG state，且讀回需用同一組內容及 slots 設定。

### K-06／P2：Theme 的「可在桌面看見」還不是跨平台外觀保證【程式確認】

位置：`ui/ui_theme.gd:10`、`:35`；`tools/make_ui_layouts.gd:ensure_themes`。

SystemFont、JSON 與已保存 `.tres` 是三個不同部署面：系統字型依環境而異；JSON 需進 export；`.tres` 預設不覆寫，修改 JSON 不會自動更新既有 Theme，手改 `.tres` 也不會回寫 JSON。

**改善**：明確指定 token 或編輯器 `.tres` 哪個是權威來源；提供「比對／明確更新」工具及本地覆寫層；字型由採用專案提供固定資源；對 Web 匯出做字形、focus、長字串、縮放和顏色狀態驗證。八個版型定位為起點，不能承諾已具備完整鍵盤／無障礙互動。

### K-07／P3：time_control 的全域時鐘所有權須明示【程式確認，非目前故障】

`time_control.gd:hit_stop/_process/_exit_tree` 直接設定並恢復 `Engine.time_scale = 1`。對只用一個實例的原型很簡單；若未來同時有慢動作、二倍速或第二個 TimeControl，會互相覆寫。

**改善**：先在契約限制同時一個 owner；真的出現第二個使用需求再做效果疊加／基準倍率，不提前建立複雜框架。

## 建議的採用邊界

```text
godot-kit               遊戲自己的 domain             遊戲 scene／內容
單檔寫入、輸入、渲染 →  存檔規則、戰鬥、敘事、經濟  →  呈現與編排
                        ↑ 共同機制經兩個實例驗證後再抽取
```

先改善測試與同步契約，暫緩擴增大型通用戰鬥框架。不要把三款的不同節奏和美術全部換成同一套 UI。
