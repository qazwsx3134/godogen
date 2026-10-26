# 驗證證據與重現方式

## 環境與範圍

2026-10-25，工作樹 HEAD `01964ab`；Godot `4.7.stable.official.5b4e0cb0f`。既有未提交的共用模組亦納入。所有測試／probe 使用 `/tmp/commercial-review-2026-10-25/` 下的隔離 XDG 目錄，沒有使用玩家正式存檔。圖像採用既有 capture 工具與虛擬顯示器，音訊為 dummy。

本次只新增評論文件和證據；沒有修正遊戲程式，也沒有 commit。測試執行可能產生一般 Godot import/cache，不把它們當交付成果。

## 既有測試：16 組，runner 均回傳 PASS

| 專案 | suites | 結果 | 本機原始 log 目錄 |
|---|---|---|---|
| godot-kit | genre_modules、proto_kit | 2 PASS | `/tmp/godot-tests.LjB1Cj` |
| skybound-blades | battle、run、save、skills、camp、field | 6 PASS | `/tmp/godot-tests.WRkbn0` |
| hero-horde-idle | balance、main | 2 PASS | `/tmp/godot-tests.Fvx6Qj` |
| debt-commission | story、chapter1、save_validation、save_slots、chapter_flow、tutorial | 6 PASS | `/tmp/godot-tests.arDFod` |

這是選定 suites，不是所有測試、更不是商業驗收通過。相關完整 log 已複製至 [evidence/tests](evidence/tests/)，避免只依賴暫存目錄。

重跑形式（在 repository root；每個專案使用不同隔離目錄）：

```bash
env XDG_DATA_HOME=/tmp/commercial-review-repeat/kit-data \
    XDG_CONFIG_HOME=/tmp/commercial-review-repeat/kit-config \
    TEST_TIMEOUT=120 \
    prototypes/godot-kit/tools/run_tests.sh prototypes/godot-kit \
    genre_modules proto_kit
```

其他專案替換專案路徑和 suites；本輪 skybound 的 field 使用 `field:60` timeout 參數。不要用新的測試覆蓋正式使用者資料。

### PASS 不代表 log 無錯誤

- kit 的 `proto_kit.log` 有 `Index p_idx = 0 is out of bounds (items.size() = 0)`，位置為 `sprite_inspector.gd:167` 的 `select_sheet()`，由 `test_proto_kit.gd:1156` 觸發；仍輸出測試成功。這是 K-02 的具體例子。
- kit 有刻意測試缺少 root、錯誤資源與 owner 等負例，skybound save 有刻意破壞 JSON 的負例。這些要用精確可辨識的負例規則分類，不能把所有 `ERROR` 一律當遊戲壞掉，也不能一律忽略。
- import／debt 部分 logs 有 sandbox TCP listen／localhost MCP 連線錯誤，editor 結束亦有資源未釋放訊息。這些屬驗證環境或開發工具噪音，未證明正式遊戲 runtime 洩漏。debt 的 MCP 有 editor guard；本輪不宣稱正式版開放偵錯端口。
- 額外 probe 找到既有 assertions 沒涵蓋的邏輯錯誤，故「已有綠燈」不能取代邊界案例。

## skybound：任務冷卻、技能鏈及存檔

原始輸出：[sky-probe.txt](evidence/sky-probe.txt)。完整 probe 原始碼以文件保存：[sky-probe-source.txt](evidence/sky-probe-source.txt)。它是評估工具，不加入產品測試或自動啟動流程。

重現命令形式：將 source 文件複製到 `/tmp/sky_review.gd`，在隔離資料目錄下執行：

```bash
env XDG_DATA_HOME=/tmp/commercial-review-repeat/sky-data \
    XDG_CONFIG_HOME=/tmp/commercial-review-repeat/sky-config \
    godot --headless --path prototypes/skybound-blades \
    --script /tmp/sky_review.gd
```

### S-02：冷卻

建立 Run，完成可重複任務 `hunt_1_0`，於 `600000ms` 領獎，序列化／還原後建立新的 Battle。

```text
設計冷卻：300000ms
存下的 available_at_ms：900000ms
新 Battle.now_ms：0ms
讀回的剩餘等待：900000ms
```

