# godot-kit 改善：實作方式

日期：2026-11-11。對應 [TODO.md](../TODO.md) 的 K1–K7。

來源是靜態閱讀：`sync.sh`、`tools/run_tests.sh` 開頭、`weighted_choice.gd`、`scene_loader.gd`，以及 `save_slots.gd`、`auto_caster.gd`、`camera_shake.gd`、`test_kit.gd` 的函式清單與片段。沒有實作，也沒有跑測試。程式片段是草稿，沒有執行過。

## 建議的實作順序

```
K1 補跑測試 ──→ K3 分類副本差異 ──→ K2 同步可排除 vfx
 （先知道現在是好是壞）              （改 sync.sh 與 audit）

K4 攔截點求解：等 walker-tps 的 A1 做完再搬進來
K5、K6、K7：規則與習慣，改到相關模組時順手做
```

---

## K1 補跑 11-06 重構後的測試

**現況**：依 [PROGRESS.md](../PROGRESS.md) 2026-11-06 的四段紀錄，下列改動完成後都沒有跑 Godot 測試（當時使用者指示重構優先、測試延後），現在已經提交：

| 改動 | 檔案 | 當時記錄的行為差異 |
|---|---|---|
| 抽出有序權重選擇 | `weighted_choice.gd`；`rarity.gd`、`chest_shop.gd`、`run_timeline.gd`、`refine_ladder.gd` 改用它 | 非法或全零權重改成明確拒絕且不消耗 RNG |
| 鏡頭震動還原原本的 offset／rotation | `camera_shake.gd` | 新增 `reset`，停用或換鏡頭時清理 |
| 載入中拒絕重入 | `scene_loader.gd` | 新增 `is_loading`；忙碌時 `request` 回傳 false |
| 循環播放改用私有副本 | `music.gd` | 不再修改共用的 AudioStream |
| 存檔驗證與備份保護 | `save_slots.gd` | 可選的 validator、逐版 migration 檢查、未來版本保護 |
| 固定步長、3D 傷害數字池 | `fixed_step.gd`、`damage_numbers_3d.gd` | 這兩項當時有跑過（composition 37 checks PASS） |

**做法**：

1. 在 repo 的 `prototypes/` 下執行：

   ```bash
   bash godot-kit/tools/run_tests.sh godot-kit
   ```

   它會先 headless 匯入，再跑 `tests/test_*.gd` 全部九組，並檢查 log 裡沒有 `SCRIPT ERROR`／`Parse Error`／`FAIL`。log 資料夾的路徑會印出來。在 `/mnt/d` 上跑比較慢；照 `prototypes/LESSONS.md` 的做法可以先 rsync 到 Linux 檔案系統再跑。

2. 把 [docs/capabilities/VALIDATION.md](capabilities/VALIDATION.md) 裡列為「待補 L2」的案例逐條對照：已有測試涵蓋的打勾；沒有的補進對應的測試檔。至少要有這幾條，因為它們是行為改變而不是純重構：

   - `weighted_choice`：空陣列、全零、含負數、含 NaN 時回傳 -1，而且 RNG 狀態不變（呼叫前後各取一次 `rng.state` 比較）；合法輸入時剛好消耗一次 `randf()`。
   - 四個消費模組：給非法權重時回傳各自定義的失敗結果，不會崩潰。
   - `scene_loader`：載入中再 `request` 回傳 false，而且 `path`、`shown` 不變。
   - `camera_shake`：震動中呼叫 `reset()` 後，鏡頭的 offset 與 rotation 回到震動前的值（不是歸零）。
   - `music`：播放循環曲目後，原始 AudioStream 資源的 loop 設定沒被改動。
   - `save_slots`：主檔版本比程式新時不覆寫、不輪替備份；migration 失敗時回退備份。

3. 失敗的項目分兩類處理：測試期待的是舊行為（改測試，並在該模組的說明寫明新行為），或真的壞了（修模組）。

4. 通過後更新 `VALIDATION.md` 與 `PROGRESS.md`，寫明指令、日期與結果；`PROGRESS.md` 裡「測試延期」的註記才能拿掉。

**注意**：通過 kit 自己的測試不代表各原型的副本沒問題，因為副本還沒同步（見 K3）。

---

## K3 分類副本差異

**現況**：2026-11-11 用 `diff -rq` 比對（排除 `.uid` 與 `.import`），walker-tps 的副本有 41 個檔與 kit 不同，debt-commission 有 13 個。這個數字包含「只存在於一邊」的檔案，沒有區分原因。

**做法**：

