# Godot 手機版架構草案

2026-10-26；狀態：**Proposed**。基線 Godot 4.7、現有 Compatibility、先沿用 2.5D 角色。這是系統規劃用的技術邊界，尚未有完整 GDD／ADR 審核，也不表示以下類別或路徑都已存在。

## 層次與責任

```text
輸入／UI／Actor／VFX／Audio（只表達意圖與演出）
                       ↓ command
Application：角色操作、任務提交、精煉等 use case
                       ↓
Domain：戰鬥／屬性／成長／物品交易／規則與狀態
                       ↓ repository／clock／rng interface
Infrastructure：本機保存／內容載入／未來 transport／DB
```

初期同一 Godot project 中完成，不要求拆出獨立套件或微服務。模組邊界先解決狀態所有權與測試，不能讓框架工程壓過可玩驗證。

| 責任 | 唯一擁有者 | 可讀者 | 不允許的捷徑 |
|---|---|---|---|
| Definition／內容 ID | S01 ContentCatalog | 各 domain／view resolver | UI／角色直接改共用 Resource |
| clock／命令序號／權威 adapter | S02 | domain、network coordinator | 玩法各用自己的牆鐘解同一事件 |
| 路徑、速度與目標 | S06 Movement/Target | Combat、AI、ActorView | Actor 動畫反向移動權威角色 |
| HP/AP／modifier | S07 | Combat／HUD／AI | UI 直接扣血；換裝各處重複加屬性 |
| 攻擊接觸與傷害結果 | S08 | AI、獎勵、回饋 | timer 和動畫 callback 各算一擊 |
| 物品／貨幣／容器 revision | S12 | 裝備、商店、任務、寵物、精煉 | 各窗口自行扣料／發獎 |
| 裝備欄與外觀解析 | S13 | StatService、ActorView | 紙娃娃從 sprite 反推裝備數值 |
| 保存 envelope 與耐久提交 | S25 repository | lifecycle／application | 只在退出儲存，或檔案寫入失敗仍報成功 |
| 多人 session／DB／AOI | S28（啟用後） | client adapters／社交 | 客戶端自行宣稱最終傷害、價格或稀有結果 |

## Scene 與程式組織提案

```text
scenes/main.tscn
├─ WorldRoot
│  ├─ Zone（保存的地形、導航、道具、入口與出生點）
│  ├─ Player（移動／碰撞、ActorView、必要標記）
│  ├─ Monsters（重複 .tscn instance）
│  └─ Drops／Effects（重複 .tscn instance）
├─ CameraRig（固定方向／俯角、跟隨）
├─ AudioRoot
└─ CanvasLayer
   └─ HUD（狀態、技能、目標、窗口 shell）
```

建議新 domain 檔案放 `scripts/domain/<system>/`；應用協調放 `scripts/application/`；視覺／UI 行為掛 scene；具體內容放 `resources/definitions/`。現有 scripts 不為符合目錄而全移檔，實際遷移由每份 TDD 明列。

根 node 掛行為腳本，以 `%唯一名稱`、export 與 signal 取得／連接子物件。重複物件透過 PackedScene instantiate；主要 scene 未執行即可看見代表性 layout。靜態 Theme、色彩、字體、文字與間距在 scene/resource。

新建／大改 scene 用 Godot pack/save 工具保存，驗 owner、子 scene instance 與重載 node 數。產生器只作製作工具；開編輯器、執行、匯入與測試都不能自動重建來源 scene。原 prototype kit 副本不可直接改，需要時在 kit 來源改並只同步指定專案。

## 主要流程與契約

### 點怪追打與傷害

```text
Touch → InputIntent → SelectTargetCommand → Target／Chase
                                               ↓ 到射程
                                      StartAttack／AttackInstance
                                               ↓ contact time
                                         CombatService
                                               ↓ CombatEvent
                          HP／死亡／掉落／EXP＋Actor／SFX／VFX
```

接觸時驗目標 entity、區域、存活、射程與攻擊 token。命中結果只產生一次，動畫可使用同 token 對齊。移動取消／死亡／切區須使舊 callback 失效。動畫、物理與 domain clock 不可因渲染 FPS 不同而改變攻擊次數。