證明持久化的絕對值與新戰鬥時鐘不在同一時間基準。改善前須先決定冷卻是遊玩時間還是真實時間；本報告不擅自指定產品選擇。

### S-01：技能鏈

Run 等級 10；leader 已學 cleave 3、rising 2、whirl 2。slots 為 `[cleave]`，chain 為 `[cleave, rising]`。呼叫 equip 將 whirl 放到 index 1。

```text
回傳：空字串（成功）
slots：[cleave, whirl]
chain：[cleave]       ← 第二格換裝仍改掉既有連招
```

Probe 直接準備已存在連招狀態，不模擬付印 UI；已付連招成本的影響由產品流程／程式判讀。未聲稱 probe 實際完成購買操作。

### S-03：存檔結構

只寫隔離的 `user://review_backup.json`，完成後清除。

1. 備份放 schema 1 合法外層資料；主檔放 schema 999。`load_state()` 回 `{}`，沒有使用備份或回報「不支援版本」。
2. 主檔放 `{"schema":1,"run":{}}`。`load_state()` 原樣接受不完整 run。

這證明載入層無法區分不支援版本、壞檔與新遊戲，也沒有驗證 run 必要欄位；沒有在本輪用完整畫面注入磁碟故障。未來版本檔案應保留並提示，不能一律自動回退再覆寫。

## hero：時間模型及復活統計

原始輸出：[hero-probe.txt](evidence/hero-probe.txt)。完整程式：[hero-probe-source.txt](evidence/hero-probe-source.txt)。執行方法同上，換成 hero 專案與 probe 路徑。

相同 seed 1、skip_muster、不輸入玩家指令，直到戰鬥結束：

| 每步秒數 | 全滅時間（秒） | Boss 剩餘 HP |
|---|---:|---:|
| 1/60 | 87.4167 | 32749.51 |
| 1/30 | 87.4000 | 32627.60 |
| 1/15 | 87.4667 | 32759.77 |
| 0.5 | 75.0000 | 33618.73 |
| 2.0 | 80.0000 | 34347.81 |

此為模擬固定 dt 敏感度檢查，不是實機 FPS benchmark，也不是留存或戰鬥平衡結論。

復活案例：找同區域 SSR healer 與盾衛，把目標 HP 設 0，呼叫 `_revive()`；依正常記帳形式把補師 saves 設為 1，讀 contribution。目標 max HP 300、補師 165、比例 0.4，恢復 120、貢獻 66。這是隔離公式重現，不是完整玩家操作追蹤。

## kit：測試 runner 的 import 假綠燈

輸出：[runner-probe.txt](evidence/runner-probe.txt)。fixture：[runner-fixture-source.txt](evidence/runner-fixture-source.txt)。

建立假的 Godot 執行檔：收到 `--editor` 時輸出 import failed 並 exit 17；其餘呼叫輸出 `GENRE MODULES TESTS PASSED (review fixture)` 並 exit 0。以 `GODOT_BIN` 指向它，執行 kit 的 genre_modules suite。runner 仍 `PASS genre_modules`、exit 0。

**這是 harness 故障注入，與上面的真 Godot 16 組測試分開計算。** 它只證明 runner 忽略 import 失敗；不表示真實 import 在本次必然失敗。fixture 也不拿來證明功能正確。

## 畫面證據

| 圖片 | 生成方式與限制 |
|---|---|
| [debt 調查](evidence/debt-investigate.png) | 既有 chapter1 截圖工具的暫存副本，設定 tutorial 完成後自動推進劇情。證明該狀態排版，不驗證新手是否能自行完成。 |
| [skybound 營地](evidence/skybound-camp.png) | 既有 shot 工具、844×390、camp 模式準備示例裝備；用於手機橫向文字／比較面板評估。 |
| [hero 重擊預警](evidence/hero-telegraph.png) | 既有 capture_shots 工具、390×844、seed 7，工具準備代表性狀態；用於資訊層級與可辨識性評估。 |

沒有測 Android/iOS 觸控與安全區、重新建置正式 Web、量測記憶體／GPU／長時運行，也沒有真人訪談或聆聽音訊。素材權利文件與商業付費意願仍待專案自行核實；本文不給法律或市場保證。
