# Godot 累積能力盤點（2026-11-06）

盤點對象為此 checkout `prototypes/` 中有頂層 `project.godot` 的 16 款遊戲，以及 godot-kit。掃描各原型來源、scene／資源引用、kit 副本 hash；列出自有 GDScript 的基底、公開方法與檔頭說明，並比較原始碼逐位元組重複。結構化證據在 `catalog/inventory.json`，可重新產生。這不是所有歷史 commit、已搬走專案或第三方套件的完整審計。

美術、聲音與模型只統計副檔名數量；不因能找到檔案就宣稱可再散布。特效素材沿用既有逐項來源與授權索引。排除 `.godot/build/art_src/node_modules` 等生成物；巢狀場景製作專案不當成獨立遊戲。

後續深入比較見 [跨原型研究](REUSE-RESEARCH.md)、[逐項研究覆蓋](RESEARCH-COVERAGE.md) 與 [介面草案](REUSE-CONTRACT-DRAFTS.md)。本頁是靜態盤點；能力數量不代表全部實作已深讀。

## 選擇抽象的判準

| 能力特性 | 選擇 | 原因 |
|---|---|---|
| 不需要 scene tree、可輸入時間與亂數 | RefCounted 規則 | 重播與測試成本低 |
| 數值、美術映射、演出曲線需要設計師調整 | Resource／資料表 | 比大量建構參數更易維護 |
| 有編輯器版面、節點生命週期、渲染資源 | 保存 scene | 保留作者可視編輯能力 |
| 只需一次轉換、建置或驗證 | CLI／製作工具 | 不進 runtime，不綁遊戲 |
| 依賴特定經濟、故事指令或戰鬥公式 | 留在遊戲／adapter | 重複程式不等於規則相同 |

## 各原型判斷

| 原型 | 值得復用的累積 | 本輪處置／邊界 |
|---|---|---|
| debt-commission | StoryRunner、DM/Parley 編譯、對話演出、調查、存檔、UI 和紙資產 | kit 音效／震動／原子檔案可直接用；故事編譯仍依賴 StoryRunner、StoryLibrary、TsukkomiRound，需以內容 adapter 拆邊界；和紙介面維持遊戲專屬 |
| dreamling-idle | domain model、固定模擬步長、行軍與戰鬥展示 | 抽 fixed_step retain 政策；game_model 的經濟與成長保持專屬 |
| erwin-run | 跑酷、流程演出、橫向手機畫面、Parallax 收尾 | 通用音訊／方向遮罩已有 kit；關卡段落與結尾視差以場景配方保留 |
| hero-horde-idle | HD-2D 舞台、鏡頭演出、gacha、march strip、長期成長 | 前四項既有 kit 能力已入契約目錄；離線收益與角色成長不強行共用 |
| horde-25d | 大軍 sprite、MultiMesh、傷害數字、攝影機 | 傷害數字抽成 scene；sprite3d 已有共用規格；跟隨鏡頭不同於固定 shot_camera |
| kagura-dango | 歌曲時鐘、節拍判定、分回合流程、方向遮罩 | song_clock 與 orientation_guard 契約化；比賽回合規則留在遊戲 |
| luffy-marineford | 存活戰鬥、傷害數字、光效池、觸控按鈕 | 抽數字；與 madara 完全相同的檔案列候選，不盲目合併已有角色／升級差異 |
| madara-survivor | 同上、sprite atlas 與技能演出 | 使用與 luffy 相同的拆分判準；保留特定技能資料與敵人規則 |
| pachinko | 盤面模擬、序列演出、壓力測試、sound synth | synth／測試基底可用；彈珠碰撞與演出機台需先分離規則，不能冒充通用 physics engine |
| pixel-monster | 步數 provider、養成 service、進化、時間與存檔 | atomic_file／test_kit 已共用；步數 provider 適合未來平台 adapter，裝置資料授權與活動規則仍由遊戲負責 |
| seal-meadow | 交易背包、道具實例 UID、寵物、點選、存檔、時鐘 | pet_care/tap_picker/save_slots/game_clock 已共用；inventory 靜態依賴 Items.ALL 與精煉規格，需資料注入後才獨立 |
| seichi-pov | 第一人稱巡覽、spot 互動、固定搖桿 | 巡覽／spot 是場景配方；與 floating_stick 的方向語義先轉換，不能直接替換 |
| skybound-blades | 固定步長、純 domain 戰鬥、sprite 品質檢查 | 抽 fixed_step drop 政策，保留插值餘額；sprite inspector/check 已共用；戰鬥數值不泛化 |
| star-tide-harbor | 釣魚、家具、景深層、螢火蟲 | 與 seal 的釣魚比較後，前者是張力玩法、後者是定時交易；保留各自玩法場景／規則，不建立通用 fishing engine |
| survivor-series | 生存類系列、地圖與素材製作、觸控操作 | 共用能力透過 kit 接入；巢狀 art_src Godot 專案屬製作來源，排除 runtime 重複統計 |
| taskbar-hero | 防禦公式、攻速換算、資料 registry、進度管理 | damage_rules 雖小但 BASE_DEFENSE=100／最低傷害=1 是平衡政策，保留遊戲端；registry 與 autoload 不直接當通用框架 |