### 物品操作與耐久性

```text
UI 請求 → Application 驗資格 → InventoryTransaction
                                    ↓ validate
                             一組物品／貨幣 delta
                                    ↓ durable commit
                         新 revision＋結果事件 → UI／保存
```

本機先以單一 snapshot 提交多容器變更，寫入失敗時依規格保留舊 durable state 或提示待保存，不得假裝已耐久成功。多人則使用服務端 DB transaction／等價原子策略；去重結果也必須與資產變更保持一致。僅在記憶體去重不保證重啟後不複製物品。

命令共通欄位建議：request_id、actor_id、type、payload、expected_revision；回傳 result_code、new_revision、events／state_delta。網路啟用後加入 session、sequence 與版本，不接受 client 自報最終價格／傷害／結果。每個命令要定重送有效範圍與保存期限，不能無界保留所有 request。

### 保存與背景

各系統提供有版本的資料片段；repository 合成 SaveEnvelope。local／remote 是實作不同的 repository，不讓 UI 與 gameplay 直接判斷存本機還是 server。背景返回先清 pointer／舊回呼，單機按本作規則恢復，線上等待權威 snapshot。

重大物品操作與任務領獎觸發 checkpoint；普通移動可定期保存。原子檔案／備份只能處理資料完整性，不能在不可信 client 上保障多人資產。

## 目前原型的漸進遷移

| 現有位置／能力 | 下一個切片 | 保留 | 移出／新增 |
|---|---|---|---|
| `scripts/camera_rig.gd` | M0 固定相機 | 固定俯角／distance 與跟隨 | 取消使用者旋轉；構圖／遮擋契約 |
| `scripts/main.gd` | M0/M1 input routing | 組裝主場景 | 多指與 UI 優先權不散在主迴圈 |
| `scripts/terrain_height.gd`、meadow | M0 導航灰盒 | 地形與可編輯 props | 碰撞／導航與高度一致；不可達策略 |
| `scripts/player.gd` | M1 追擊／普攻 | 角色 scene 與可玩基線 | 屬性、EXP、傷害與保存逐段移到 domain |
| `scripts/monster.gd` | M1 怪物 FSM | 場景 export 參數／出生點 | 一致攻擊服務、leash 與死亡事件 |
| `scripts/actor.gd` | M0/M1 視覺接口 | sheet、腳底、圖層、名牌 | 播演出不直接決定傷害／成長 |
| `ui/hud.tscn`、hud script | M0/M2 手機窗口 | 可編輯 Theme／狀態呈現 | modal、safe area、view models、重複 slot scene |
| kit `pet_care/refine_ladder` | M3 | 純邏輯與測試參考 | 套本作已定規則；不沿用未知原作試調值 |

不接入 kit combo_input；無連招規格、同步或 UI。固定相機不減少角色必要方向；材質與動畫預算用真機測量決定。

## 提議需要的 ADR

| ADR 題目（尚未建立） | 時點 | 必須比較的選項 |
|---|---|---|
| 手機平台與 renderer | M0 | 原生／Web，Compatibility 與需求支援；以 Godot 4.7 為基線 |
| 權威、命令與時間邊界 | M0 | 本地同步執行、替換 adapter；快取與重送／取消 |
| 保存與物品原子變更 | M0 | envelope、revision、備份／恢復、提交成功語意 |
| 角色呈現與換裝管線 | M2 前 | 現有 2.5D 分層、完整 3D；工時／記憶體／遮擋比較 |
| 多人 transport 與服務拓樸 | M2 試驗／M4 | 平台可用能力、AOI、DB、可支持負載；避免提前微服務化 |
| 交易鎖與持久化去重 | M4 | 原子提交、session revision、崩潰恢復與稽核 |

實作前依當期工具與官方文件查核未驗證 API、套件與平台限制；此草案沒有新增第三方套件或 pin 全 source repo 引擎。資料 schema、平台、商城等未決選擇在[決策清單](../../design/planning/decision-register.md)追蹤。
