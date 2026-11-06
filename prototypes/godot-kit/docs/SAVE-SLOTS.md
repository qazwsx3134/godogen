# SaveSlots：可驗證的 JSON 快照

2026-11-06。來源已重構，Godot 執行測試依使用者指示延期；已選擇性同步 seal-meadow 的 save_slots.gd，並以 SaveStore adapter 接入；其他副本未同步。

用於單人遊戲進度／profile。存檔封套為 `{version: 非負整數, data: Dictionary}`；遊戲負責 payload schema，kit 負責版本、備份選取與單檔提交。這不是 journal、多檔匯入或雲端衝突合併工具。

```text
restore → 讀主檔與備份 → 任一較新版本：拒絕
                       → 主檔遷移＋驗證成功：返回 main
                       → 否則嘗試備份：返回 backup 或錯誤
save → JSON 序列化＋驗證候選 → 查兩檔較新版本
     → 有效主檔原始 bytes 輪替備份 → 提交候選主檔
```

## 介面

| API | 回傳／語義 |
|---|---|
| `restore(path, version, migrations={}, validator=Callable())` | `{data, source, error}`；source 為 main／backup／空字串；error 為空字串、missing、corrupt、newer、migration、invalid |
| `save(path, data, version, validator=Callable(), migrations={})` | Godot Error：OK 成功；ERR_INVALID_PARAMETER 路徑空或版本負值；ERR_INVALID_DATA 候選不合格；ERR_UNAVAILABLE 現有檔案較新；其他為 IO 錯誤 |

`migrations` 是整數舊版本 → Callable(Dictionary) → Dictionary，每步升一版。`validator` 是 Callable(Dictionary) → bool，檢查目前 schema；缺省只檢查封套。回呼須純函式，不讀寫檔案、不改遊戲狀態。傳入 validator 的資料是深複製；錯誤返回型別會拒絕，但回呼內部的腳本例外不由此 API 捕捉。

restore 不修復磁碟、不自動保存，返回獨立資料。save 檢查的是 JSON round-trip 後的資料，數字可能變 float；payload 限 JSON 相容值，validator 應檢查必要型別與範圍。舊主檔必須能遷移至目前版本並通過 validator 才輪替備份，保存的仍是舊主檔原始 bytes。若舊主檔無效，保留既有備份。

## 使用範例

```gdscript
const Saves = preload("res://addons/proto_kit/save_slots.gd")

func validate_profile(data: Dictionary) -> bool:
    var coins: Variant = data.get("coins")
    return ((coins is int or coins is float) and is_finite(float(coins))
        and float(coins) >= 0.0 and floorf(float(coins)) == float(coins))

func load_profile() -> Dictionary:
    return Saves.restore("user://profile.json", 1, {}, validate_profile)

func save_profile(snapshot: Dictionary) -> Error:
    return Saves.save("user://profile.json", snapshot, 1, validate_profile)
```

這是最小 payload 示範，實際遊戲需驗所有必要欄位。load 返回 error 非空時不要把空 data 當作已讀取存檔；特別是 newer 應停用自動保存，讓玩家使用正確版本。只有 save == OK 才顯示保存成功。

## 相容性與限制

- 原三參數 save／restore 呼叫保留。新增可選 validator；save 可帶 migrations 以驗證舊主檔，參數順序見表。
- 保留明確 v0；缺失、字串、負值、非整數版本不再被 int() 寬鬆轉換。較新數字版本即使 payload 不合格仍阻止覆寫。
- 主檔有效但備份較新，現在也拒絕。主檔 migration 失敗現在可嘗試備份；兩者都失敗時錯誤優先保留主檔的 migration／invalid，否則取可用的失敗原因。
- 單寫入者。讀取後到寫入間沒有 revision 比對或跨程序鎖；不適合多程序競爭同一路徑。備份提交成功後主檔仍可能寫入失敗，兩檔不是一個交易。
- 泛用 codec、revision 與遊戲 adapter 遷移仍未實作；原研究的 ValidatedSnapshotStore 草案不等於目前 API。

驗證：只做能力目錄生成一致性與 diff 格式檢查；執行案例見 [待驗證紀錄](capabilities/VALIDATION.md)。