## 抽取結果與候選決策

| 能力 | 證據／耦合 | 決策 |
|---|---|---|
| damage_numbers_3d | horde/luffy/madara 三份完全相同 | 已抽：2 個保存 scene、專屬 RNG、世界座標、可調色／容量／生命週期、固定池與清理 API |
| weighted_choice | rarity/chest_shop/run_timeline/refine_ladder 四處相同抽取流程 | 已抽且四個既有模組改用；gacha 與 card_draft 保留不同演算法；重構後測試暫緩 |
| fixed_step | skybound 丟棄過量；dreamling 保留積欠 | 已抽：明確 retain/drop，觀察 backlog/dropped；避免把兩種時間政策混成隱含行為 |
| glow_pool | luffy/madara 相同；綁 MultiMesh 20-float stride、fx_shapes shader、混色材質 | 保留候選：要連 shader/material/scene 一起抽，不能只搬腳本；GPU 行為需實機驗證 |
| gems | luffy/madara 相同；包含拾取、經驗值與遊戲宿主呼叫 | 分成顯示池與遊戲拾取 adapter 後才值得共用；目前保持遊戲實作 |
| touch_stick/touch_button | luffy/madara 相同；其他遊戲有 fixed/floating 不同模式 | kit 已有 floating_stick；先標準化螢幕向量／UI 阻擋／release，再決定固定式版本 |
| upgrades/upgrade_card | luffy/madara 相同，綁角色與升級資料 | 純選卡優先用 card_draft；卡面維持可編輯 scene；特定角色規則不搬 |
| enemy_def/enemy_jutsu/passive_def | 相同資料類型但遊戲語義專屬 | 以遊戲 Resource 保留；不建立通用 Entity 大類別 |
| inventory | seal 的 all-or-nothing 交易有價值，Items.ALL 靜態依賴、裝備精煉與 UID | 可復用的是交易邊界；新消費者需注入 item catalog／instance schema，不能悄悄丟棄未知道具 |
| story_build | 可共用格式 adapter、可達性檢查；輸出驗證綁 ADV runtime | 先獨立 graph IR/schema，再注入遊戲指令驗證；目前不聲稱整個資料夾已是獨立工具庫 |
| UI／shader 資產 | scene、Theme、uniform 可參數化 | 既有 resources.json 列入口與 uniforms；視覺資源按現有目錄分組，不用新的通用 UI runtime 重畫 |

## 遷移與相容性

新增共用能力未覆蓋原型檔案。傷害數字新介面接世界座標；舊版本 `at` 直接寫局部 position。新池採專屬 RNG，會改變既有以全域 RNG 混合特效的序列，因此遷移時需重新驗證玩法亂數基準。fixed_step 的 drop 保留小數餘額，skybound 舊版過載會全部清零；這是明確的新契約，不能把換檔視為零行為差異。

Kit 的既有自動同步按整包複製，包含實驗／展示工具；本輪提供依賴參考而沒有宣稱 tree-shaking 或細粒度安裝。需要外部專案使用時，應把 capability 目錄與契約文件一併作為開發參考；runtime 仍是 `addons/proto_kit`。

## 成熟度與測量

採用證據分為副本存在、來源靜態引用、遊戲路徑實際執行、作者外觀／手感驗收。inventory 只證明前兩種。檔頭方法與測試引用不是新測試通過宣告。新增池驗證容量固定，不宣稱提升了幾毫秒或手機 FPS；未取得實機數據前不做效能結論。

## 快照數量

| 原型 | 自有 GDScript（含工具／測試） | kit 引用路徑 | kit 腳本副本 |
|---|---:|---:|---:|
| debt-commission | 149 | 5 | 53 |
| dreamling-idle | 18 | 8 | 37 |
| erwin-run | 13 | 10 | 14 |
| hero-horde-idle | 96 | 23 | 31 |
| horde-25d | 18 | 6 | 17 |
| kagura-dango | 44 | 5 | 67 |
| luffy-marineford | 47 | 11 | 17 |
| madara-survivor | 24 | 8 | 17 |
| pachinko | 19 | 1 | 3 |
| pixel-monster | 21 | 2 | 3 |
| seal-meadow | 60 | 17 | 37 |
| seichi-pov | 11 | 1 | 3 |
| skybound-blades | 36 | 16 | 21 |
| star-tide-harbor | 14 | 3 | 3 |
| survivor-series | 63 | 12 | 14 |
| taskbar-hero | 33 | 2 | 3 |

跨原型逐位元組相同的程式／shader 共 23 組；完整路徑見 inventory.json。
