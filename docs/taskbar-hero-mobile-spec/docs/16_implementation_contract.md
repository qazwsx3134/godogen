# 16 — 實作契約與首個可玩檢查點

2026-09-27 規格 review 後的實作基準。本文裁定早期文件尚未確定的細節；內容規模仍以 11 為 MVP 目標，完成狀態只看 DEV_STATUS 與實際驗證。

## 交付分段

| 檢查點 | 可玩的內容 | 本階段驗收 |
|---|---|---|
| A：Foundation + Combat Slice | 一名 Knight 對 Slime、自動接近／攻擊、HP／死亡／重生、金幣、直式常駐戰鬥區、基本存檔 | scene 可編輯；兩種手機比例；10 分鐘模擬戰鬥；存檔損壞回復 |
| B：Party + Stage | 三人隊伍、EXP、資料驅動波次、1-1～1-5 解鎖／失敗／農關 | 三名角色同場、死亡不可被選中、全滅退回已解鎖農關 |
| C：Loot + Equipment | 寶箱、六欄裝備、比較、穿裝與戰力變化 | 掉落 → 開箱 → 穿裝 → 戰鬥結果改變；UID 與裝備引用可存讀 |
| D：Offline + Economy | 離線領取、分解／合成／製作、符文 | 重開不可重複領；資源守恆；已鎖與已穿裝備受保護 |
| E：MVP content + Mobile | 15 關、2 Boss、30 基底裝備、25 符文與平台驗證 | 完成 13 的所有條件；另記 Android／iOS 實機證據 |

本次開始實作 A。它是可玩的系統骨架，不代表已完成離線 Idle 循環或 MVP。A 的金幣以擊殺累積；尚未有消耗用途，不能拿來宣稱經濟循環成立。美術先用可替換的幾何佔位物件。

## 可維護的 Godot 場景

專案：`prototypes/taskbar-hero/project.godot`。使用 GDScript、Compatibility renderer，預覽視窗 390 × 844，最小邏輯畫布 320 × 568，兩者都驗證；1080 × 1920 可作美術輸出尺寸，不作按鈕的邏輯單位。

場景責任：

- Main：Safe Area／Margin／VBox 組合主頁、可捲動內容、常駐戰鬥區及操作列。
- AdventureStrip：戰況文字與 2D 戰場；切頁不銷毀戰鬥狀態。
- Unit：視覺、HP 顯示及行為腳本；靜態 UnitData 與當前 HP／目標／冷卻分離。
- Screen／Item scene：重複元件可獨立打開編輯，不在主畫面腳本畫整頁。

靜態節點隨 scene 儲存、動態實例由資料決定。戰場內代表性 Hero／Enemy 保留為 scene instance，方便編輯器預覽。UI 版面不用 `_process()` 改寫尺寸；戰鬥角色可正常移動。字體、Theme 與色彩資源跟隨專案，避免依賴作業系統字型造成匯出缺字。

一次性 scene 產生器不參與一般啟動／測試／匯入。重跑會影響手動編輯，必須明確執行並檢查 diff。檢查 pack 前後節點數與子 scene 引用，不能以執行時看起來正常取代可編輯性驗收。

## 共用模組與依賴

沿用 repo 的 `prototypes/godot-kit`：

| 模組 | 使用方式 | 責任邊界 |
|---|---|---|
| `atomic_file.gd` | SaveManager 呼叫原子寫入 | 遊戲自己驗證 schema、維護 backup 與回復策略 |
| `test_kit.gd` | headless 測試基底 | 測試真實 scene、signal 與 UI 輸入 |
| `synth.gd` | 日後有音效需求時引用 | 目前沒有音效也不影響 A 驗收 |

使用 `sync.sh taskbar-hero` 同步，不能修改專案中的副本。首個檢查點不需要下載 Asset Library／商店套件。日後依實際功能缺口選套件，README 記錄版本、授權、來源、平台限制；需要付費資源時先提供明確選項。

## 自動戰鬥與失敗

- 初始普攻遵循 06 的防禦公式；attack_speed 下限 0.1，defense 下限 0；冷卻與移動使用 delta，不以畫面 FPS 決定傷害。
- 只選仍存活、同一戰場的敵方單位；最近距離相同時以穩定 spawn 序決定，測試可重現。
- 攻擊前重新驗證距離與目標，死亡只結算一次。冷卻重設於攻擊事件，不能每一幀重設。
- A 階段死亡後短暫等待，重生下一次對戰；Gold 只因敵方死亡增加，英雄死亡不加獎勵。
- B 起戰鬥失敗退回最近已通關可農關。第一關失敗則重新挑戰第一關；不扣永久資源。復活間隔算入農關速度。
- 正式 Boss 位於 1-10（Iron Guardian）與 1-15（Grave Summoner）；1-5 是成長里程碑。前期可用測試資料驗證 Boss，但不把測試 fixture 宣稱為正式內容。
- 正式技能導入時分 physical／magic damage；magic 用 magic_resistance 套相同減傷公式。鐵衛的低魔防才有實際配裝意義。

