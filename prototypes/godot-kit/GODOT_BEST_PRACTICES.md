# Godot 官方 Best Practices（stable）摘要與 skill 涵蓋盤點

來源：https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html （共 12 頁，CC BY 3.0，僅連結不轉載原文）
比對對象：repo 內 `.claude/skills/godot-*/SKILL.md` 及其 `references/*.md`（13 個 Godot 4.7 skill，行號以 2026-09-25 版本為準）
用途：給在 `prototypes/` 開發 Godot 4.7 GDScript 原型的人與 AI 參考。表格說明官方每頁的重點、哪些已有 skill 可查；「缺口守則」補上 skill 沒寫到的部分。

## 逐頁摘要與涵蓋狀態

| # | 頁面 | 核心規則（自己的話） | 涵蓋狀態 |
|---|---|---|---|
| 1 | [Introduction](https://docs.godotengine.org/en/stable/tutorials/best_practices/introduction_best_practices.html) | 沒有單一標準架構，依情境選方案；先懂 OOP 對應關係，再談單一職責、封裝 | 未涵蓋（屬導讀性質，非技術規則，見下方缺口） |
| 2 | [OOP 原則](https://docs.godotengine.org/en/stable/tutorials/best_practices/what_are_godot_classes.html) | Script 是在內建類別上疊加行為；Scene 本身可視為可實例化/繼承的類別；優先用節點組合而非深層腳本繼承 | 部分涵蓋——組合優先於繼承：`godot-nodes-scenes/SKILL.md:28-30`（"Model with composition...Favor adding child nodes over deep inheritance"）。ClassDB 動態能力查詢未提及 |
| 3 | [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) | 用 Main 節點做進入點；scene 盡量自足、對外靠 signal/方法而非硬引用；父子關係要反映「概念上是否從屬」而非只圖方便；孤立系統才用 autoload | 部分涵蓋——autoload 用途與註冊：`godot-nodes-scenes/SKILL.md:37-38,104-105`；signal 解耦（子往上發、父連接）：`godot-signals-groups/SKILL.md:29-30`。缺 Main/World/GUI 進入點慣例與「父子關係要反映概念從屬」的判準——見下方守則 |
| 4 | [Scene vs Script](https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html) | 遊戲專屬內容用 scene（好編輯維護）；通用工具/跨專案共用邏輯用純 script；scene 靠序列化資料，大量節點時效能優於程式碼組裝 | 部分涵蓋——機制面（instantiate() vs new()、preload/PackedScene）：`godot-nodes-scenes/SKILL.md:33,48,51,106-107`。缺「何時該選純 script 當通用工具」的決策準則 |
| 5 | [Autoload vs 一般節點](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html) | 場景專屬狀態用一般節點自己管理；避免用 autoload 集中資源池；autoload 適合真正全域、不干涉其他物件的系統（任務/對話系統）；4.1 起可用 static func/var 取代部分 autoload 用途 | 部分涵蓋——autoload 何時用、註冊方式、順序限制：`godot-nodes-scenes/SKILL.md:37-38,104-105`。缺「避免 autoload 資源池」與「static var/func 可取代 autoload」——見下方守則 |
| 6 | [Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html) | 節點數量／行為複雜度上升會拖效能；改用 Object（最輕）、RefCounted（自動釋放）、Resource（可存檔＋Inspector 相容）取代整棵節點樹 | 未涵蓋——13 個 skill 內未搜到 `RefCounted`／`extends Object`／輕量替代節點的討論（`godot-resources` 只談 Resource 當「資料」用，未提它作為 Node 的輕量替代）——見下方守則 |
| 7 | [Godot interfaces](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_interfaces.html) | Godot 走 duck typing：用 has_method()/is/斷言確認能力再呼叫；用 group/命名慣例當專案內的「介面」；Callable 可降低耦合 | 已涵蓋——has_method 檢查：`godot-physics/SKILL.md:68`；group 當能力標記＋Callable/signal 解耦：`godot-signals-groups/SKILL.md:32-37,49`；`call_group` 對缺方法節點靜默略過的風險也提到：`godot-signals-groups/SKILL.md:117` |
| 8 | [Godot notifications](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_notifications.html) | `_notification()`是萬用底層 callback，能收到沒有對應虛擬方法的事件（如 PARENTED/UNPARENTED）；一般用 `_ready`/`_process`/`_physics_process`/`*_input` 各司其職；屬性賦值順序是 初始值→`_init()`→Inspector 覆寫 | 部分涵蓋——lifecycle 各 callback 用途與 `_init()` 時序陷阱：`godot-gdscript/SKILL.md:31-33,112`；`_notification(what)` 僅一行帶過：`godot-gdscript/references/annotations-and-typing.md:69`。缺 NOTIFICATION_PARENTED/UNPARENTED 這類「沒有虛擬方法可用時」的守則——見下方 |
| 9 | [Data preferences](https://docs.godotengine.org/en/stable/tutorials/best_practices/data_preferences.html) | Array 適合順序存取/迭代；Dictionary 適合鍵值查找，但有記憶體開銷；Object 提供封裝/signal/驗證但因走 ClassDB 較慢；資料量大時（每幀百萬級）要照存取模式選結構 | 部分涵蓋——Dictionary 用法與 `.get(key, default)` 慣例：`godot-gdscript/SKILL.md:101-102`；`.tres`（Resource）文字格式對版控友善的取捨：`godot-resources/references/resource-patterns.md:7`。缺 Array/Dictionary/Object 三者效能取捨的系統性說明——見下方 |
| 10 | [Logic preferences](https://docs.godotengine.org/en/stable/tutorials/best_practices/logic_preferences.html) | 節點屬性可在 `add_child()` 前後設定（兩者皆可，但 `_ready()` 要等進樹後才跑）；效能關鍵路徑用 `preload`，需要彈性/晚決定用 `load()`；小專案適合手刻靜態關卡，大專案適合資料驅動的動態關卡系統 | 部分涵蓋——add_child 前後設定狀態與 `_ready()` 時序：`godot-nodes-scenes/SKILL.md:34,102-103`；preload vs load 差異：`godot-nodes-scenes/SKILL.md:106-107`、`godot-resources/SKILL.md:104-106`。缺「靜態關卡 vs 資料驅動動態關卡」何時選哪個的守則——見下方 |
| 11 | [Project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html) | 資源放在使用它的 scene 附近；資料夾/檔名用 snake_case（C# script 例外用 PascalCase）、節點名用 PascalCase；第三方資源集中放 `addons/`；全部小寫避免跨 OS 大小寫問題；用空的 `.gdignore` 排除不需匯入的資料夾 | 未涵蓋——13 個 skill 中未搜到專案資料夾結構/命名慣例/`.gdignore` 的討論（`godot-csharp/SKILL.md:31` 只講 C# lifecycle 方法用 PascalCase，非專案檔案命名）——見下方守則 |
| 12 | [Version control systems](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html) | Godot 產出的檔案本身對版控友善；`.godot/`、`*.translation` 要進 `.gitignore`；編輯器可自動產生 `.gitignore`/`.gitattributes`（含強制 LF）；大型二進位資產用 Git LFS；Windows 要設 `core.autocrlf` 或靠自動產生的 `.gitattributes` | 未涵蓋——僅 `godot-csharp/references/csharp-setup-and-interop.md:107` 提到「Keep generated `obj/`, `bin/`, and `.godot/` out of version control」一句，屬 C# build 產物範疇，未涉及 Git LFS／`.gitattributes`／LF 設定——見下方守則 |

## 缺口守則（給 Godot 4.7 GDScript 原型開發用）

**#1 Introduction（無對應技術規則，僅補充框架心法）**
寫新系統前先問：這個節點/腳本的職責是不是單一且清楚？能不能只靠 signal/方法暴露必要介面，其餘變數用底線前綴視為私有慣例。

**#3 Scene organization 缺口**
- 每個原型建立一個 `Main.tscn` 作進入點，底下分 `World`/`UI` 兩支，方便一眼看懂資料流向。
- 判斷父子關係時自問：「刪掉父節點，子節點是否理應一起消失？」不是就拆成兄弟節點或獨立 scene，不要為了方便硬塞進同一分支。

**#5 Autoload 缺口**
- 不要把音效/資源池等「場景該自己管的東西」丟進 autoload；每個 scene 自己持有自己需要的 `AudioStreamPlayer`/資源。
- 只是要共用常數或無狀態工具函式時，寫成 `static func`／`static var`（4.1+）放在一支 script，用 `class_name` 或 `const X = preload(...)` 引用，不要為此多開一個 autoload。跨原型共用的放 [godot-kit](README.md)，它刻意用 preload 避免 `class_name` 撞名。

**#6 Node alternatives 缺口**
- 大量（數千個以上）同質、不需要進 scene tree、不需要 `_process`/`_physics_process` 的資料物件，改用 `extends RefCounted`（自動記憶體管理）或 `extends Resource`（需要 Inspector 編輯/存檔時），不要為每筆資料生一個 Node。
- 只有真的需要進場景樹、收 `_ready`/`_input`/物理回呼時才用 Node；否則 Node 的樹狀開銷是不必要的成本。

**#8 Godot notifications 缺口**
- 要在節點被 `add_child()`／移出父節點的當下反應（此時可能還沒進場景樹），用 `_notification(what)` 判斷 `NOTIFICATION_PARENTED`／`NOTIFICATION_UNPARENTED`；`_ready()`／`_enter_tree()` 要等進樹才會觸發。
- 只有在沒有對應虛擬方法（如 `_ready`）可用的引擎事件才需要 `_notification()`；一般情況仍優先用虛擬方法，可讀性較好。

**#9 Data preferences 缺口**
- 需要依 index 大量迭代、極少插入/刪除中間元素 → 用 `Array`（含型別化 `Array[T]`）。
- 需要用 id/key 快速查找、增刪頻繁 → 用 `Dictionary`。
- 需要驗證、預設值、signal、Inspector 編輯的複雜資料 → 用 `class_name` 自訂型別（`Resource` 或一般 `RefCounted`），但每幀操作上萬筆時避免用完整 Object，改用 Array/Dictionary 打底。

**#10 Logic preferences 缺口**
- 關卡內容固定、數量少（原型/demo 階段常見）→ 直接手刻 `.tscn` 靜態關卡最快。
- 關卡需要程序生成、由設計師用資料表配置、或數量會持續成長 → 改用資料驅動（`Resource`/`.tres` 描述關卡內容 + 一個通用 loader 場景生成），避免每關都複製貼上 scene。

**#11 Project organization 缺口**
- 資料夾/檔名一律 `snake_case`（C# `.cs` 例外用 `PascalCase` 對齊類別名），node 名稱用 `PascalCase`；全部小寫路徑，避免 Linux（大小寫敏感）與 Windows/macOS（不敏感）行為不一致。
- 素材放在使用它的 scene 旁邊而非集中的全域資料夾；第三方外掛/資產放 `addons/`；不需要匯入的資料夾（如原始設計稿）放空的 `.gdignore` 排除。

**#12 Version control 缺口**
- `.gitignore` 一定要排除 `.godot/`（引擎快取，會自動重建）與匯出產物（例如 `build/`）。Project Manager 建新專案時，Version Control Metadata 選 Git 就會產生 `.gitignore` 與 `.gitattributes`。
- 換行一律 LF：`.gitattributes` 放 `* text=auto eol=lf`。這個 repo 在 Windows／WSL 間切換過，pachinko 就曾整批檔案變成 CRLF、每個檔案都顯示已修改。
- 大型二進位資產（貼圖、模型、音檔）累積變大時考慮 Git LFS；原型階段的小型佔位素材直接進 repo 即可。
- 場景/資源檔預設用 `.tscn`/`.tres`（文字格式）而非 `.scn`/`.res`（二進位），可讀 diff、方便 code review 與合併衝突排除。