1. 跑既有的檢查，它會分類：

   ```bash
   cd prototypes && ./godot-kit/sync.sh --check walker-tps debt-commission
   ```

   `tools/audit_copies.py` 的分類方式與輸出格式見 [VERSION-SYNC.md](VERSION-SYNC.md)。

2. 每個有差異的檔案歸到下面其中一類，決定動作：

   | 類別 | 判斷方式 | 動作 |
   |---|---|---|
   | 副本比 kit 舊 | 副本內容等於 kit 的某個歷史版本（`git log -p` 該檔） | 同步 |
   | 副本被直接改過 | 內容不等於 kit 的任何歷史版本 | 把改動搬回 kit（確認不影響其他原型）或改成原型自己的檔案，再同步 |
   | 只存在於 kit | 副本同步之後 kit 才新增的 | 同步時自然補上；或依 K2 排除 |
   | 只存在於副本 | kit 已刪除或改名 | 確認原型沒有引用後刪除 |

3. 同步前先看該原型實際引用了哪些模組，只需要為這些檔案的差異負責：

   ```bash
   grep -rhoE 'proto_kit/[a-z0-9_/]+\.(gd|tscn|gdshader)' <原型>/scripts <原型>/scenes <原型>/tests <原型>/tools <原型>/*.gd | sort -u
   ```

   2026-11-11 的結果：walker-tps 引用 `scene_builder.gd`、`test_kit.gd`、`screenshot.gd`、`synth.gd`；debt-commission 的遊戲程式引用 `atomic_file.gd`、`synth.gd`、`haptics.gd`（測試與工具另外會用 `test_kit.gd` 等，同步前重跑上面的指令確認）。

4. 同步後跑該原型的 L2 測試。walker-tps 的同步副本在 2026-11-11 才提交，有差異多半是「只存在於一邊」；debt-commission 的 13 個要逐一看。

---

## K2 同步時可以排除不用的部分

**現況**：`sync.sh` 第 36 行是 `rsync -a --delete "$source/" "$target/addons/proto_kit/"`，一律整包複製。`addons/proto_kit` 共 13 MB，其中 `vfx/` 就佔約 13 MB（41 組 Scenario 匯出的圖集與 46 個 Three.js 移植的 `.res`／shader／scene），其餘 55 支腳本與 `ui/` 加起來不到 1 MB。

後果：walker-tps 與 debt-commission 都沒有引用 `vfx/` 裡的任何東西，卻各帶一份 13 MB；Godot 匯入時要處理這些檔案，匯出時要靠 `export_presets.cfg` 的 `exclude_filter` 擋掉（debt-commission 有擋 `addons/proto_kit/vfx/*`，walker-tps 還沒有匯出設定）。

**做法**：用每個原型自己的排除清單，不做「選擇性安裝器」。

1. 原型根目錄可以放一個 `proto_kit.exclude`，內容是 rsync 的排除規則，一行一條：

   ```
   /vfx/
   /hd2d_*.gd
   ```

   開頭的 `/` 表示相對於 `addons/proto_kit/`。

2. `sync.sh` 第 35–37 行改成：

   ```bash
   mkdir -p "$target/addons/proto_kit"
   exclude=()
   [[ -f "$target/proto_kit.exclude" ]] && exclude=(--exclude-from="$target/proto_kit.exclude" --delete-excluded)
   rsync -a --delete "${exclude[@]}" "$source/" "$target/addons/proto_kit/"
   echo "synced: $target${exclude:+ (with proto_kit.exclude)}"
   ```

   `--delete-excluded` 會把副本裡已經存在、但現在被排除的檔案刪掉；沒有它的話，加了排除清單之後舊的 `vfx/` 會留著。

3. `tools/audit_copies.py --check` 要讀同一個檔，把符合排除規則的路徑從「只存在於 kit」的清單中拿掉，否則排除之後 `--check` 永遠回報有差異。規則語法只支援兩種就夠：以 `/` 結尾的目錄前綴，與含 `*` 的檔名樣式（用 `fnmatch`）。在 `audit_copies.py` 的既有 CLI 測試裡加一個含排除清單的暫存 fixture。