## 離線結算（D 階段契約，A 不實作）

MVP 離線只農「已通關且有有效速度樣本的關卡」，不解鎖關卡、不擊敗新 Boss。Boss 首殺與推關留給線上。報告只顯示實際算出的農關收益，不宣稱角色闖到尚未模擬的關卡。

農關快照保存 stage_id、版本、每秒 EXP／Gold／Material／Chest 產出、有效觀測時間與時間戳。速率取最近 120 秒內的完整清波樣本，至少 3 次清波且 60 秒有效觀測；分母包含波間等待和復活。暫停及背景時間不納入。換裝／隊伍／關卡／符文後舊樣本失效；新樣本不足時先不發離線收益，UI 說明「完成農關記錄後開啟離線收益」，不可猜測 kill rate。通關及版本資料更新需重新驗證快照。

```
seconds = clamp(now - settled_at, 0, capacity_seconds)
reward[type] = floor(snapshot.rate[type] * seconds * efficiency[type])
```

EXP／Gold 效率 0.8，Material／Chest 0.7；容量初始 12h，符文合計增加 2h + 2h + 4h + 4h，上限 24h。離線回報與領取流程：

1. 載入合法存檔，先顯示已存在的 pending report。
2. 新期間只建立一次 report，持久化 `report_id`、`from`、`to`、seed、固定 reward 與新的 `settled_at`，寫入成功才展示；pending 存在時保留後續期間，領完再結算。
3. Collect 把收益、claim 狀態、report 移除寫入同一份原子快照；寫失敗時維持待領狀態，不先發獎。重開讀到的是領前或領後的完整狀態。
4. 非負時間差與 cap 防止倒退和超長收益；沒有有效快照則只前移結算點，不發收益。

運算以數量累加及固定上限批次抽樣完成，不逐幀、不為每隻假想怪建立物件。Report seed 與 chest 開啟序號持久化，重開不重抽。pending report 展示期間暫停線上收益；領取成功後再啟動線上計時，避免同一時間區間重算。

## 裝備與經濟（C／D 階段契約）

- inventory 初始上限 200 件，包含已裝備的實例；裝備欄只引用 UID。每件物品至多被一個 Hero 的一個欄位引用。
- Chest 存為數量與可重現生成序號。滿包時不能再開箱，寶箱留存，不靜默丟棄物品；批次開箱最多開到剩餘空位。
- Locked 或 Equipped 物品不得進入分解、批量分解、自動分解或合成；換装原子地解除舊引用並指向新物品。
- 自動分解預設關閉；符文解鎖後玩家可選 Common／Rare，預覽與確認後套用。保留前期比較／穿裝的機會。
- Merge 明確選擇 5 件相同 rarity、未鎖定、未穿裝的不同 UID；Mythic 不可再升階。成功一次消耗五件、產出一件，失敗不得部分扣除；產物等級為素材最低等級、隨機 base，seed 持久化。
- Salvage 每件得到 Dust 與等量 Craft Progress：Common 1、Rare 3、Epic 10、Legendary 30、Mythic 100。
- Craft 消耗 100 Dust 與 100 Progress，產出指定 slot 的 Rare 裝備，等級依最高已通關關卡。這保證指定部位和品質，不保證比當前裝備更強；UI 不應稱作「必定升級」。
- 所有修改先驗證完整輸入與資源，再一次提交；排序、篩選不得改動物品身份。Affix 池只納入已有運算與測試的效果。
- Rune prerequisites 使用全數成立（AND），成本與效果在 Resource；解鎖一次扣款一次、重載不得重複套加。

## 存檔與驗證

Schema 有 version；所有讀檔先驗證型別、有限數值、非負值與範圍。已知舊版按明確遷移函式處理；未知新版停止覆寫並顯示原因，不當作新遊戲默默重置。主檔損壞嘗試合法 backup，兩者損壞時保留損壞檔並提示重建。

只備份已驗證的舊主檔，避免壞檔蓋掉可恢復副本。寫入錯誤向 UI 回報。每 60 秒、手動存檔、背景／退出觸發保存；後續所有裝備、消耗與領取交易亦需保存。

自動測試使用獨立 `user://` 目錄。至少涵蓋：戰鬥時序與死亡一次性、10 分鐘模擬不累積單位、合法與損壞存讀、future schema、不帶快取的匯入、兩種比例的真實 scene 與按鈕操作、人工 scene 編輯保留。Headless 通過不等於 Android／iOS 實機、60 FPS 或電量驗收。