4. **排除之前要確認依賴**：如果 kit 頂層有腳本或 scene 引用 `vfx/` 裡的東西，排除 `vfx/` 後它們在原型裡會出現載入錯誤。2026-11-11 搜尋 `grep -ln 'proto_kit/vfx/' godot-kit/addons/proto_kit/*.gd` 沒有結果，也就是頂層腳本沒有用完整路徑引用它；但這個搜尋沒涵蓋 `.tscn`、相對路徑與執行時組出來的路徑（`vfx_gallery.gd`、`pixel_vfx.gd`、`pixel_vfx3d.gd` 從名稱看是候選，沒有讀過）。動手前再查兩件事：

   ```bash
   grep -rln 'vfx/' godot-kit/addons/proto_kit --include=*.gd --include=*.tscn --include=*.tres | grep -v '/vfx/'
   python3 godot-kit/tools/capabilities.py plan <模組名>
   ```

   有引用的腳本一起寫進排除清單。排除後做一次 headless 匯入，確認沒有 `Failed to load script`。

5. 先在 walker-tps 做：加 `proto_kit.exclude`（`/vfx/` 與依賴它的腳本）→ `sync.sh walker-tps` → headless 匯入 → `test_combat.gd`、`test_battlefield.gd`。確認沒問題再做 debt-commission，做完它的 `export_presets.cfg` 裡 `addons/proto_kit/vfx/*` 那條排除可以留著，沒有壞處。

6. `README.md` 的同步段落與 `VERSION-SYNC.md` 補上這個檔的說明。

**不做的事**：不做依賴解析後自動只複製用到的模組。55 支小腳本加起來不到 1 MB，全帶著沒有成本；值得排除的只有 `vfx/` 這種大目錄。

---

## K4 AI／戰鬥基礎模組：等有實際程式再抽

**現況**：`addons/proto_kit` 的 55 支腳本涵蓋存檔、音訊、鏡頭、載入、抽卡與掉寶、特效、Sprite、測試工具，沒有狀態機、感知、瞄準預判、血量或傷害元件。walker-tps 的敵人 AI 是第一個需要這些的原型。

**做法**：

1. **現在不抽**。kit 的規則是有第二個使用者才抽共用；AI 的狀態機與感知和遊戲規則綁得很緊，先在 walker-tps 裡寫好（它的 `design/code-improvements.md` A1–A8）。

2. **第一個候選是攔截點求解**。它是純數學、沒有狀態、不依賴任何 node，任何有彈道的遊戲都用得到。walker-tps 的 A1 做完並通過測試後，搬成 `addons/proto_kit/intercept.gd`：

   ```gdscript
   extends RefCounted
   ## 射擊預判：已知射手位置、目標位置與速度、彈速，求瞄準點。
   ## 解不出來（目標比子彈快而且在遠離）時回傳目標現在的位置。不讀場景、不用 RNG。

   static func point(shooter: Vector3, target: Vector3, target_velocity: Vector3, shot_speed: float) -> Vector3
   static func time(shooter: Vector3, target: Vector3, target_velocity: Vector3, shot_speed: float) -> float   # 無解回傳 -1
   ```

   2D 遊戲用得到的話加 `point_2d`，不要用 Variant 同時接受兩種向量（`auto_caster.gd` 的 `origin: Variant` 就是這種寫法，呼叫端傳錯型別不會報錯）。

3. 搬進來時照 kit 既有的流程：`catalog/specs.json` 加一筆（用途、參數、回傳、限制、範例）、`capabilities.py build` 重新產生目錄、在 `tests/` 加測試（目標靜止、橫移、迎面、遠離且比子彈快、`shot_speed` 為 0）。

4. **之後才考慮的**（要等第二個原型真的需要）：

   | 候選 | 什麼時候抽 | 形狀 |
   |---|---|---|
   | 視線檢查 | 第二個 3D 原型也要「看不看得到」時 | 靜態函式：起點、目標點陣列、遮罩、排除清單 → bool。視角錐與降頻留在遊戲裡 |
   | 繞目標站位 | 第二個有多敵人包圍的原型 | 靜態函式：目標位置、名次、總數、半徑、基準角 → 位置 |
   | 狀態機 | 不抽 | GDScript 的 `enum` 加 `match` 就夠；包成類別只會多一層 |
   | 血量元件 | 不抽 | 十行程式，各遊戲的受擊規則都不同 |

---

## K5 帶遊戲規則的模組不再擴充

**現況**：`pet_care.gd`、`gacha.gd`、`march_strip.gd`、`chest_shop.gd`、`card_draft.gd`、`talent_tiers.gd`、`refine_ladder.gd`、`run_goals.gd`、`run_timeline.gd`、`store_front.gd`、`upgrade_tree.gd`、`auto_caster.gd` 這類模組裡有具體的遊戲規則（機率表的形狀、保底、升級曲線），不是基礎設施。walker-tps 與 debt-commission 一支都沒用。

**做法**：

1. 用既有的採用證據分三類。`catalog/specs.json` 每筆有來源採用紀錄；也可以直接數引用：

   ```bash
   for m in pet_care gacha march_strip chest_shop card_draft talent_tiers refine_ladder run_goals run_timeline store_front upgrade_tree auto_caster; do
     echo "$m: $(grep -rl "proto_kit/$m.gd" --include=*.gd --include=*.tscn . | grep -v '^./godot-kit/' | cut -d/ -f2 | sort -u | tr '\n' ' ')"
   done
   ```

   | 引用的原型數 | 處理 |
   |---|---|
   | 2 個以上 | 留在 kit，正常維護 |
   | 1 個 | 在 `specs.json` 標 `"maturity": "single-consumer"`；不再為假想的需求加參數，那個原型要改就改 |
   | 0 個 | 標 `"maturity": "unused"`；下次整理時移到 `addons/proto_kit/_attic/` 或刪除 |

2. 不要現在就搬動或刪除檔案：各原型的副本與 `sync.sh --delete` 會讓搬動變成一次全面同步。只先標記。

3. 新增模組前的檢查寫進 `README.md` 開頭：已經有兩個原型各自寫了一份，才抽共用。

---

## K6 以 Dictionary 傳參數的 API 檢查未知鍵

**現況**：多數模組用 Dictionary 當參數與資料列。例如 `auto_caster.gd` 的 `learn(spell: Dictionary, bonus: Dictionary = {})`，裡面直接讀 `spell.id`，其他欄位在 `effective()` 與 `_cast()` 裡用 `get` 取預設值。鍵名打錯（`cooldwon`）不會報錯，只會安靜地用預設值。

**做法**：不改成 Resource 或類別（原型要的是能在程式裡直接寫字面值）。在入口加一個只在除錯版執行的檢查：

```gdscript
const SPELL_KEYS: Array[String] = ["id", "damage", "cooldown", "range", "targets", "pick", "dot", "buff"]   # 以實際欄位為準

func learn(spell: Dictionary, bonus: Dictionary = {}) -> void:
    assert(spell.has("id"), "auto_caster.learn: spell needs an id")
    if OS.is_debug_build():
        for key: String in spell.keys():
            if key not in SPELL_KEYS:
                push_warning("auto_caster.learn: unknown key '%s' in spell '%s'" % [key, spell.get("id", "?")])
```

- 欄位清單從該模組開頭的說明註解與 `catalog/specs.json` 抄，兩邊要一致。
- 只在「改到那個模組」或「新增模組」時加，不要為了這件事巡一遍 55 支。
- 共用的檢查函式可以放進 `test_kit.gd` 之外的一個小檔（例如 `dict_check.gd`，一個靜態函式 `unknown_keys(data, allowed) -> Array`），第二個模組要用時再抽。

**驗證**：該模組的測試加一條：傳入含未知鍵的字典時，行為與沒有該鍵時相同（警告不影響結果）。

---

## K7 文件

**現況**：`README.md` 786 行，是模組 API 說明、第三方外掛目錄、同步方式與研究摘要的混合。`docs/` 另有 `REUSE-RESEARCH.md`、`KIT-RESEARCH-02.md`、`KIT-RESEARCH-03.md`、`REUSE-CONTRACT-DRAFTS.md`、`REUSE-AUDIT.md`、`COMPOSITION.md`、`RESEARCH-COVERAGE.md`、`REFACTOR-P0.md`。其中 `REUSE-CONTRACT-DRAFTS.md` 是未實作的 API 草案。

**做法**：

1. `README.md` 只留四件事：這是什麼與怎麼同步（含 K2 的排除清單）、模組一覽表（每個模組一行：用途、成熟度、連到 `docs/capabilities/REFERENCE.md` 的對應段落）、命令列工具一覽、第三方外掛目錄。各模組的詳細 API 已經由 `capabilities.py build` 產生在 `REFERENCE.md`，README 不重複。

2. 動手前先確認 `REFERENCE.md` 真的涵蓋 README 現有的每個模組說明；README 有而 `specs.json` 沒有的內容，先補進 `specs.json` 再刪 README 的段落。

3. 研究文件移到 `docs/research/`，每份開頭加一行狀態：「已實作（見某模組）」「部分實作」「未實作的草案」。`REUSE-CONTRACT-DRAFTS.md` 標成未實作。

4. `.claude/rules/prototype-code.md` 與 `prototypes/LESSONS.md` 有連到 kit README 的特定段落，改完檢查這些連結。

5. 這項是純文件，不用跑測試；跑 `capabilities.py check` 確認目錄仍一致。
